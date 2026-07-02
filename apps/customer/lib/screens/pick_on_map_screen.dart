import 'dart:async';

import 'package:flowzaa_shared/flowzaa_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../providers/providers.dart';
import '../util/latlng_ext.dart';
import '../widgets/map_attribution.dart';

/// Full-screen "drop a pin" location picker. The map moves under a fixed
/// centre pin; the address of the map centre is reverse-geocoded (debounced)
/// and shown in the bottom card. Confirming pops with a [ResolvedPlace].
///
/// IMPORTANT: the returned point is always the *raw map centre* — the
/// reverse-geocoded address is display text only and never shifts the
/// coordinates (captains navigate to these exact lat/lng values).
class PickOnMapScreen extends ConsumerStatefulWidget {
  /// Where the map opens (usually the current field value or the user's GPS).
  final LatLngPoint initial;

  /// Card title, e.g. "Set pickup" / "Set destination".
  final String title;

  const PickOnMapScreen({
    super.key,
    required this.initial,
    this.title = 'Set location',
  });

  @override
  ConsumerState<PickOnMapScreen> createState() => _PickOnMapScreenState();
}

class _PickOnMapScreenState extends ConsumerState<PickOnMapScreen> {
  final MapController _map = MapController();
  Timer? _debounce;
  late LatLng _center = widget.initial.toLatLng();
  String _address = '';
  bool _resolving = true;
  bool _moving = false;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _resolve(_center);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    // Keep the RAW camera centre — this is the point we return on confirm.
    _center = camera.center;
    setState(() {
      _resolving = true;
      _moving = true;
    });
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 700),
      () {
        if (mounted) setState(() => _moving = false);
        _resolve(_center);
      },
    );
  }

  Future<void> _resolve(LatLng at) async {
    try {
      final addr = await ref.read(geoGatewayProvider).reverseGeocode(
            at.toPoint(),
          );
      if (!mounted) return;
      setState(() {
        _address = addr.isEmpty ? 'Dropped pin' : addr;
        _resolving = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _address = 'Dropped pin';
        _resolving = false;
      });
    }
  }

  /// Recenters the map on the user's GPS location.
  Future<void> _recenter() async {
    setState(() => _locating = true);
    try {
      final p = await ref.read(locationServiceProvider).currentPosition();
      if (!mounted) return;
      _map.move(p.toLatLng(), 16);
    } catch (_) {
      // GPS unavailable — keep the current view.
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _confirm() {
    final addr = _address.isEmpty ? 'Dropped pin' : _address;
    // Return the exact map-centre coordinates, untouched by geocoding.
    Navigator.of(context).pop(ResolvedPlace(
      point: _center.toPoint().copyWith(address: addr),
      address: addr,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: _center,
                initialZoom: 16,
                onPositionChanged: _onPositionChanged,
                interactionOptions:
                    const InteractionOptions(flags: InteractiveFlag.all),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.flowzaa.customer',
                ),
                const OsmAttribution(),
              ],
            ),
          ),
          // Fixed centre pin — the tip marks the exact map centre.
          IgnorePointer(
            child: Center(
              child: Transform.translate(
                offset: const Offset(0, -31),
                child: SizedBox(
                  width: 48,
                  height: 62,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      // Elliptical shadow anchor at the exact centre point.
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: _moving ? 14 : 10,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.30),
                          borderRadius: BorderRadius.all(
                            Radius.elliptical(_moving ? 7 : 5, 2),
                          ),
                        ),
                      ),
                      // The pin, bouncing up slightly while the map moves.
                      AnimatedSlide(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        offset: _moving ? const Offset(0, -0.10) : Offset.zero,
                        child: const Icon(
                          Icons.location_pin,
                          size: 48,
                          color: AppColors.primary,
                          shadows: [
                            Shadow(
                              color: Color(0x33000000),
                              blurRadius: 8,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Back button, top-left.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _CircleButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
          ),
          // My-location button + confirm card, bottom.
          Align(
            alignment: Alignment.bottomCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 16, bottom: 12),
                  child: _CircleButton(
                    icon: _locating
                        ? Icons.more_horiz_rounded
                        : Icons.my_location_rounded,
                    color: AppColors.primary,
                    onTap: _locating ? null : _recenter,
                  ),
                ),
                _ConfirmCard(
                  title: widget.title,
                  address: _address,
                  resolving: _resolving,
                  center: _center,
                  onConfirm: _resolving ? null : _confirm,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The single bottom card: title, address, exact coordinates, confirm CTA.
class _ConfirmCard extends StatelessWidget {
  final String title;
  final String address;
  final bool resolving;
  final LatLng center;
  final VoidCallback? onConfirm;

  const _ConfirmCard({
    required this.title,
    required this.address,
    required this.resolving,
    required this.center,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppColors.line)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 12,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppText.h2),
            const SizedBox(height: 10),
            if (resolving)
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(width: double.infinity, height: 14),
                  SizedBox(height: 8),
                  ShimmerBox(width: 180, height: 14),
                ],
              )
            else
              Text(
                address,
                style: AppText.body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 6),
            Text(
              '${center.latitude.toStringAsFixed(5)}, '
              '${center.longitude.toStringAsFixed(5)}',
              style: AppText.label.copyWith(fontSize: 12),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Confirm location',
              icon: Icons.check_rounded,
              onPressed: onConfirm,
            ),
          ],
        ),
      ),
    );
  }
}

/// A white circular icon button with a soft shadow.
class _CircleButton extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final VoidCallback? onTap;

  const _CircleButton({required this.icon, this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ScaleTap(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.line),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: color ?? AppColors.ink, size: 22),
      ),
    );
  }
}
