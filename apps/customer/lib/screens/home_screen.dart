import 'package:flowzaa_shared/flowzaa_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../providers/providers.dart';
import '../util/latlng_ext.dart';
import '../widgets/sheet_card.dart';
import 'destination_search_screen.dart';
import 'tracking_screen.dart';

/// Default map center (Hyderabad) used when location permission is denied.
const _hyderabad = LatLng(17.44, 78.39);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final MapController _map = MapController();
  LatLng _center = _hyderabad;
  bool _hasLocation = false;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    try {
      final p = await ref.read(locationServiceProvider).currentPosition();
      if (!mounted) return;
      setState(() {
        _center = p.toLatLng();
        _hasLocation = true;
      });
      _map.move(_center, 15);
    } catch (_) {
      // Fall back to Hyderabad.
    }
  }

  void _openSearch() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DestinationSearchScreen(origin: _center.toPoint()),
    ));
  }

  @override
  Widget build(BuildContext context) {
    // If an active ride exists, take over the screen with tracking.
    final active = ref.watch(activeRideProvider).value;
    if (active != null) {
      return TrackingScreen(rideId: active.id);
    }

    final profile = ref.watch(userProfileProvider).value;

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 15,
              interactionOptions:
                  const InteractionOptions(flags: InteractiveFlag.all),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.flowzaa.customer',
              ),
              if (_hasLocation)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _center,
                      width: 24,
                      height: 24,
                      child: const _MyLocationDot(),
                    ),
                  ],
                ),
            ],
          ),
          // Top bar: menu + greeting.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _RoundIconButton(
                    icon: Icons.menu_rounded,
                    onTap: () => _showMenu(context),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
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
                      child: Row(
                        children: [
                          const Icon(Icons.person_rounded,
                              color: AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              profile == null
                                  ? 'Welcome'
                                  : 'Hi, ${profile.name}',
                              style: AppText.title,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Bottom "where to" card.
          Align(
            alignment: Alignment.bottomCenter,
            child: SheetCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Where are you going?', style: AppText.h2),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: _openSearch,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 16),
                      decoration: BoxDecoration(
                        color: AppColors.scaffold,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.search_rounded,
                              color: AppColors.inkSoft),
                          SizedBox(width: 10),
                          Text('Search destination',
                              style: AppText.bodySoft),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMenu(BuildContext context) {
    final auth = ref.read(authServiceProvider);
    final profile = ref.read(userProfileProvider).value;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            const SheetHandle(),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.primary,
                child: Icon(Icons.person, color: Colors.white),
              ),
              title: Text(profile?.name ?? 'Rider', style: AppText.title),
              subtitle: Text(
                profile == null ? '' : Fmt.phone(profile.phone),
                style: AppText.bodySoft,
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: AppColors.danger),
              title: const Text('Sign out'),
              onTap: () async {
                Navigator.of(ctx).pop();
                await auth.signOut();
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// A blue "my location" dot marker (replaces Google's myLocationEnabled).
class _MyLocationDot extends StatelessWidget {
  const _MyLocationDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: AppColors.ink),
        ),
      ),
    );
  }
}
