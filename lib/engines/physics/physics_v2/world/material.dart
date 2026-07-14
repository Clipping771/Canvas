/// Defines the physical properties of a surface or volume in the simulation.
class PhysicsMaterial {
  /// The mass density of the material (kg/m^2 in 2D).
  final double density;

  /// Coefficient of restitution (bounciness). 0 = perfectly inelastic, 1 = perfectly elastic.
  final double restitution;

  /// Coefficient of static friction.
  final double staticFriction;

  /// Coefficient of kinetic (sliding) friction.
  final double kineticFriction;

  const PhysicsMaterial({
    this.density = 1.0,
    this.restitution = 0.5,
    this.staticFriction = 0.5,
    this.kineticFriction = 0.3,
  });

  // Common Materials
  static const PhysicsMaterial rock = PhysicsMaterial(
    density: 2.5,
    restitution: 0.1,
    staticFriction: 0.8,
    kineticFriction: 0.6,
  );

  static const PhysicsMaterial rubber = PhysicsMaterial(
    density: 1.1,
    restitution: 0.9,
    staticFriction: 0.9,
    kineticFriction: 0.7,
  );

  static const PhysicsMaterial ice = PhysicsMaterial(
    density: 0.9,
    restitution: 0.05,
    staticFriction: 0.05,
    kineticFriction: 0.02,
  );

  static const PhysicsMaterial steel = PhysicsMaterial(
    density: 7.8,
    restitution: 0.2,
    staticFriction: 0.6,
    kineticFriction: 0.4,
  );
}
