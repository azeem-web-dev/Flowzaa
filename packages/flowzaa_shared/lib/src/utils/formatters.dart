/// Display formatting helpers.
class Fmt {
  /// ₹64.50 -> "₹65" (rounded, no decimals for whole-rupee display).
  static String rupees(num amount, {bool decimals = false}) {
    if (decimals) return '₹${amount.toStringAsFixed(2)}';
    return '₹${amount.round()}';
  }

  /// 5300 m -> "5.3 km"; 800 m -> "800 m".
  static String distance(num meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  /// 900 s -> "15 min"; 45 s -> "1 min".
  static String duration(num seconds) {
    final mins = (seconds / 60).round();
    if (mins < 1) return '1 min';
    if (mins < 60) return '$mins min';
    final h = mins ~/ 60;
    final m = mins % 60;
    return m == 0 ? '$h hr' : '$h hr $m min';
  }

  /// Mask a phone for privacy in lists: +919000000001 -> "+91 90000 00001".
  static String phone(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length >= 12) {
      final cc = digits.substring(0, digits.length - 10);
      final rest = digits.substring(digits.length - 10);
      return '+$cc ${rest.substring(0, 5)} ${rest.substring(5)}';
    }
    return raw;
  }
}
