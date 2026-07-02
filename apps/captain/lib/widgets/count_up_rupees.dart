import 'package:flowzaa_shared/flowzaa_shared.dart';
import 'package:flutter/material.dart';

/// A rupee amount that counts up smoothly to [value] whenever it changes.
class CountUpRupees extends StatelessWidget {
  final double value;
  final TextStyle style;
  final Duration duration;
  final TextAlign? textAlign;

  const CountUpRupees({
    super.key,
    required this.value,
    required this.style,
    this.duration = const Duration(milliseconds: 900),
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) =>
          Text(Fmt.rupees(v), style: style, textAlign: textAlign),
    );
  }
}
