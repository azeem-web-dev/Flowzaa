import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Fades + slides a child in on first build. Use `delay` to stagger lists:
/// FadeSlideIn(delay: Duration(milliseconds: 60 * index), child: tile).
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset beginOffset;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 380),
    this.beginOffset = const Offset(0, 0.10),
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration);
  late final Animation<double> _fade =
      CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
  late final Animation<Offset> _slide =
      Tween(begin: widget.beginOffset, end: Offset.zero)
          .animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _fade,
        child: SlideTransition(position: _slide, child: widget.child),
      );
}

/// Scales down slightly while pressed — makes cards/buttons feel tactile.
class ScaleTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;

  const ScaleTap({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.97,
  });

  @override
  State<ScaleTap> createState() => _ScaleTapState();
}

class _ScaleTapState extends State<ScaleTap> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? widget.pressedScale : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// A shimmering placeholder block for loading states (no dependencies).
class ShimmerBox extends StatefulWidget {
  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  const ShimmerBox({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius,
  });

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(10),
            gradient: LinearGradient(
              begin: Alignment(-1 + 2 * t, 0),
              end: Alignment(0 + 2 * t, 0),
              colors: const [
                Color(0xFFEDF1F5),
                Color(0xFFF8FAFC),
                Color(0xFFEDF1F5),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// An expanding "radar" pulse — used while searching for a captain.
class RadarPulse extends StatefulWidget {
  final double size;
  final Color color;
  final Widget? center;

  const RadarPulse({
    super.key,
    this.size = 220,
    this.color = AppColors.primary,
    this.center,
  });

  @override
  State<RadarPulse> createState() => _RadarPulseState();
}

class _RadarPulseState extends State<RadarPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              for (final phase in [0.0, 0.33, 0.66])
                _ring(((_c.value + phase) % 1.0)),
              Container(
                width: widget.size * 0.30,
                height: widget.size * 0.30,
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withOpacity(0.4),
                      blurRadius: 18,
                    ),
                  ],
                ),
                child: widget.center ??
                    const Icon(Icons.search_rounded,
                        color: Colors.white, size: 32),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _ring(double t) {
    return Container(
      width: widget.size * (0.3 + 0.7 * t),
      height: widget.size * (0.3 + 0.7 * t),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: widget.color.withOpacity((1 - t) * 0.5),
          width: 2,
        ),
      ),
    );
  }
}
