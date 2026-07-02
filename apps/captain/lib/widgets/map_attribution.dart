import 'package:flowzaa_shared/flowzaa_shared.dart';
import 'package:flutter/material.dart';

/// Tiny OpenStreetMap attribution shown over map views. Place inside a
/// `Stack` on top of a `FlutterMap`.
class MapAttribution extends StatelessWidget {
  const MapAttribution({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 6,
      bottom: 4,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.7),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '© OpenStreetMap',
            style: AppText.label.copyWith(
              fontSize: 10,
              color: AppColors.inkSoft,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
