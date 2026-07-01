import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// A small labelled stat pill (e.g. distance / time / fare) used on ride cards.
class InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  const InfoPill({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return Column(
      children: [
        Icon(icon, size: 20, color: c),
        const SizedBox(height: 4),
        Text(value, style: AppText.title),
        Text(label, style: AppText.label),
      ],
    );
  }
}
