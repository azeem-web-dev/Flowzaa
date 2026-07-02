import 'dart:async';

import 'package:flowzaa_shared/flowzaa_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../providers/providers.dart';
import '../util/earnings.dart';
import '../util/latlng_ext.dart';
import '../widgets/count_up_rupees.dart';
import '../widgets/map_attribution.dart';
import '../widgets/vehicle_marker.dart';
import 'active_ride_screen.dart';
import 'earnings_screen.dart';
import 'profile_screen.dart';

/// Max distance (km) from the captain within which we surface a request.
const double _kRequestRadiusKm = 6.0;

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final MapController _mapController = MapController();
  StreamSubscription<LatLngPoint>? _positionSub;
  StreamSubscription<List<Ride>>? _requestsSub;

  LatLngPoint? _myLocation;
  List<Ride> _incoming = const [];
  bool _busy = false; // toggling online / accepting
  final Set<String> _dismissed = {};

  @override
  void dispose() {
    _positionSub?.cancel();
    _requestsSub?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  // ---- Online / offline ---------------------------------------------------

  Future<void> _setOnline(bool online, Captain captain) async {
    final uid = captain.uid;
    final captains = ref.read(captainServiceProvider);
    setState(() => _busy = true);
    try {
      if (online) {
        await ref.read(locationServiceProvider).ensurePermission();
        await captains.setOnline(uid, true);
        _startLocationStream(uid);
        _startRequestStream(captain.vehicleType);
      } else {
        await captains.setOnline(uid, false);
        await _positionSub?.cancel();
        await _requestsSub?.cancel();
        _positionSub = null;
        _requestsSub = null;
        if (mounted) setState(() => _incoming = const []);
      }
    } catch (e) {
      if (mounted) _snack('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _startLocationStream(String uid) {
    _positionSub?.cancel();
    final captains = ref.read(captainServiceProvider);
    final rides = ref.read(rideServiceProvider);
    _positionSub = ref
        .read(locationServiceProvider)
        .positionStream(distanceFilter: 20)
        .listen((p) {
      _myLocation = p;
      captains.updateLocation(uid, p);
      // Mirror onto an active ride so the rider sees us moving.
      final active = ref.read(activeRideProvider).valueOrNull;
      if (active != null) {
        rides.updateCaptainLocation(active.id, p);
      }
      _mapController.move(p.toLatLng, _mapController.camera.zoom);
      if (mounted) setState(() {});
    });
  }

  void _startRequestStream(VehicleType type) {
    _requestsSub?.cancel();
    _requestsSub =
        ref.read(rideServiceProvider).watchSearchingRides(type).listen((rides) {
      final me = _myLocation;
      final filtered = rides.where((r) {
        if (_dismissed.contains(r.id)) return false;
        if (me == null) return true;
        return Geo.distanceKm(me, r.pickup) <= _kRequestRadiusKm;
      }).toList();
      if (mounted) setState(() => _incoming = filtered);
    });
  }

  // ---- Accept -------------------------------------------------------------

  Future<void> _accept(Ride ride, Captain captain) async {
    setState(() => _busy = true);
    try {
      final ok = await ref.read(rideServiceProvider).acceptRide(
        rideId: ride.id,
        captainId: captain.uid,
        captainName: captain.name,
        captainPhone: captain.phone,
        captainVehicle: {
          'type': captain.vehicleType.id,
          'number': captain.vehicleNumber,
          'model': captain.vehicleModel,
        },
      );
      if (!mounted) return;
      if (!ok) {
        _snack('Ride already taken');
        setState(() => _incoming =
            _incoming.where((r) => r.id != ride.id).toList());
      } else {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ActiveRideScreen()),
        );
      }
    } catch (e) {
      if (mounted) _snack('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final captainAsync = ref.watch(captainProvider);

    // If an active ride appears, jump to the active ride screen.
    ref.listen(activeRideProvider, (prev, next) {
      final ride = next.valueOrNull;
      if (ride != null && ModalRoute.of(context)?.isCurrent == true) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ActiveRideScreen()),
        );
      }
    });

    return captainAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (captain) {
        if (captain == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return _buildHome(captain);
      },
    );
  }

  Widget _buildHome(Captain captain) {
    final online = captain.isOnline;
    final myLatLng = _myLocation?.toLatLng ??
        (captain.location != null
            ? captain.location!.toLatLng
            : const LatLng(12.9716, 77.5946)); // Bengaluru fallback

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      body: SafeArea(
        child: Column(
          children: [
            _header(captain),
            _earningsCard(),
            _onlineToggle(captain),
            Expanded(
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: myLatLng,
                      initialZoom: 15,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.flowzaa.captain',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: myLatLng,
                            width: 48,
                            height: 48,
                            child: VehicleMarkerDisc(
                              type: captain.vehicleType,
                              headingDeg: _myLocation?.heading ?? 0,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const MapAttribution(),
                  if (online && _incoming.isNotEmpty)
                    _requestsSheet(captain),
                  if (online && _incoming.isEmpty)
                    _waitingBanner(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(Captain captain) {
    return FadeSlideIn(
      child: ScaleTap(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ProfileScreen()),
        ),
        child: Container(
          margin: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.primary,
                child: Text(
                  captain.name.isNotEmpty
                      ? captain.name[0].toUpperCase()
                      : 'C',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(captain.name, style: AppText.title),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        RatingStars(value: captain.rating, size: 16),
                        const SizedBox(width: 8),
                        Text('${captain.totalRides} trips',
                            style: AppText.bodySoft),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  VehicleIcon(type: captain.vehicleType, size: 36),
                  const SizedBox(height: 3),
                  Text(captain.vehicleType.label, style: AppText.label),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _earningsCard() {
    final historyAsync = ref.watch(rideHistoryProvider);
    if (historyAsync.isLoading && !historyAsync.hasValue) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        child: ShimmerBox(
          height: 92,
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
      );
    }
    final rides = historyAsync.valueOrNull ?? const <Ride>[];
    final s = EarningsSummary.fromRides(rides);
    return FadeSlideIn(
      delay: const Duration(milliseconds: 60),
      child: ScaleTap(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const EarningsScreen()),
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.28),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.account_balance_wallet_rounded,
                    color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        CountUpRupees(
                          value: s.today,
                          style: AppText.h1.copyWith(color: Colors.white),
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(
                            'today · ${s.todayTrips} '
                            'trip${s.todayTrips == 1 ? '' : 's'}',
                            style: AppText.label
                                .copyWith(color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'This week ${Fmt.rupees(s.week)} · '
                      "0% commission — it's all yours.",
                      style: AppText.label.copyWith(color: Colors.white),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  Widget _onlineToggle(Captain captain) {
    final online = captain.isOnline;
    return FadeSlideIn(
      delay: const Duration(milliseconds: 120),
      child: ScaleTap(
        onTap: _busy ? null : () => _setOnline(!online, captain),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: online ? AppColors.onlineGreen : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: online ? AppColors.onlineGreen : AppColors.line,
            ),
            boxShadow: online
                ? [
                    BoxShadow(
                      color: AppColors.onlineGreen.withOpacity(0.45),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: Icon(
                  online
                      ? Icons.bolt_rounded
                      : Icons.power_settings_new_rounded,
                  key: ValueKey(online),
                  color: online ? Colors.white : AppColors.offlineGrey,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      online ? "You're Online" : "You're Offline",
                      style: AppText.title.copyWith(
                        color: online ? Colors.white : AppColors.ink,
                      ),
                    ),
                    Text(
                      online
                          ? 'Finding rides for you…'
                          : 'Go online to start earning',
                      style: AppText.bodySoft.copyWith(
                        color: online ? Colors.white70 : AppColors.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: online,
                activeColor: Colors.white,
                activeTrackColor: Colors.white24,
                onChanged: _busy ? null : (v) => _setOnline(v, captain),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _waitingBanner() {
    return Positioned(
      left: 20,
      right: 20,
      bottom: 20,
      child: FadeSlideIn(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.line),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadarPulse(
                size: 120,
                color: AppColors.onlineGreen,
                center: Icon(Icons.sports_motorsports_rounded,
                    color: Colors.white, size: 24),
              ),
              SizedBox(height: 12),
              Text('Waiting for requests…', style: AppText.title),
              SizedBox(height: 2),
              Text("You'll be alerted when a ride comes in",
                  style: AppText.bodySoft),
            ],
          ),
        ),
      ),
    );
  }

  Widget _requestsSheet(Captain captain) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 380),
        margin: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: ListView.separated(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          itemCount: _incoming.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => FadeSlideIn(
            key: ValueKey(_incoming[i].id),
            delay: Duration(milliseconds: 50 * i),
            child: _requestCard(_incoming[i], captain),
          ),
        ),
      ),
    );
  }

  Widget _requestCard(Ride ride, Captain captain) {
    final me = _myLocation ?? captain.location;
    final awayKm = me == null ? null : Geo.distanceKm(me, ride.pickup);
    final isParcel =
        ride.vehicleType == VehicleType.parcel && ride.parcelInfo != null;

    return ScaleTap(
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.line),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Accent bar in the vehicle color.
                Container(width: 4, color: ride.vehicleType.color),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            VehicleIcon(type: ride.vehicleType, size: 40),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('New request',
                                    style: AppText.label),
                                Text(ride.vehicleType.label,
                                    style: AppText.title),
                              ],
                            ),
                            if (isParcel) ...[
                              const SizedBox(width: 8),
                              _parcelBadge(),
                            ],
                            const Spacer(),
                            Text(Fmt.rupees(ride.fare.total),
                                style: AppText.price),
                          ],
                        ),
                        if (awayKm != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.near_me_rounded,
                                  size: 16, color: AppColors.primary),
                              const SizedBox(width: 6),
                              Text(
                                '${awayKm.toStringAsFixed(1)} km away',
                                style: AppText.label
                                    .copyWith(color: AppColors.primary),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),
                        _locRow(Icons.trip_origin, AppColors.primary,
                            ride.pickup.address ?? 'Pickup point'),
                        const Padding(
                          padding: EdgeInsets.only(left: 9),
                          child: SizedBox(
                            height: 16,
                            child: VerticalDivider(
                                width: 2, color: AppColors.line),
                          ),
                        ),
                        _locRow(Icons.location_on, AppColors.danger,
                            ride.dropoff.address ?? 'Drop point'),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _pill(Icons.route,
                                Fmt.distance(ride.distanceMeters)),
                            const SizedBox(width: 8),
                            _pill(Icons.schedule,
                                Fmt.duration(ride.durationSeconds)),
                            const SizedBox(width: 8),
                            _pill(
                              ride.paymentMethod == PaymentMethod.upi
                                  ? Icons.qr_code_2_rounded
                                  : Icons.payments_outlined,
                              ride.paymentMethod.label,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => setState(() {
                                          _dismissed.add(ride.id);
                                          _incoming = _incoming
                                              .where((r) => r.id != ride.id)
                                              .toList();
                                        }),
                                child: const Text('Dismiss'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: PrimaryButton(
                                label: 'Accept',
                                icon: Icons.check_rounded,
                                loading: _busy,
                                onPressed: () => _accept(ride, captain),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _parcelBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.parcel.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inventory_2_rounded,
              size: 13, color: AppColors.parcel),
          const SizedBox(width: 4),
          Text(
            'Parcel',
            style: AppText.label.copyWith(color: AppColors.parcel),
          ),
        ],
      ),
    );
  }

  Widget _locRow(IconData icon, Color color, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.body),
        ),
      ],
    );
  }

  Widget _pill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.scaffold,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.inkSoft),
          const SizedBox(width: 6),
          Text(label, style: AppText.label),
        ],
      ),
    );
  }
}
