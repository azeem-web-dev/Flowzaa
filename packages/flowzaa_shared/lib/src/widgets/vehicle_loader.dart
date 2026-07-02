import 'package:flutter/material.dart';

import '../models/vehicle_type.dart';
import '../theme/app_colors.dart';
import 'vehicle_icon.dart';

/// The signature Flowzaa loading animation: the chosen vehicle glides left→right
/// along a dashed road, wheels/road-dashes scrolling, and loops. Flat and
/// professional — no gradients or glow. Use it as the primary "searching" and
/// app-wide loading motif.
class VehicleLoader extends StatefulWidget {
  final VehicleType type;
  final double width;
  final double vehicleSize;
  final Color? roadColor;

  const VehicleLoader({
    super.key,
    this.type = VehicleType.bike,
    this.width = 240,
    this.vehicleSize = 40,
    this.roadColor,
  });

  @override
  State<VehicleLoader> createState() => _VehicleLoaderState();
}

class _VehicleLoaderState extends State<VehicleLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final road = widget.roadColor ?? AppColors.line;
    final v = widget.vehicleSize;
    final trackHeight = v + 26;
    return SizedBox(
      width: widget.width,
      height: trackHeight,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value; // 0..1
          // Vehicle travels across, easing in/out, then loops.
          final travel = (widget.width - v);
          final x = Curves.easeInOut.transform(t) * travel;
          // Subtle bob so it feels alive without a "growing" effect.
          final bob = 1.5 * -( (t * 2 % 1) - 0.5).abs();
          return Stack(
            clipBehavior: Clip.none,
            children: [
              // The road: a scrolling dashed line.
              Positioned(
                left: 0,
                right: 0,
                bottom: 4,
                child: CustomPaint(
                  size: Size(widget.width, 3),
                  painter: _DashPainter(phase: t, color: road),
                ),
              ),
              // The vehicle, flat icon in its category color.
              Positioned(
                left: x,
                bottom: 8 + bob,
                child: Icon(
                  widget.type.icon,
                  size: v,
                  color: widget.type.color,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  final double phase;
  final Color color;
  _DashPainter({required this.phase, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    const dash = 14.0;
    const gap = 12.0;
    final period = dash + gap;
    // Scroll the dashes leftwards to sell forward motion.
    var start = -period + (phase * period);
    while (start < size.width) {
      final x1 = start.clamp(0.0, size.width);
      final x2 = (start + dash).clamp(0.0, size.width);
      if (x2 > x1) {
        canvas.drawLine(Offset(x1, 0), Offset(x2, 0), paint);
      }
      start += period;
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.phase != phase;
}

/// Compact inline loader for smaller loading states (route calc, fares, etc.).
class VehicleLoaderSmall extends StatelessWidget {
  final VehicleType type;
  final String? label;
  const VehicleLoaderSmall({super.key, this.type = VehicleType.bike, this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        VehicleLoader(type: type, width: 160, vehicleSize: 30),
        if (label != null) ...[
          const SizedBox(height: 6),
          Text(label!,
              style: const TextStyle(color: AppColors.inkSoft, fontSize: 13)),
        ],
      ],
    );
  }
}
