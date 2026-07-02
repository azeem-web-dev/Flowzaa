import 'package:flutter/material.dart';

import '../models/vehicle_type.dart';
import '../theme/app_colors.dart';

/// Flat, professional icon treatment for ride categories — no gradients, no
/// glow. Unselected: neutral surface + ink icon. Selected: solid teal + white.
extension VehicleTypeVisuals on VehicleType {
  IconData get icon {
    switch (this) {
      case VehicleType.bike:
        return Icons.two_wheeler_rounded;
      case VehicleType.auto:
        return Icons.electric_rickshaw_rounded;
      case VehicleType.car:
        return Icons.directions_car_rounded;
      case VehicleType.parcel:
        return Icons.inventory_2_rounded;
    }
  }

  Color get color {
    switch (this) {
      case VehicleType.bike:
        return AppColors.bike;
      case VehicleType.auto:
        return AppColors.auto;
      case VehicleType.car:
        return AppColors.car;
      case VehicleType.parcel:
        return AppColors.parcel;
    }
  }
}

/// A flat square badge with the vehicle icon. Selected = solid brand fill.
class VehicleIcon extends StatelessWidget {
  final VehicleType type;
  final double size;
  final bool selected;

  const VehicleIcon({
    super.key,
    required this.type,
    this.size = 48,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : AppColors.iconSurface,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(
        type.icon,
        size: size * 0.52,
        color: selected ? Colors.white : AppColors.ink,
      ),
    );
  }
}
