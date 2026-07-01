import '../models/fare.dart';
import '../models/vehicle_type.dart';
import 'fare_config.dart';

/// Pure fare math: total = max(min, base + perKm*km + perMin*min) * surge.
///
/// Deliberately side-effect free so it can be unit-tested and reused by both
/// apps. Flowzaa adds 0% commission — the total is exactly what the rider owes
/// the captain.
class FareCalculator {
  const FareCalculator();

  static double _round2(double v) => (v * 100).roundToDouble() / 100;

  Fare compute({
    required FareConfig config,
    required VehicleType type,
    required double distanceMeters,
    required double durationSeconds,
    double surgeMultiplier = 1.0,
  }) {
    final rates = config.ratesFor(type);
    final km = distanceMeters / 1000.0;
    final mins = durationSeconds / 60.0;

    final distanceFare = _round2(rates.perKm * km);
    final timeFare = _round2(rates.perMin * mins);
    var subtotal = rates.base + distanceFare + timeFare;

    // Apply the floor before surge so the minimum is respected.
    if (subtotal < rates.min) subtotal = rates.min;

    final surged = subtotal * surgeMultiplier;
    final surgeAmount = _round2(surged - subtotal);

    return Fare(
      base: rates.base,
      distanceFare: distanceFare,
      timeFare: timeFare,
      surge: surgeAmount,
      total: _round2(surged),
      currency: config.currency,
    );
  }
}
