import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Atom in a 2D molecule layout
class ChemAtom {
  final String symbol;
  final double x; // in Angstroms (PubChem layout coords)
  final double y;
  ChemAtom({required this.symbol, required this.x, required this.y});
}

/// Bond between two atoms
class ChemBond {
  final int atomIdx1;
  final int atomIdx2;
  final int order; // 1 = single, 2 = double, 3 = triple
  ChemBond({required this.atomIdx1, required this.atomIdx2, required this.order});
}

/// Full parsed molecule ready for rendering
class ChemMolecule {
  final String name;
  final String formula;
  final List<ChemAtom> atoms;
  final List<ChemBond> bonds;
  ChemMolecule({
    required this.name,
    required this.formula,
    required this.atoms,
    required this.bonds,
  });
}

/// In-memory SMILES/molecule cache — formula never changes so TTL = infinite
final Map<String, ChemMolecule> _cache = {};

class ChemistryService {
  static const String _pubchemBase =
      'https://pubchem.ncbi.nlm.nih.gov/rest/pug';

  /// Fetch molecule from cache or PubChem.
  /// Returns null if the formula is unknown or network fails.
  static Future<ChemMolecule?> fetchMolecule(String query) async {
    final key = query.trim().toLowerCase();
    if (_cache.containsKey(key)) return _cache[key];

    try {
      // Step 1: resolve name → CID (JSON, CORS-safe on web via PubChem JSONP/CORS)
      final cidUrl =
          '$_pubchemBase/compound/name/${Uri.encodeComponent(query)}/cids/JSON';
      final cidRes = await http.get(Uri.parse(cidUrl)).timeout(
            const Duration(seconds: 10),
          );
      if (cidRes.statusCode != 200) return null;
      final cidData = jsonDecode(cidRes.body);
      final cid = cidData['IdentifierList']['CID'][0] as int;

      // Step 2: fetch 2D coordinates as SDF (text/plain — no CORS issues)
      final sdfUrl = '$_pubchemBase/compound/cid/$cid/SDF?record_type=2d';
      final sdfRes = await http.get(Uri.parse(sdfUrl)).timeout(
            const Duration(seconds: 12),
          );
      if (sdfRes.statusCode != 200) return null;

      // Step 3: also fetch the IUPAC name + formula
      final propUrl =
          '$_pubchemBase/compound/cid/$cid/property/MolecularFormula,IUPACName/JSON';
      final propRes = await http.get(Uri.parse(propUrl)).timeout(
            const Duration(seconds: 8),
          );
      String formula = query;
      String iupacName = query;
      if (propRes.statusCode == 200) {
        final propData = jsonDecode(propRes.body);
        final props = propData['PropertyTable']['Properties'][0];
        formula = props['MolecularFormula'] ?? query;
        iupacName = props['IUPACName'] ?? query;
      }

      // Step 4: parse SDF to atoms + bonds
      final mol = _parseSdf(sdfRes.body, name: iupacName, formula: formula);
      if (mol != null) {
        _cache[key] = mol;
      }
      return mol;
    } catch (e) {
      debugPrint('ChemistryService: failed to fetch "$query" — $e');
      return null;
    }
  }

  /// Parse a V2000 MOL/SDF block into ChemMolecule.
  static ChemMolecule? _parseSdf(String sdf,
      {required String name, required String formula}) {
    try {
      final lines = sdf.split('\n');
      // Find the counts line (line index 3 in a standalone MOL block)
      int molStart = 0;
      for (int i = 0; i < lines.length; i++) {
        if (lines[i].trimRight().endsWith('V2000') ||
            lines[i].trimRight().endsWith('V3000')) {
          molStart = i;
          break;
        }
      }

      // Counts line: aaabbblllfffcccsssxxxrrrpppiiimmmvvvvvv
      final countsLine = lines[molStart];
      if (countsLine.length < 6) return null;

      final atomCount = int.tryParse(countsLine.substring(0, 3).trim()) ?? 0;
      final bondCount = int.tryParse(countsLine.substring(3, 6).trim()) ?? 0;

      final atoms = <ChemAtom>[];
      final bonds = <ChemBond>[];

      // Atom block starts at molStart + 1
      for (int i = 0; i < atomCount; i++) {
        final line = lines[molStart + 1 + i];
        if (line.length < 31) continue;
        final x = double.tryParse(line.substring(0, 10).trim()) ?? 0.0;
        final y = double.tryParse(line.substring(10, 20).trim()) ?? 0.0;
        final symbol = line.substring(31, 34).trim();
        atoms.add(ChemAtom(symbol: symbol, x: x, y: y));
      }

      // Bond block starts at molStart + 1 + atomCount
      for (int i = 0; i < bondCount; i++) {
        final line = lines[molStart + 1 + atomCount + i];
        if (line.length < 9) continue;
        final a1 = (int.tryParse(line.substring(0, 3).trim()) ?? 1) - 1;
        final a2 = (int.tryParse(line.substring(3, 6).trim()) ?? 1) - 1;
        final order = int.tryParse(line.substring(6, 9).trim()) ?? 1;
        bonds.add(ChemBond(atomIdx1: a1, atomIdx2: a2, order: order));
      }

      if (atoms.isEmpty) return null;
      return ChemMolecule(
          name: name, formula: formula, atoms: atoms, bonds: bonds);
    } catch (e) {
      debugPrint('ChemistryService._parseSdf: $e');
      return null;
    }
  }
}
