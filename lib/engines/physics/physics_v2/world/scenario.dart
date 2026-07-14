import 'dart:ui';

/// Defines the environmental conditions for the simulation (Layer 4 integration).
class PhysicsScenario {
  final String name;
  final Offset gravity;
  final double atmosphereDensity; // Affects air resistance

  const PhysicsScenario({
    required this.name,
    required this.gravity,
    this.atmosphereDensity = 1.225, // Earth sea level roughly
  });

  // Pre-defined scenarios (The Scenario Builder foundation)
  static const PhysicsScenario earth = PhysicsScenario(
    name: 'Earth',
    gravity: Offset(0, 9.81), // Base gravity in m/s^2
  );

  static const PhysicsScenario moon = PhysicsScenario(
    name: 'Moon',
    gravity: Offset(0, 1.62),
    atmosphereDensity: 0.0, // No air
  );

  static const PhysicsScenario mars = PhysicsScenario(
    name: 'Mars',
    gravity: Offset(0, 3.72),
    atmosphereDensity: 0.02, // Thin atmosphere
  );

  static const PhysicsScenario deepSpace = PhysicsScenario(
    name: 'Deep Space',
    gravity: Offset.zero,
    atmosphereDensity: 0.0,
  );
}
