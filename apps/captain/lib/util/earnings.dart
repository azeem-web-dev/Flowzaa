import 'package:flowzaa_shared/flowzaa_shared.dart';

/// The moment a ride's earnings count towards (completion, falling back to
/// creation for older docs).
DateTime? rideEarnedAt(Ride r) => r.completedAt ?? r.createdAt;

/// Aggregated earnings figures computed from the captain's ride history.
/// Only completed rides count; amounts are `fare.total` (0% commission —
/// the full fare belongs to the captain).
class EarningsSummary {
  final double today;
  final int todayTrips;
  final double week;
  final int weekTrips;
  final double allTime;
  final int allTimeTrips;

  const EarningsSummary({
    this.today = 0,
    this.todayTrips = 0,
    this.week = 0,
    this.weekTrips = 0,
    this.allTime = 0,
    this.allTimeTrips = 0,
  });

  factory EarningsSummary.fromRides(List<Ride> rides, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final weekStart = n.subtract(const Duration(days: 7));

    double today = 0, week = 0, all = 0;
    int todayTrips = 0, weekTrips = 0, allTrips = 0;

    for (final r in rides) {
      if (r.status != RideStatus.completed) continue;
      final at = rideEarnedAt(r);
      final amount = r.fare.total;
      all += amount;
      allTrips++;
      if (at == null) continue;
      if (at.year == n.year && at.month == n.month && at.day == n.day) {
        today += amount;
        todayTrips++;
      }
      if (at.isAfter(weekStart)) {
        week += amount;
        weekTrips++;
      }
    }

    return EarningsSummary(
      today: today,
      todayTrips: todayTrips,
      week: week,
      weekTrips: weekTrips,
      allTime: all,
      allTimeTrips: allTrips,
    );
  }
}
