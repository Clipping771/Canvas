import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/chemistry_service.dart';

// ─────────────────────────────────────────────────────────────
// Atom colour table (CPK colouring — standard in chemistry)
// ─────────────────────────────────────────────────────────────
const Map<String, Color> _atomColors = {
  'C':  Color(0xFF303030),
  'H':  Color(0xFF888888),
  'O':  Color(0xFFE03030),
  'N':  Color(0xFF3050D0),
  'S':  Color(0xFFD0B020),
  'P':  Color(0xFFD06020),
  'F':  Color(0xFF20C050),
  'Cl': Color(0xFF20B030),
  'Br': Color(0xFF8B3020),
  'I':  Color(0xFF6020A0),
  'Na': Color(0xFF8040C0),
  'K':  Color(0xFF8040C0),
  'Ca': Color(0xFF808080),
  'Fe': Color(0xFFD04000),
  'Mg': Color(0xFF00A000),
  'Zn': Color(0xFF808080),
};

Color _colorFor(String symbol) =>
    _atomColors[symbol] ?? const Color(0xFF606060);

// ─────────────────────────────────────────────────────────────
// ChemistryWidget
// Renders a ChemMolecule as a clean vector 2D structure diagram.
// ─────────────────────────────────────────────────────────────
class ChemistryWidget extends StatelessWidget {
  final ChemMolecule molecule;
  final double width;
  final double height;
  final Color strokeColor;
  final double strokeWidth;

  const ChemistryWidget({
    super.key,
    required this.molecule,
    this.width = 300,
    this.height = 260,
    this.strokeColor = const Color(0xFF222222),
    this.strokeWidth = 2.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _MolPainter(
          molecule: molecule,
          strokeColor: strokeColor,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ChemistryRevealWidget
// Same as above but reveals left-to-right via animationProgress (0..1).
// ─────────────────────────────────────────────────────────────
class ChemistryRevealWidget extends StatelessWidget {
  final ChemMolecule molecule;
  final double width;
  final double height;
  final double animationProgress; // 0..1
  final Color strokeColor;

  const ChemistryRevealWidget({
    super.key,
    required this.molecule,
    required this.animationProgress,
    this.width = 300,
    this.height = 260,
    this.strokeColor = const Color(0xFF222222),
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: ClipRect(
        child: Align(
          alignment: Alignment.centerLeft,
          widthFactor: animationProgress.clamp(0.0, 1.0),
          child: SizedBox(
            width: width,
            height: height,
            child: CustomPaint(
              painter: _MolPainter(
                molecule: molecule,
                strokeColor: strokeColor,
                strokeWidth: 2.0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Internal painter
// ─────────────────────────────────────────────────────────────
class _MolPainter extends CustomPainter {
  final ChemMolecule molecule;
  final Color strokeColor;
  final double strokeWidth;

  _MolPainter({
    required this.molecule,
    required this.strokeColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (molecule.atoms.isEmpty) return;

    // ── 1. Compute bounding box of atom coords ─────────────
    double minX = molecule.atoms.first.x, maxX = minX;
    double minY = molecule.atoms.first.y, maxY = minY;
    for (final a in molecule.atoms) {
      if (a.x < minX) minX = a.x;
      if (a.x > maxX) maxX = a.x;
      if (a.y < minY) minY = a.y;
      if (a.y > maxY) maxY = a.y;
    }

    final molW = maxX - minX;
    final molH = maxY - minY;
    if (molW == 0 && molH == 0) return; // single atom

    // ── 2. Fit into canvas with padding ───────────────────
    const padding = 36.0;
    final scaleX = molW > 0 ? (size.width - padding * 2) / molW : 1.0;
    final scaleY = molH > 0 ? (size.height - padding * 2 - 24) / molH : 1.0;
    final scale = math.min(scaleX, scaleY);

    // Centre the molecule
    final renderW = molW * scale;
    final renderH = molH * scale;
    final offsetX = (size.width - renderW) / 2 - minX * scale;
    final offsetY = (size.height - 24 - renderH) / 2 - minY * scale;

    Offset toScreen(ChemAtom a) =>
        Offset(a.x * scale + offsetX, a.y * scale + offsetY);

    // ── 3. Draw bonds ─────────────────────────────────────
    final bondPaint = Paint()
      ..color = strokeColor
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final bond in molecule.bonds) {
      if (bond.atomIdx1 >= molecule.atoms.length ||
          bond.atomIdx2 >= molecule.atoms.length) continue;

      final p1 = toScreen(molecule.atoms[bond.atomIdx1]);
      final p2 = toScreen(molecule.atoms[bond.atomIdx2]);

      if (bond.order == 1) {
        canvas.drawLine(p1, p2, bondPaint);
      } else if (bond.order == 2) {
        _drawDoubleBond(canvas, p1, p2, bondPaint);
      } else if (bond.order >= 3) {
        _drawTripleBond(canvas, p1, p2, bondPaint);
      }
    }

    // ── 4. Draw atom labels ───────────────────────────────
    // Skip 'C' (carbon) — structural formula convention
    for (final atom in molecule.atoms) {
      if (atom.symbol == 'C') continue; // implicit carbon
      final pos = toScreen(atom);
      final color = _colorFor(atom.symbol);

      // White background circle to erase bond line under label
      canvas.drawCircle(
        pos,
        8.5,
        Paint()..color = Colors.white,
      );

      // Atom symbol
      final tp = TextPainter(
        text: TextSpan(
          text: atom.symbol,
          style: TextStyle(
            color: color,
            fontSize: atom.symbol.length > 1 ? 11 : 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(
        canvas,
        Offset(pos.dx - tp.width / 2, pos.dy - tp.height / 2),
      );
    }

    // ── 5. Footer: formula + name ─────────────────────────
    final label = '${molecule.formula}  ·  ${molecule.name}';
    final footerTp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: strokeColor.withOpacity(0.6),
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 1,
    )..layout(maxWidth: size.width - 16);

    footerTp.paint(
      canvas,
      Offset(
        (size.width - footerTp.width) / 2,
        size.height - footerTp.height - 4,
      ),
    );
  }

  void _drawDoubleBond(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len == 0) return;
    final nx = -dy / len * 2.5; // normal offset
    final ny = dx / len * 2.5;

    canvas.drawLine(
        Offset(p1.dx + nx, p1.dy + ny), Offset(p2.dx + nx, p2.dy + ny), paint);
    canvas.drawLine(
        Offset(p1.dx - nx, p1.dy - ny), Offset(p2.dx - nx, p2.dy - ny), paint);
  }

  void _drawTripleBond(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len == 0) return;
    final nx = -dy / len * 3.5;
    final ny = dx / len * 3.5;

    canvas.drawLine(p1, p2, paint); // centre line
    canvas.drawLine(
        Offset(p1.dx + nx, p1.dy + ny), Offset(p2.dx + nx, p2.dy + ny), paint);
    canvas.drawLine(
        Offset(p1.dx - nx, p1.dy - ny), Offset(p2.dx - nx, p2.dy - ny), paint);
  }

  @override
  bool shouldRepaint(covariant _MolPainter old) =>
      old.molecule != molecule ||
      old.strokeColor != strokeColor ||
      old.strokeWidth != strokeWidth;
}
