/// A computed fare breakdown for a ride. Amounts are in rupees (numbers), e.g.
/// 64.5 == ₹64.50. Flowzaa keeps 0% — this is the full amount the rider pays
/// the captain directly.
class Fare {
  final double base;
  final double distanceFare;
  final double timeFare;
  final double surge;
  final double total;
  final String currency;

  const Fare({
    required this.base,
    required this.distanceFare,
    required this.timeFare,
    this.surge = 0,
    required this.total,
    this.currency = 'INR',
  });

  Map<String, dynamic> toMap() => {
        'base': base,
        'distanceFare': distanceFare,
        'timeFare': timeFare,
        'surge': surge,
        'total': total,
        'currency': currency,
      };

  factory Fare.fromMap(Map<String, dynamic>? map) {
    map ??= const {};
    return Fare(
      base: (map['base'] as num?)?.toDouble() ?? 0,
      distanceFare: (map['distanceFare'] as num?)?.toDouble() ?? 0,
      timeFare: (map['timeFare'] as num?)?.toDouble() ?? 0,
      surge: (map['surge'] as num?)?.toDouble() ?? 0,
      total: (map['total'] as num?)?.toDouble() ?? 0,
      currency: map['currency'] as String? ?? 'INR',
    );
  }
}
