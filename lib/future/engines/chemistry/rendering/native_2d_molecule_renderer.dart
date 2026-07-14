import 'package:flutter/widgets.dart';
import 'package:vinci_board/engines/chemistry/chemistry_service.dart';
import 'package:vinci_board/presentation/widgets/chemistry_widget.dart';
import 'package:vinci_board/engines/chemistry/rendering/i_molecule_renderer.dart';

/// A native 2D renderer implementation using Flutter Canvas.
/// This acts as an adapter around the existing ChemistryWidget.
class Native2DMoleculeRenderer implements IMoleculeRenderer {
  ChemMolecule? _molecule;

  @override
  Future<void> initialize() async {
    // Nothing async to initialize for native 2D canvas
  }

  @override
  void loadMolecule(ChemMolecule molecule) {
    _molecule = molecule;
  }

  @override
  void loadRawData(String data, String format) {
    // 2D renderer does not support raw PDB/CIF directly without parsing it first.
    // For now, no-op or throw unsupported.
  }

  @override
  void clear() {
    _molecule = null;
  }

  @override
  void setStyle(String styleName) {
    // Currently native 2D only has one style (CPK 2D structural diagram).
  }

  @override
  Widget buildWidget(
    BuildContext context, {
    double width = 300,
    double height = 260,
  }) {
    if (_molecule == null) {
      return SizedBox(
        width: width,
        height: height,
        child: const Center(child: Text("No molecule loaded")),
      );
    }

    return ChemistryWidget(molecule: _molecule!, width: width, height: height);
  }
}
