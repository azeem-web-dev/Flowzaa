import 'package:flowzaa_shared/flowzaa_shared.dart';
import 'package:flutter/material.dart';

/// The Flowzaa Captain mark — a gradient rounded square with a helmet icon.
/// Used on the splash and login screens.
class BrandLogo extends StatelessWidget {
  final double size;

  const BrandLogo({super.key, this.size = 64});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(
        Icons.sports_motorsports_rounded,
        color: Colors.white,
        size: size * 0.55,
      ),
    );
  }
}
