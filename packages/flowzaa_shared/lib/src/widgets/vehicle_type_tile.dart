import 'package:flutter/material.dart';

import '../models/vehicle_type.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../utils/formatters.dart';

/// A selectable ride-type row showing the emoji, name, capacity, ETA and fare.
class VehicleTypeTile extends StatelessWidget {
  final VehicleType type;
  final double fare;
  final int etaMinutes;
  final bool selected;
  final VoidCallback onTap;

  const VehicleTypeTile({
    super.key,
    required this.type,
    required this.fare,
    required this.etaMinutes,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.line,
            width: selected ? 1.8 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(type.emoji, style: const TextStyle(fontSize: 30)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(type.label, style: AppText.title),
                      if (type.capacity > 0) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.person, size: 14, color: AppColors.inkSoft),
                        Text('${type.capacity}', style: AppText.bodySoft),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text('$etaMinutes min away · ${type.description}',
                      style: AppText.bodySoft),
                ],
              ),
            ),
            Text(Fmt.rupees(fare), style: AppText.price),
          ],
        ),
      ),
    );
  }
}
