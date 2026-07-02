import 'package:flutter/material.dart';

/// A small icon inside a softly tinted circle — the standard leading visual
/// for list tiles and chips (saved places, search results, profile rows).
class TintedCircleIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const TintedCircleIcon({
    super.key,
    required this.icon,
    required this.color,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: size * 0.52),
    );
  }
}
