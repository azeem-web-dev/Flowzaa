import 'dart:async';

import 'package:flowzaa_shared/flowzaa_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../providers/providers.dart';
import '../util/latlng_ext.dart';
import '../widgets/sheet_card.dart';

/// Full-screen "drop a pin" location picker. The map moves under a fixed
/// centre pin; the address of the map centre is reverse-geocoded (debounced)
/// and shown in a top card. Confirming pops with a [ResolvedPlace].
class PickOnMapScreen extends ConsumerStatefulWidget {
  /// Where the map opens (usually the current field value or the user's GPS).
  final LatLngPoint initial;

  /// Screen title, e.g. "Choose pickup" / "Choose destination".
  final String title;

  const PickOnMapScreen({
    super.key,
    required this.initial,
    this.title = 'Choose location',
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
    _center = camera.center;
    if (!_resolving) setState(() => _resolving = true);
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 800),
      () => _resolve(camera.center),
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

  void _confirm() {
    final addr = _address.isEmpty ? 'Dropped pin' : _address;
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
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.flowzaa.customer',
                ),
              ],
            ),
          ),
          // Fixed centre pin (tip points at the map centre).
          const IgnorePointer(
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 44),
                child: Icon(Icons.location_on,
                    size: 44, color: AppColors.danger),
              ),
            ),
          ),
          // Top bar: back button + live address card.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    elevation: 2,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x140E1726),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.title, style: AppText.label),
                          const SizedBox(height: 4),
                          _resolving
                              ? const Text('Locating…',
                                  style: AppText.bodySoft)
                              : Text(
                                  _address,
                                  style: AppText.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Confirm sheet.
          Align(
            alignment: Alignment.bottomCenter,
            child: SheetCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.place_rounded,
                          color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _resolving ? 'Locating…' : _address,
                          style: AppText.bodySoft,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  PrimaryButton(
                    label: 'Confirm location',
                    icon: Icons.check_rounded,
                    onPressed: _resolving ? null : _confirm,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
