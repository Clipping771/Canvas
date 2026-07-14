import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vinci_board/engines/chemistry/lab/glassware.dart';
import 'package:vinci_board/engines/chemistry/reaction/reaction_conditions.dart';
import 'package:vinci_board/engines/chemistry/core/compound.dart';
import 'package:vinci_board/presentation/widgets/glassmorphic_panel.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinci_board/presentation/providers/chemistry_engine_provider.dart';

// ─────────────────────────────────────────────────────────────
// BEAKER WIDGET (Advanced Interactive Glassware)
// ─────────────────────────────────────────────────────────────
class BeakerWidget extends ConsumerStatefulWidget {
  const BeakerWidget({super.key});

  @override
  ConsumerState<BeakerWidget> createState() => _BeakerWidgetState();
}

class _BeakerWidgetState extends ConsumerState<BeakerWidget>
    with TickerProviderStateMixin {
  final Beaker _beaker = Beaker(id: 'beaker_1');
  final _equationController = TextEditingController(
    text: 'HCl + NaOH -> NaCl + H2O',
  );
  String _reactionReport = '';
  String _selectedSolute = 'NaCl';
  double _molesToAdd = 0.5;

  late final AnimationController _liquidAnimController;
  final List<_BubbleParticle> _bubbles = [];
  bool _isReacting = false;
  double _precipitateAmount = 0.0; // moles of solid precipitate

  @override
  void initState() {
    super.initState();
    _liquidAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _liquidAnimController.addListener(() {
      _updateBubbles();
    });

    // Seed some initial bubbles
    for (int i = 0; i < 15; i++) {
      _bubbles.add(
        _BubbleParticle(
          xFraction: math.Random().nextDouble(),
          yFraction: math.Random().nextDouble(),
          radius: 1.5 + math.Random().nextDouble() * 2.0,
          speed: 0.005 + math.Random().nextDouble() * 0.01,
        ),
      );
    }
  }

  @override
  void dispose() {
    _liquidAnimController.dispose();
    _equationController.dispose();
    super.dispose();
  }

  void _updateBubbles() {
    final double maxRisingSpeed = _isReacting ? 0.02 : 0.003;
    final int targetBubbleCount = _isReacting ? 40 : 10;

    // Adjust bubble count dynamically
    if (_bubbles.length < targetBubbleCount) {
      _bubbles.add(
        _BubbleParticle(
          xFraction: math.Random().nextDouble(),
          yFraction: 1.0,
          radius: 1.0 + math.Random().nextDouble() * 2.5,
          speed: 0.005 + math.Random().nextDouble() * maxRisingSpeed,
        ),
      );
    } else if (_bubbles.length > targetBubbleCount) {
      _bubbles.removeLast();
    }

    // Move bubbles up
    for (var bubble in _bubbles) {
      bubble.yFraction -= bubble.speed;
      if (bubble.yFraction < 0.0) {
        bubble.yFraction = 1.0;
        bubble.xFraction = math.Random().nextDouble();
      }
    }
    setState(() {});
  }

  void _addSolute() {
    final db = ref.read(chemistryDatabaseProvider);
    ChemicalCompound? compound = db.getCompound(_selectedSolute);
    if (compound == null) {
      if (_selectedSolute == 'HCl') {
        compound = ChemicalCompound(
          formula: 'HCl',
          name: 'Hydrochloric Acid',
          molarMass: 36.46,
          composition: {},
          state: 'aq',
        );
        db.addCompound(compound);
      } else if (_selectedSolute == 'NaOH') {
        compound = ChemicalCompound(
          formula: 'NaOH',
          name: 'Sodium Hydroxide',
          molarMass: 40.0,
          composition: {},
          state: 'aq',
        );
        db.addCompound(compound);
      }
    }

    if (compound != null) {
      setState(() {
        final mass = _molesToAdd * compound!.molarMass;
        // 15mL per 0.1 mole
        final vol = _molesToAdd * 150.0;

        if (compound.formula == 'HCl') {
          _beaker.currentPh = (_beaker.currentPh - 1.2).clamp(1.0, 7.0);
        } else if (compound.formula == 'NaOH') {
          _beaker.currentPh = (_beaker.currentPh + 1.2).clamp(7.0, 14.0);
        } else if (compound.formula == 'NaCl') {
          // salt neutralizes slightly
          _beaker.currentPh =
              _beaker.currentPh + (7.0 - _beaker.currentPh) * 0.15;
          // NaCl has limited solubility, let's precipitate if total NaCl > 1.5 moles
          double currentNaCl = _beaker.contents[compound] ?? 0.0;
          if (currentNaCl + _molesToAdd > 1.5) {
            _precipitateAmount += (currentNaCl + _molesToAdd - 1.5);
          }
        }

        _beaker.addCompound(compound, _molesToAdd, vol, mass);
      });
    }
  }

  void _runReaction() {
    setState(() {
      _isReacting = true;
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      final engine = ref.read(chemistryEngineProvider);
      final db = ref.read(chemistryDatabaseProvider);

      final List<ChemicalCompound> reactants = [];
      final reactantsFormulae = ['HCl', 'NaOH'];
      for (var f in reactantsFormulae) {
        var c = db.getCompound(f);
        c ??= ChemicalCompound(
          formula: f,
          name: f,
          molarMass: 50,
          composition: {},
        );
        reactants.add(c);
      }

      final conditions = ReactionConditions(
        temperatureK: _beaker.temperature,
        pressureAtm: 1.0,
      );
      final report = engine.executeEquation(
        _equationController.text,
        reactants,
        conditions,
      );

      setState(() {
        _isReacting = false;
        _reactionReport = report;

        if (_equationController.text.contains('HCl') &&
            _equationController.text.contains('NaOH')) {
          _beaker.currentPh = 7.0;
          _beaker.contents.clear();
          final water =
              db.getCompound('H2O') ??
              ChemicalCompound(
                formula: 'H2O',
                name: 'Water',
                molarMass: 18.015,
                composition: {},
              );
          final salt =
              db.getCompound('NaCl') ??
              ChemicalCompound(
                formula: 'NaCl',
                name: 'Sodium Chloride',
                molarMass: 58.44,
                composition: {},
              );
          _beaker.contents[water] = 1.0;
          _beaker.contents[salt] = 0.8;
          _precipitateAmount =
              0.0; // reset precipitate as neutralization dissolves it
        }
      });
    });
  }

  // Enthalpy of reaction (mock exothermic neutralization value)
  final double _dH = -57.1; // kJ/mol
  final double _dS = 0.080; // kJ/(mol*K)

  @override
  Widget build(BuildContext context) {
    // Gibbs Free Energy: dG = dH - T * dS
    final dG = _dH - (_beaker.temperature * _dS);
    final isSpontaneous = dG < 0;

    return GlassmorphicPanel(
      width: 330,
      height: 520,
      borderRadius: BorderRadius.circular(24),
      color: const Color(0xFF1E1E2F).withValues(alpha: 0.85),
      borderColor: const Color(0xFF3D5AFE).withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3D5AFE).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.science,
                  color: Color(0xFF3D5AFE),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Virtual Beaker Lab',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              if (_isReacting)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: const [
                      SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: Colors.amber,
                        ),
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Reacting',
                        style: TextStyle(
                          color: Colors.amber,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Beaker Graphic Panel
          Center(
            child: Container(
              width: 130,
              height: 130,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: CustomPaint(
                painter: _VirtualBeakerPainter(
                  currentVolume: _beaker.currentVolume,
                  capacityVolume: _beaker.capacityVolume,
                  ph: _beaker.currentPh,
                  bubbles: _bubbles,
                  precipitateAmount: _precipitateAmount,
                ),
              ),
            ),
          ),

          // Stats / Parameters
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              childAspectRatio: 2.8,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStatCell(
                  'Volume',
                  '${_beaker.currentVolume.toStringAsFixed(0)} mL',
                ),
                _buildStatCell(
                  'pH Value',
                  _beaker.currentPh.toStringAsFixed(2),
                  color: _getPhColor(_beaker.currentPh),
                ),
                _buildStatCell(
                  'Solution Temp',
                  '${_beaker.temperature.toStringAsFixed(0)} K',
                ),
                _buildStatCell(
                  'Free Energy ΔG',
                  '${dG.toStringAsFixed(1)} kJ',
                  color: isSpontaneous ? Colors.greenAccent : Colors.redAccent,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Interactive Temperature Control
          Row(
            children: [
              Text(
                'Temp (Kelvin):',
                style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13),
              ),
              const Spacer(),
              Text(
                '${_beaker.temperature.toStringAsFixed(0)} K',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF3D5AFE),
              inactiveTrackColor: Colors.white12,
              thumbColor: const Color(0xFF3D5AFE),
              trackHeight: 3.0,
            ),
            child: Slider(
              min: 273.0,
              max: 373.0,
              value: _beaker.temperature,
              onChanged: (val) {
                setState(() {
                  _beaker.temperature = val;
                });
              },
            ),
          ),

          // Add Solute Controls
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedSolute,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF1E1E2F),
                    underline: const SizedBox(),
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 13,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'NaCl',
                        child: Text('NaCl (Salt)'),
                      ),
                      DropdownMenuItem(value: 'HCl', child: Text('HCl (Acid)')),
                      DropdownMenuItem(
                        value: 'NaOH',
                        child: Text('NaOH (Base)'),
                      ),
                      DropdownMenuItem(
                        value: 'H2O',
                        child: Text('H2O (Water)'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedSolute = val);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: TextField(
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        suffixText: ' mol',
                        suffixStyle: TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                      ),
                      onChanged: (val) {
                        _molesToAdd = double.tryParse(val) ?? 0.5;
                      },
                      controller: TextEditingController(
                        text: _molesToAdd.toString(),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isReacting ? null : _addSolute,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3D5AFE),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  minimumSize: const Size(50, 38),
                ),
                child: Text(
                  'Add',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Chemical Equation & Run
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: TextField(
                      controller: _equationController,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 13,
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: 'HCl + NaOH -> NaCl + H2O',
                        hintStyle: TextStyle(color: Colors.white24),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _isReacting ? null : _runReaction,
                icon: const Icon(Icons.bolt, size: 14, color: Colors.white),
                label: Text(
                  'Run',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  minimumSize: const Size(80, 38),
                ),
              ),
            ],
          ),

          // Output report
          if (_reactionReport.isNotEmpty) ...[
            const SizedBox(height: 10),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _reactionReport,
                    style: GoogleFonts.firaCode(
                      color: const Color(0xFF34D399),
                      fontSize: 9,
                    ),
                  ),
                ),
              ),
            ),
          ] else
            const Spacer(),
        ],
      ),
    );
  }

  Widget _buildStatCell(String title, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          title,
          style: GoogleFonts.outfit(color: Colors.white54, fontSize: 11),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          style: GoogleFonts.outfit(
            color: color ?? Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

class _BubbleParticle {
  double xFraction;
  double yFraction;
  double radius;
  double speed;
  _BubbleParticle({
    required this.xFraction,
    required this.yFraction,
    required this.radius,
    required this.speed,
  });
}

class _VirtualBeakerPainter extends CustomPainter {
  final double currentVolume;
  final double capacityVolume;
  final double ph;
  final List<_BubbleParticle> bubbles;
  final double precipitateAmount;

  _VirtualBeakerPainter({
    required this.currentVolume,
    required this.capacityVolume,
    required this.ph,
    required this.bubbles,
    required this.precipitateAmount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double W = size.width;
    final double H = size.height;

    // Draw beaker body
    final beakerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final beakerPath = Path()
      ..moveTo(W * 0.15, H * 0.05)
      ..lineTo(W * 0.15, H * 0.95)
      ..arcToPoint(Offset(W * 0.25, H * 0.98), radius: const Radius.circular(5))
      ..lineTo(W * 0.75, H * 0.98)
      ..arcToPoint(Offset(W * 0.85, H * 0.95), radius: const Radius.circular(5))
      ..lineTo(W * 0.85, H * 0.05);
    canvas.drawPath(beakerPath, beakerPaint);

    // Draw liquid level
    if (currentVolume > 0.0) {
      final double fillHeightFraction = (currentVolume / capacityVolume).clamp(
        0.0,
        1.0,
      );
      final double fillY = H * 0.95 - (H * 0.85 * fillHeightFraction);
      final Color baseColor = _getPhColor(ph);

      final liquidPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            baseColor.withValues(alpha: 0.55),
            baseColor.withValues(alpha: 0.25),
          ],
        ).createShader(Rect.fromLTRB(W * 0.16, fillY, W * 0.84, H * 0.97))
        ..style = PaintingStyle.fill;

      final liquidPath = Path()
        ..moveTo(W * 0.16, fillY)
        ..lineTo(W * 0.16, H * 0.95)
        ..arcToPoint(
          Offset(W * 0.25, H * 0.97),
          radius: const Radius.circular(4),
        )
        ..lineTo(W * 0.75, H * 0.97)
        ..arcToPoint(
          Offset(W * 0.84, H * 0.95),
          radius: const Radius.circular(4),
        )
        ..lineTo(W * 0.84, fillY)
        ..close();

      canvas.drawPath(liquidPath, liquidPaint);

      // Liquid surface meniscus (elliptical curve top)
      final surfacePaint = Paint()
        ..color = baseColor.withValues(alpha: 0.8)
        ..style = PaintingStyle.fill;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(W * 0.5, fillY),
          width: W * 0.68,
          height: 6,
        ),
        surfacePaint,
      );

      // Draw precipitate (precipitated solid salt at the bottom)
      if (precipitateAmount > 0.0) {
        final precipitatePaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.85)
          ..style = PaintingStyle.fill;
        final double precipHeight = (precipitateAmount * 12.0).clamp(3.0, 20.0);
        final precipPath = Path()
          ..moveTo(W * 0.17, H * 0.95)
          ..quadraticBezierTo(
            W * 0.5,
            H * 0.95 - precipHeight,
            W * 0.83,
            H * 0.95,
          )
          ..arcToPoint(
            Offset(W * 0.75, H * 0.97),
            radius: const Radius.circular(4),
          )
          ..lineTo(W * 0.25, H * 0.97)
          ..arcToPoint(
            Offset(W * 0.17, H * 0.95),
            radius: const Radius.circular(4),
          );
        canvas.drawPath(precipPath, precipitatePaint);
      }

      // Draw bubbles rising inside liquid
      final bubblePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      final bubbleFill = Paint()
        ..color = Colors.white.withValues(alpha: 0.25)
        ..style = PaintingStyle.fill;

      for (var b in bubbles) {
        final double bubbleX = W * 0.18 + (W * 0.64 * b.xFraction);
        final double bubbleY = fillY + ((H * 0.95 - fillY) * b.yFraction);
        if (bubbleY > fillY) {
          canvas.drawCircle(Offset(bubbleX, bubbleY), b.radius, bubbleFill);
          canvas.drawCircle(Offset(bubbleX, bubbleY), b.radius, bubblePaint);
        }
      }
    }

    // Draw graduation lines (marks)
    final gradPaint = Paint()
      ..color = Colors.white30
      ..strokeWidth = 1.5;
    for (int i = 50; i <= 250; i += 50) {
      final double fraction = i / 250.0;
      final double gradY = H * 0.95 - (H * 0.85 * fraction);
      canvas.drawLine(
        Offset(W * 0.75, gradY),
        Offset(W * 0.83, gradY),
        gradPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _VirtualBeakerPainter oldDelegate) => true;
}

