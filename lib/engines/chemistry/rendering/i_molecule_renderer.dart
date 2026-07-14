import 'package:flutter/widgets.dart';
import 'package:vinci_board/engines/chemistry/chemistry_service.dart';

/// Abstraction Layer for rendering chemical molecules.
/// This ensures the Chemistry Engine is completely decoupled from the specific rendering technology (e.g. Flutter Canvas, 3Dmol.js, ThreeJS).
abstract class IMoleculeRenderer {
  /// Initializes the renderer engine (e.g. loading web views, allocating WebGL contexts)
  Future<void> initialize();

  /// Loads a molecule model into the renderer.
  void loadMolecule(ChemMolecule molecule);

  /// Loads a raw PDB or CIF string into the renderer (primarily for 3D renderers).
  void loadRawData(String data, String format);

  /// Clears the currently rendered molecule.
  void clear();

  /// Sets rendering style (e.g. 'stick', 'sphere', 'cartoon')
  void setStyle(String styleName);

  /// Builds the Flutter Widget that encapsulates this renderer.
  Widget buildWidget(BuildContext context, {double width, double height});
}
