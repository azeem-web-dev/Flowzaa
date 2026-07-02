import 'package:flowzaa_shared/flowzaa_shared.dart';
import 'package:flutter/material.dart';

/// The Flowzaa Captain mark — a flat solid teal rounded square with a white
/// helmet icon. No gradient, no glow.
class BrandLogo extends StatelessWidget {
  final double size;

  const BrandLogo({super.key, this.size = 64});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(
        Icons.sports_motorsports_rounded,
        color: Colors.white,
        size: size * 0.55,
      ),
    );
  }
}