Color _getPhColor(double ph) {
  if (ph < 3.0) return const Color(0xFFEF5350); // Acid (Red)
  if (ph < 6.0) return const Color(0xFFFFB74D); // Soft Acid (Orange)
  if (ph < 8.0) return const Color(0xFF66BB6A); // Neutral (Green)
  if (ph < 11.0) return const Color(0xFF29B6F6); // Weak Base (Blue)
  return const Color(0xFFAB47BC); // Strong Base (Purple)
}

// ─────────────────────────────────────────────────────────────
// MICROSCOPE WIDGET (Premium Scientific Specimen Viewer)
// ─────────────────────────────────────────────────────────────
class MicroscopeWidget extends StatefulWidget {
  const MicroscopeWidget({super.key});

  @override
  State<MicroscopeWidget> createState() => _MicroscopeWidgetState();
}

class _MicroscopeWidgetState extends State<MicroscopeWidget> {
  String _specimen = 'Onion Cell';
  double _magnification = 100.0; // 100x to 1000x
  double _focus = 3.0; // optimal focus is 5.0
  String _activeStain = 'None'; // 'None', 'Iodine', 'Methylene Blue'

  @override
  Widget build(BuildContext context) {
    return GlassmorphicPanel(
      width: 330,
      height: 520,
      borderRadius: BorderRadius.circular(24),
      color: const Color(0xFF1E1E2F).withValues(alpha: 0.85),
      borderColor: const Color(0xFF00E676).withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E676).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.biotech,
                  color: Color(0xFF00E676),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Microscope Viewer',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Specimen Selector
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: DropdownButton<String>(
              value: _specimen,
              isExpanded: true,
              dropdownColor: const Color(0xFF1E1E2F),
              underline: const SizedBox(),
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
              items: const [
                DropdownMenuItem(
                  value: 'Onion Cell',
                  child: Text('Onion Epidermal Cells'),
                ),
                DropdownMenuItem(
                  value: 'Cheek Cell',
                  child: Text('Human Cheek Cells'),
                ),
                DropdownMenuItem(
                  value: 'Bacteria',
                  child: Text('Bacillus Bacteria'),
                ),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _specimen = val);
              },
            ),
          ),
          const SizedBox(height: 10),

          // Eyepiece custom visualizer
          Center(
            child: SizedBox(
              width: 170,
              height: 170,
              child: ClipOval(
                child: CustomPaint(
                  painter: _MicroscopicLensPainter(
                    specimen: _specimen,
                    magnification: _magnification,
                    focus: _focus,
                    activeStain: _activeStain,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Staining selector panel
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Stain Specimen:',
                style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12),
              ),
              Row(
                children: [
                  _buildStainChip('None', Colors.white30),
                  const SizedBox(width: 4),
                  _buildStainChip('Iodine', Colors.amber),
                  const SizedBox(width: 4),
                  _buildStainChip('M. Blue', Colors.blue),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Magnification slider (100x to 1000x)
          Row(
            children: [
              Text(
                'Magnification:',
                style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12),
              ),
              const Spacer(),
              Text(
                '${_magnification.toStringAsFixed(0)}x',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF00E676),
              inactiveTrackColor: Colors.white12,
              thumbColor: const Color(0xFF00E676),
              trackHeight: 3.0,
            ),
            child: Slider(
              min: 100.0,
              max: 1000.0,
              value: _magnification,
              onChanged: (val) {
                setState(() {
                  _magnification = val;
                });
              },
            ),
          ),

          // Focus Adjustment knob
          Row(
            children: [
              Text(
                'Focus Adjustment:',
                style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12),
              ),
              const Spacer(),
              Text(
                (_focus - 5.0).abs() < 0.5 ? 'Focused ✨' : 'Blurry 🌫️',
                style: GoogleFonts.outfit(
                  color: (_focus - 5.0).abs() < 0.5
                      ? Colors.greenAccent
                      : Colors.amberAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF00E676),
              inactiveTrackColor: Colors.white12,
              thumbColor: const Color(0xFF00E676),
              trackHeight: 3.0,
            ),
            child: Slider(
              min: 0.0,
              max: 10.0,
              value: _focus,
              onChanged: (val) {
                setState(() {
                  _focus = val;
                });
              },
            ),
          ),

          const SizedBox(height: 6),
          // Specimen scientific text description
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: SingleChildScrollView(
                child: Text(
                  _getSpecimenDescription(_specimen, _activeStain),
                  style: GoogleFonts.outfit(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStainChip(String name, Color badgeColor) {
    final active =
        _activeStain == name ||
        (_activeStain == 'Methylene Blue' && name == 'M. Blue');
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeStain = (name == 'M. Blue') ? 'Methylene Blue' : name;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active
              ? badgeColor.withValues(alpha: 0.2)
              : Colors.transparent,
          border: Border.all(
            color: active ? badgeColor : Colors.white24,
            width: 1.0,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          name,
          style: TextStyle(
            color: active ? Colors.white : Colors.white54,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  String _getSpecimenDescription(String specimen, String stain) {
    if (specimen == 'Onion Cell') {
      if (stain == 'Iodine') {
        return "Onion epidermal cells stained with Iodine. Staining turns the starch-rich cell walls and prominent nuclei gold/brown. You can clearly identify the rectangular brick-like pattern of cellulose walls.";
      }
      return "Onion epidermal cells under brightfield lens. Without staining, the cytoplasm remains transparent and nuclei are extremely faint to identify.";
    } else if (specimen == 'Cheek Cell') {
      if (stain == 'Methylene Blue') {
        return "Human epithelial cheek cells stained with Methylene Blue. Staining turns the acidic DNA inside the nucleus vibrant blue. Shows single flat, irregular scales containing central dark blue spheres.";
      }
      return "Human cheek cells unstained. Cell membranes are highly transparent and difficult to view in high contrast.";
    } else {
      if (stain == 'Methylene Blue') {
        return "Bacillus bacteria clusters stained with Methylene Blue. The staining makes tiny rod-like prokaryotic organism chains clearly distinguishable as deep violet-blue capsules.";
      }
      return "Tiny Bacillus chains under magnification. Unstained bacteria are highly microscopic and lack structural definition.";
    }
  }
}

class _MicroscopicLensPainter extends CustomPainter {
  final String specimen;
  final double magnification;
  final double focus;
  final String activeStain;

  _MicroscopicLensPainter({
    required this.specimen,
    required this.magnification,
    required this.focus,
    required this.activeStain,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double W = size.width;
    final double H = size.height;
    final center = Offset(W / 2, H / 2);
    final double radius = W / 2;

    // Eyepiece base background color tint based on stain
    Color backColor = const Color(0xFFF1F8E9); // Default white-greenish glow
    if (activeStain == 'Iodine') {
      backColor = const Color(0xFFFFF8E1); // yellow tint
    } else if (activeStain == 'Methylene Blue') {
      backColor = const Color(0xFFE3F2FD); // blue tint
    }

    final backPaint = Paint()
      ..color = backColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, backPaint);

    // Save Layer to apply dynamic focus blur filter
    final double optimalFocus = 5.0;
    final double focusError = (focus - optimalFocus).abs();
    final double blurSigma = (focusError * 1.8).clamp(0.0, 15.0);

    canvas.saveLayer(
      Rect.fromLTWH(0, 0, W, H),
      Paint()
        ..imageFilter = ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
    );

    // Draw gridlines (microscopic eyepiece crosshair)
    final gridPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.06)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(0, H / 2), Offset(W, H / 2), gridPaint);
    canvas.drawLine(Offset(W / 2, 0), Offset(W / 2, H), gridPaint);
    canvas.drawCircle(
      center,
      radius * 0.5,
      Paint()
        ..color = Colors.transparent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = Colors.black.withValues(alpha: 0.04),
    );

    // Specimen Vector Drawings
    final double scale = magnification / 100.0;

    if (specimen == 'Onion Cell') {
      _paintOnionCells(canvas, center, radius, scale);
    } else if (specimen == 'Cheek Cell') {
      _paintCheekCells(canvas, center, radius, scale);
    } else if (specimen == 'Bacteria') {
      _paintBacteria(canvas, center, radius, scale);
    }

    canvas.restore(); // end blur layer

    // Eyepiece lens reflection overlay
    final reflectionPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.3),
          Colors.white.withValues(alpha: 0.0),
          Colors.black.withValues(alpha: 0.15),
        ],
        stops: const [0.0, 0.4, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, W, H))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, reflectionPaint);

    // Eyepiece outer circular frame overlay
    final framePaint = Paint()
      ..color = const Color(0xFF1E1E2F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0;
    canvas.drawCircle(center, radius - 4, framePaint);
  }

  void _paintOnionCells(
    Canvas canvas,
    Offset center,
    double radius,
    double scale,
  ) {
    // Onion cells look like rectangular brick grid layers
    final double cellW = 55.0 * scale;
    final double cellH = 26.0 * scale;

    final cellWallPaint = Paint()
      ..color = (activeStain == 'Iodine')
          ? const Color(0xFF8D6E63)
          : Colors.grey.shade400
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final nucleusPaint = Paint()
      ..color = (activeStain == 'Iodine')
          ? const Color(0xFFB57C1E)
          : Colors.grey.shade300
      ..style = PaintingStyle.fill;

    // Draw multiple rows and columns
    for (double y = -radius - cellH; y < radius + cellH; y += cellH) {
      for (double x = -radius - cellW; x < radius + cellW; x += cellW) {
        // slight offset to make rows look staggered like bricks
        final double offsetX = (y ~/ cellH) % 2 * (cellW * 0.3);
        final rect = Rect.fromLTWH(
          center.dx + x + offsetX,
          center.dy + y,
          cellW,
          cellH,
        );

        // draw cell boundary
        canvas.drawRect(rect, cellWallPaint);

        // Draw internal cell nucleus
        final nucleusCenter = Offset(
          rect.left + cellW * 0.75,
          rect.top + cellH * 0.5,
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: nucleusCenter,
            width: 4.5 * scale,
            height: 3.5 * scale,
          ),
          nucleusPaint,
        );
      }
    }
  }

  void _paintCheekCells(
    Canvas canvas,
    Offset center,
    double radius,
    double scale,
  ) {
    // Cheek cells are irregular scale-like flat polygons
    final double size = 45.0 * scale;

    final cellMembranePaint = Paint()
      ..color = (activeStain == 'Methylene Blue')
          ? const Color(0xFF1976D2)
          : Colors.grey.shade400
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    final cellBodyPaint = Paint()
      ..color = (activeStain == 'Methylene Blue')
          ? const Color(0xFFBBDEFB).withValues(alpha: 0.4)
          : Colors.grey.shade100.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    final nucleusPaint = Paint()
      ..color = (activeStain == 'Methylene Blue')
          ? const Color(0xFF0D47A1)
          : Colors.grey.shade500
      ..style = PaintingStyle.fill;

    // Fixed locations for a few cheek cells
    final List<Offset> cellPositions = [
      Offset(center.dx - 20, center.dy - 25),
      Offset(center.dx + 25, center.dy + 15),
      Offset(center.dx - 30, center.dy + 35),
    ];

    for (var pos in cellPositions) {
      // Create irregular polygon path
      final path = Path()
        ..moveTo(pos.dx - size * 0.4, pos.dy - size * 0.3)
        ..lineTo(pos.dx + size * 0.5, pos.dy - size * 0.4)
        ..lineTo(pos.dx + size * 0.45, pos.dy + size * 0.3)
        ..lineTo(pos.dx - size * 0.3, pos.dy + size * 0.5)
        ..lineTo(pos.dx - size * 0.5, pos.dy + size * 0.1)
        ..close();

      canvas.drawPath(path, cellBodyPaint);
      canvas.drawPath(path, cellMembranePaint);

      // Draw nucleus
      canvas.drawCircle(
        Offset(pos.dx + size * 0.05, pos.dy + size * 0.05),
        4.5 * scale,
        nucleusPaint,
      );
    }
  }

  void _paintBacteria(
    Canvas canvas,
    Offset center,
    double radius,
    double scale,
  ) {
    // Bacteria (Bacillus) are tiny rods in chains
    final double rodW = 14.0 * scale;
    final double rodH = 4.0 * scale;

    final bacColor = (activeStain == 'Methylene Blue')
        ? const Color(0xFF5E35B1)
        : Colors.grey.shade500;
    final bacPaint = Paint()
      ..color = bacColor
      ..style = PaintingStyle.fill;

    final List<Offset> bacPositions = [
      Offset(center.dx - 40, center.dy - 30),
      Offset(center.dx - 20, center.dy - 35),
      Offset(center.dx, center.dy - 40),

      Offset(center.dx + 10, center.dy + 20),
      Offset(center.dx + 25, center.dy + 10),
      Offset(center.dx + 35, center.dy - 5),

      Offset(center.dx - 20, center.dy + 20),
      Offset(center.dx - 35, center.dy + 25),
    ];

    for (var pos in bacPositions) {
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(0.3); // rotate slightly
      final rrect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: rodW, height: rodH),
        const Radius.circular(2),
      );
      canvas.drawRRect(rrect, bacPaint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _MicroscopicLensPainter oldDelegate) => true;
}
