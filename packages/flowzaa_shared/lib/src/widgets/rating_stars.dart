import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Read-only or interactive star rating.
class RatingStars extends StatelessWidget {
  final double value;
  final double size;
  final ValueChanged<int>? onRate; // null = read-only

  const RatingStars({
    super.key,
    required this.value,
    this.size = 20,
    this.onRate,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < value.round();
        final star = Icon(
          filled ? Icons.star_rounded : Icons.star_border_rounded,
          size: size,
          color: AppColors.accent,
        );
        if (onRate == null) return star;
        return GestureDetector(
          onTap: () => onRate!(i + 1),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Icon(
              filled ? Icons.star_rounded : Icons.star_border_rounded,
              size: size,
              color: AppColors.accent,
            ),
          ),
        );
      }),
    );
  }
}
