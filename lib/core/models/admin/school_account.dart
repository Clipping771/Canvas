class SchoolAccount {
  final String id;
  final String name;
  final String districtId;
  final String billingTier; // e.g. "Free", "Pro", "Enterprise"
  final int activeLicenses;
  final int maxLicenses;

  SchoolAccount({
    required this.id,
    required this.name,
    required this.districtId,
    required this.billingTier,
    required this.activeLicenses,
    required this.maxLicenses,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'districtId': districtId,
    'billingTier': billingTier,
    'activeLicenses': activeLicenses,
    'maxLicenses': maxLicenses,
  };

  factory SchoolAccount.fromJson(Map<String, dynamic> json) => SchoolAccount(
    id: json['id'] as String,
    name: json['name'] as String,
    districtId: json['districtId'] as String,
    billingTier: json['billingTier'] as String,
    activeLicenses: (json['activeLicenses'] as num).toInt(),
    maxLicenses: (json['maxLicenses'] as num).toInt(),
  );
}
