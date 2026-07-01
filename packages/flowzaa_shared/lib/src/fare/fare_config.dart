import '../models/vehicle_type.dart';

/// Per-vehicle-type pricing parameters (mirrors config/fares.types.*).
class FareRates {
  final double base;
  final double perKm;
  final double perMin;
  final double min;

  const FareRates({
    required this.base,
    required this.perKm,
    required this.perMin,
    required this.min,
  });

  factory FareRates.fromMap(Map<String, dynamic> m) => FareRates(
        base: (m['base'] as num?)?.toDouble() ?? 0,
        perKm: (m['perKm'] as num?)?.toDouble() ?? 0,
        perMin: (m['perMin'] as num?)?.toDouble() ?? 0,
        min: (m['min'] as num?)?.toDouble() ?? 0,
      );
}

/// The whole fare config document (config/fares).
class FareConfig {
  final String currency;
  final double searchRadiusKm;
  final Map<VehicleType, FareRates> rates;

  const FareConfig({
    required this.currency,
    required this.searchRadiusKm,
    required this.rates,
  });

  FareRates ratesFor(VehicleType type) =>
      rates[type] ?? rates[VehicleType.bike]!;

  /// Sensible India defaults, used until config/fares is fetched.
  static FareConfig get defaults => const FareConfig(
        currency: 'INR',
        searchRadiusKm: 5,
        rates: {
          VehicleType.bike:
              FareRates(base: 20, perKm: 6.5, perMin: 0.6, min: 25),
          VehicleType.auto: FareRates(base: 30, perKm: 9, perMin: 0.8, min: 35),
          VehicleType.car: FareRates(base: 50, perKm: 14, perMin: 1.2, min: 70),
          VehicleType.parcel:
              FareRates(base: 25, perKm: 8, perMin: 0.7, min: 30),
        },
      );

  factory FareConfig.fromMap(Map<String, dynamic> m) {
    final typesMap = (m['types'] as Map?)?.cast<String, dynamic>() ?? {};
    final rates = <VehicleType, FareRates>{};
    for (final type in VehicleType.values) {
      final raw = typesMap[type.id];
      if (raw is Map) {
        rates[type] = FareRates.fromMap(raw.cast<String, dynamic>());
      } else {
        rates[type] = defaults.ratesFor(type);
      }
    }
    return FareConfig(
      currency: m['currency'] as String? ?? 'INR',
      searchRadiusKm: (m['searchRadiusKm'] as num?)?.toDouble() ?? 5,
      rates: rates,
    );
  }
}
