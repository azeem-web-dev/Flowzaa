import 'package:flowzaa_shared/flowzaa_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../providers/providers.dart';
import '../util/latlng_ext.dart';
import '../util/saved_place_flow.dart';
import '../widgets/map_attribution.dart';
import '../widgets/sheet_card.dart';
import '../widgets/tinted_circle_icon.dart';
import 'destination_search_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';
import 'ride_options_screen.dart';
import 'searching_screen.dart';
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
  bool _routing = false;

  /// Ride id we already auto-opened, so backing out of tracking doesn't
  /// immediately push it again (the banner stays available instead).
  String? _autoOpenedRideId;

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

  void _recenter() {
    if (_hasLocation) {
      _map.move(_center, 15);
    }
    _initLocation();
  }

  void _openSearch({VehicleType? type}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DestinationSearchScreen(
        origin: _center.toPoint(),
        preselectType: type,
      ),
    ));
  }

  void _openTracking(Ride ride) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ride.status == RideStatus.searching
          ? SearchingScreen(rideId: ride.id)
          : TrackingScreen(rideId: ride.id),
    ));
  }

  /// One-tap booking: current GPS as pickup, [drop] as destination.
  Future<void> _goTo(LatLngPoint drop) async {
    if (_routing) return;
    setState(() => _routing = true);
    try {
      final geo = ref.read(geoGatewayProvider);
      LatLngPoint pickup;
      try {
        pickup = await ref.read(locationServiceProvider).currentPosition();
      } catch (_) {
        pickup = _center.toPoint();
      }
      String address = 'Current location';
      try {
        final addr = await geo.reverseGeocode(pickup);
        if (addr.isNotEmpty) address = addr;
      } catch (_) {
        // Keep the placeholder address.
      }
      pickup = pickup.copyWith(address: address);
      final route = await geo.route(pickup, drop);
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => RideOptionsScreen(
          pickup: pickup,
          dropoff: drop,
          route: route,
        ),
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not compute route: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _routing = false);
    }
  }

  Future<void> _addSavedPlace() async {
    await addSavedPlaceFlow(context, ref, _center.toPoint());
  }

  /// Unique recent dropoff addresses from ride history (max 3).
  List<LatLngPoint> _recentDestinations(List<Ride> rides) {
    final seen = <String>{};
    final result = <LatLngPoint>[];
    for (final ride in rides) {
      final address = ride.dropoff.address;
      if (address == null || address.isEmpty) continue;
      if (!seen.add(address)) continue;
      result.add(ride.dropoff);
      if (result.length == 3) break;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(activeRideProvider).value;
    final profileAsync = ref.watch(userProfileProvider);
    final historyAsync = ref.watch(rideHistoryProvider);
    final profile = profileAsync.value;
    final rides = historyAsync.value ?? const <Ride>[];
    final sheetLoading = profileAsync.isLoading || historyAsync.isLoading;

    // Auto-open an active ride once (e.g. app relaunched mid-trip). After
    // that the banner below remains as the way back in.
    if (active != null && _autoOpenedRideId != active.id) {
      _autoOpenedRideId = active.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final route = ModalRoute.of(context);
        if (route != null && route.isCurrent) _openTracking(active);
      });
    }

    final firstName = _firstName(profile?.name);
    final recents = _recentDestinations(rides);
    final savedPlaces = profile?.savedPlaces ?? const <SavedPlace>[];

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
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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
              const OsmAttribution(),
            ],
          ),
          // Top bar: greeting + history + avatar.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.line),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0F000000),
                            blurRadius: 10,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        firstName == null
                            ? _greeting()
                            : '${_greeting()}, $firstName',
                        style: AppText.title,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _RoundIconButton(
                    icon: Icons.history_rounded,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const HistoryScreen()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _AvatarButton(
                    name: profile?.name,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ProfileScreen()),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Bottom: locate FAB + active ride banner + main sheet.
          Align(
            alignment: Alignment.bottomCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 16, bottom: 12),
                  child: FloatingActionButton.small(
                    heroTag: 'locate',
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                    onPressed: _recenter,
                    child: const Icon(Icons.my_location_rounded),
                  ),
                ),
                if (active != null)
                  _ActiveRideBanner(
                    ride: active,
                    onTap: () => _openTracking(active),
                  ),
                SheetCard(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.52,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Big "Where to?" search bar.
                          FadeSlideIn(
                            child: ScaleTap(
                              onTap: _openSearch,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 18),
                                decoration: BoxDecoration(
                                  color: AppColors.scaffold,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: AppColors.line, width: 1.2),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.search_rounded,
                                        color: AppColors.primary, size: 26),
                                    SizedBox(width: 12),
                                    Text('Where to?', style: AppText.h2),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          // Ride-type shortcut chips.
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                for (final (i, t) in VehicleType.values.indexed)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 10),
                                    child: FadeSlideIn(
                                      delay:
                                          Duration(milliseconds: 60 + 50 * i),
                                      beginOffset: const Offset(0.10, 0),
                                      child: _RideTypeChip(
                                        type: t,
                                        onTap: () => _openSearch(type: t),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          if (sheetLoading)
                            const FadeSlideIn(
                              delay: Duration(milliseconds: 120),
                              child: _SheetShimmer(),
                            )
                          else ...[
                            // Saved places chips + Add.
                            FadeSlideIn(
                              delay: const Duration(milliseconds: 160),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    ...savedPlaces.map(
                                      (p) => Padding(
                                        padding:
                                            const EdgeInsets.only(right: 8),
                                        child: ActionChip(
                                          avatar: TintedCircleIcon(
                                            icon: savedPlaceIcon(p.label),
                                            color: AppColors.primary,
                                            size: 22,
                                          ),
                                          label: Text(p.label,
                                              style: AppText.label.copyWith(
                                                  color: AppColors.ink)),
                                          backgroundColor: Colors.white,
                                          side: const BorderSide(
                                              color: AppColors.line),
                                          onPressed: () => _goTo(LatLngPoint(
                                            lat: p.lat,
                                            lng: p.lng,
                                            address: p.address,
                                          )),
                                        ),
                                      ),
                                    ),
                                    ActionChip(
                                      avatar: const Icon(Icons.add_rounded,
                                          size: 18, color: AppColors.primary),
                                      label: Text('Add',
                                          style: AppText.label.copyWith(
                                              color: AppColors.primary)),
                                      backgroundColor: Colors.white,
                                      side: const BorderSide(
                                          color: AppColors.line),
                                      onPressed: _addSavedPlace,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Recent destinations.
                            if (recents.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              const Divider(height: 1),
                              for (final (i, d) in recents.indexed)
                                FadeSlideIn(
                                  delay: Duration(milliseconds: 220 + 50 * i),
                                  child: ScaleTap(
                                    onTap: () => _goTo(d),
                                    child: ListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      leading: const TintedCircleIcon(
                                        icon: Icons.history_rounded,
                                        color: AppColors.inkSoft,
                                        size: 32,
                                      ),
                                      title: Text(
                                        d.address ?? '',
                                        style: AppText.body,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_routing) ...[
            const Opacity(
              opacity: 0.35,
              child: ModalBarrier(dismissible: false, color: Colors.black),
            ),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.line),
                ),
                child: const VehicleLoaderSmall(
                  type: VehicleType.bike,
                  label: 'Getting your route…',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String? _firstName(String? name) {
    final n = (name ?? '').trim();
    if (n.isEmpty) return null;
    return n.split(RegExp(r'\s+')).first;
  }

  /// Time-of-day greeting shown in the top bar.
  static String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

/// Banner shown above the sheet when a ride is in progress.
class _ActiveRideBanner extends StatelessWidget {
  final Ride ride;
  final VoidCallback onTap;
  const _ActiveRideBanner({required this.ride, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Material(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                VehicleIcon(type: ride.vehicleType, size: 36, selected: true),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ride in progress — tap to view',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ride.status.customerLabel,
                        style: AppText.label.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Premium-icon chip for the ride-type shortcuts row.
class _RideTypeChip extends StatelessWidget {
  final VehicleType type;
  final VoidCallback onTap;
  const _RideTypeChip({required this.type, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ScaleTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            VehicleIcon(type: type, size: 34),
            const SizedBox(width: 8),
            Text(type.label, style: AppText.title),
          ],
        ),
      ),
    );
  }
}

/// Skeleton rows shown in the bottom sheet while profile/history load.
class _SheetShimmer extends StatelessWidget {
  const _SheetShimmer();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < 3; i++) ...[
              ShimmerBox(
                width: 88,
                height: 32,
                borderRadius: BorderRadius.circular(16),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < 2; i++) ...[
          Row(
            children: [
              ShimmerBox(
                width: 32,
                height: 32,
                borderRadius: BorderRadius.circular(16),
              ),
              const SizedBox(width: 12),
              const Expanded(child: ShimmerBox(height: 14)),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ],
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

/// Circular avatar button showing the user's initial; opens the profile.
class _AvatarButton extends StatelessWidget {
  final String? name;
  final VoidCallback onTap;
  const _AvatarButton({required this.name, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final n = (name ?? '').trim();
    final initial = n.isEmpty ? 'R' : n[0].toUpperCase();
    return Material(
      color: AppColors.primary,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
