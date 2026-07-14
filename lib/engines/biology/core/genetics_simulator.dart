/// Simulates genetics, DNA transcription, and translation.
class GeneticsSimulator {
  static const Map<String, String> _codonTable = {
    'UUU': 'Phe',
    'UUC': 'Phe',
    'UUA': 'Leu',
    'UUG': 'Leu',
    'CUU': 'Leu',
    'CUC': 'Leu',
    'CUA': 'Leu',
    'CUG': 'Leu',
    'AUU': 'Ile',
    'AUC': 'Ile',
    'AUA': 'Ile',
    'AUG': 'Met',
    'GUU': 'Val',
    'GUC': 'Val',
    'GUA': 'Val',
    'GUG': 'Val',
    'UCU': 'Ser',
    'UCC': 'Ser',
    'UCA': 'Ser',
    'UCG': 'Ser',
    'CCU': 'Pro',
    'CCC': 'Pro',
    'CCA': 'Pro',
    'CCG': 'Pro',
    'ACU': 'Thr',
    'ACC': 'Thr',
    'ACA': 'Thr',
    'ACG': 'Thr',
    'GCU': 'Ala',
    'GCC': 'Ala',
    'GCA': 'Ala',
    'GCG': 'Ala',
    'UAU': 'Tyr',
    'UAC': 'Tyr',
    'UAA': 'STOP',
    'UAG': 'STOP',
    'CAU': 'His',
    'CAC': 'His',
    'CAA': 'Gln',
    'CAG': 'Gln',
    'AAU': 'Asn',
    'AAC': 'Asn',
    'AAA': 'Lys',
    'AAG': 'Lys',
    'GAU': 'Asp',
    'GAC': 'Asp',
    'GAA': 'Glu',
    'GAG': 'Glu',
    'UGU': 'Cys',
    'UGC': 'Cys',
    'UGA': 'STOP',
    'UGG': 'Trp',
    'CGU': 'Arg',
    'CGC': 'Arg',
    'CGA': 'Arg',
    'CGG': 'Arg',
    'AGU': 'Ser',
    'AGC': 'Ser',
    'AGA': 'Arg',
    'AGG': 'Arg',
    'GGU': 'Gly',
    'GGC': 'Gly',
    'GGA': 'Gly',
    'GGG': 'Gly',
  };

  /// Transcribes DNA into mRNA (replaces T with U and finds complement if it was a template strand)
  /// For simplicity, assume coding strand provided, just replace T with U.
  String transcribe(String dnaSequence) {
    return dnaSequence.toUpperCase().replaceAll('T', 'U');
  }

  /// Translates mRNA into a sequence of amino acids (Protein)
  String translate(String mrnaSequence) {
    String protein = "";
    String mrna = mrnaSequence.toUpperCase();

    // Find START codon (AUG)
    int startIndex = mrna.indexOf('AUG');
    if (startIndex == -1) return "No START codon found.";

    for (int i = startIndex; i < mrna.length - 2; i += 3) {
      String codon = mrna.substring(i, i + 3);
      String aminoAcid = _codonTable[codon] ?? '?';

      if (aminoAcid == 'STOP') {
        break; // End translation on STOP codon
      }

      protein += (protein.isEmpty ? "" : "-") + aminoAcid;
    }

    return protein.isEmpty ? "Invalid sequence" : protein;
  }

  /// Calculates Punnett Square probabilities for a single trait (e.g. Aa x Aa)
  Map<String, double> punnettSquare(String parent1, String parent2) {
    if (parent1.length != 2 || parent2.length != 2) return {};

    List<String> outcomes = [];
    for (int i = 0; i < 2; i++) {
      for (int j = 0; j < 2; j++) {
        // Sort alleles so 'Aa' and 'aA' are both 'Aa' (Dominant first)
        String allele1 = parent1[i];
        String allele2 = parent2[j];

        String outcome =
            (allele1.toUpperCase() == allele1 ||
                allele2.toUpperCase() == allele2)
            ? (allele1.toUpperCase() == allele1
                  ? allele1 + allele2
                  : allele2 + allele1)
            : allele1 + allele2;

        // Final normalization: if one is uppercase and other lowercase, uppercase comes first
        if (outcome[0].toLowerCase() == outcome[0] &&
            outcome[1].toUpperCase() == outcome[1]) {
          outcome = outcome[1] + outcome[0];
        }

        outcomes.add(outcome);
      }
    }

    Map<String, double> probabilities = {};
    for (String outcome in outcomes) {
      probabilities[outcome] = (probabilities[outcome] ?? 0) + 0.25;
    }
    return probabilities;
  }
}
