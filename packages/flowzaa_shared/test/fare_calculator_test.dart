import 'package:flowzaa_shared/flowzaa_shared.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calc = FareCalculator();
  final config = FareConfig.defaults;

  test('bike fare = base + perKm*km + perMin*min', () {
    // 5 km, 10 min → 20 + 6.5*5 + 0.6*10 = 20 + 32.5 + 6 = 58.5
    final fare = calc.compute(
      config: config,
      type: VehicleType.bike,
      distanceMeters: 5000,
      durationSeconds: 600,
    );
    expect(fare.base, 20);
    expect(fare.distanceFare, 32.5);
    expect(fare.timeFare, 6);
    expect(fare.total, 58.5);
    expect(fare.currency, 'INR');
  });

  test('enforces the minimum fare on very short trips', () {
    // 0.2 km, 1 min → 20 + 1.3 + 0.6 = 21.9, but bike min is 25.
    final fare = calc.compute(
      config: config,
      type: VehicleType.bike,
      distanceMeters: 200,
      durationSeconds: 60,
    );
    expect(fare.total, 25);
  });

  test('surge multiplier is applied after the floor', () {
    final fare = calc.compute(
      config: config,
      type: VehicleType.car,
      distanceMeters: 10000,
      durationSeconds: 1200,
      surgeMultiplier: 1.5,
    );
    // car: 50 + 14*10 + 1.2*20 = 50 + 140 + 24 = 214; *1.5 = 321
    expect(fare.surge, 107);
    expect(fare.total, 321);
  });

  test('every vehicle type has rates', () {
    for (final t in VehicleType.values) {
      final fare = calc.compute(
        config: config,
        type: t,
        distanceMeters: 3000,
        durationSeconds: 480,
      );
      expect(fare.total, greaterThan(0), reason: 'no fare for ${t.label}');
    }
  });
}
