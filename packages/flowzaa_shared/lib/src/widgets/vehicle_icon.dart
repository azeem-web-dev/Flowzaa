import 'package:flutter/material.dart';

import '../models/vehicle_type.dart';
import '../theme/app_colors.dart';

/// Premium icon treatment for ride categories — replaces emoji everywhere.
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

/// A soft gradient badge with the vehicle icon — the standard way to render a
/// ride category across both apps.
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
    final c = type.color;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: selected
              ? [c, c.withOpacity(0.75)]
              : [c.withOpacity(0.16), c.withOpacity(0.08)],
        ),
        borderRadius: BorderRadius.circular(size * 0.32),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: c.withOpacity(0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: Icon(
        type.icon,
        size: size * 0.55,
        color: selected ? Colors.white : c,
      ),
    );
  }
}
