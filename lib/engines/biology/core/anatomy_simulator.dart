/// Represents a basic human anatomical system
enum AnatomySystem {
  skeletal,
  muscular,
  nervous,
  cardiovascular,
  respiratory,
  digestive,
}

class AnatomySimulator {
  final Map<String, List<String>> _systemComponents = {
    'Skeletal System': ['Skull', 'Spine', 'Ribcage', 'Femur', 'Humerus'],
    'Cardiovascular System': [
      'Heart',
      'Aorta',
      'Vena Cava',
      'Pulmonary Artery',
      'Capillaries',
    ],
    'Nervous System': ['Brain', 'Spinal Cord', 'Peripheral Nerves', 'Neurons'],
    'Muscular System': ['Biceps', 'Triceps', 'Glutes', 'Deltoids', 'Pectorals'],
  };

  final Map<String, String> _systemDescriptions = {
    'Skeletal System':
        'Provides structural support and protection for internal organs.',
    'Cardiovascular System':
        'Circulates blood and transports nutrients, oxygen, and hormones.',
    'Nervous System':
        'Coordinates actions by transmitting signals to and from different parts of the body.',
    'Muscular System':
        'Permits movement of the body, maintains posture, and circulates blood.',
  };

  List<String> getOrgansForSystem(String systemName) {
    return _systemComponents[systemName] ?? [];
  }

  String getSystemDescription(String systemName) {
    return _systemDescriptions[systemName] ??
        'Select a system to view details.';
  }
}
