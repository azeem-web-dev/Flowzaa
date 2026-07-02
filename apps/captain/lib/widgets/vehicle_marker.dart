import 'dart:math' as math;

import 'package:flowzaa_shared/flowzaa_shared.dart';
import 'package:flutter/material.dart';

/// The captain's own map marker — a white disc with the vehicle icon in its
/// category color, rotated to the current heading.
class VehicleMarkerDisc extends StatelessWidget {
  final VehicleType type;
  final double headingDeg;
  final double size;

  const VehicleMarkerDisc({
    super.key,
    required this.type,
    this.headingDeg = 0,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: headingDeg * math.pi / 180,
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.fromBorderSide(
            BorderSide(color: AppColors.line, width: 1.5),
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Icon(type.icon, color: type.color, size: size * 0.6),
      ),
    );
  }
}
