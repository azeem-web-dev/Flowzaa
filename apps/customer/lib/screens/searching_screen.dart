import 'dart:async';

import 'package:flowzaa_shared/flowzaa_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import 'tracking_screen.dart';

/// How long we search before giving up and auto-cancelling.
const _searchTimeout = Duration(minutes: 3);

class SearchingScreen extends ConsumerStatefulWidget {
  final String rideId;
  const SearchingScreen({super.key, required this.rideId});

  @override
  ConsumerState<SearchingScreen> createState() => _SearchingScreenState();
}

class _SearchingScreenState extends ConsumerState<SearchingScreen> {
  bool _cancelling = false;
  bool _timedOut = false;
  bool _retrying = false;
  Timer? _timeoutTimer;
  Timer? _hintTimer;
  int _hintIndex = 0;

  static const _hints = [
    'Contacting nearby captains…',
    'Hang tight…',
    'Matching you with the best captain…',
  ];

  /// Last snapshot of the ride, used to re-create it on Retry.
  Ride? _lastRide;

  @override
  void initState() {
    super.initState();
    _timeoutTimer = Timer(_searchTimeout, _onTimeout);
    _hintTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      setState(() => _hintIndex = (_hintIndex + 1) % _hints.length);
    });
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _hintTimer?.cancel();
    super.dispose();
  }

  Future<void> _onTimeout() async {
    final ride = _lastRide;
    if (!mounted || (ride != null && ride.status != RideStatus.searching)) {
      return;
    }
    setState(() => _timedOut = true);
    try {
      await ref.read(rideServiceProvider).cancelRide(
            rideId: widget.rideId,
            by: 'customer',
            reason: 'No captain found — timeout',
          );
    } catch (_) {
      // Best effort — the stream keeps the UI honest either way.
    }
  }

  Future<void> _cancel() async {
    setState(() => _cancelling = true);
    try {
      await ref.read(rideServiceProvider).cancelRide(
            rideId: widget.rideId,
            by: 'customer',
            reason: 'Cancelled while searching',
          );
    } catch (_) {
      // ignore; the stream below will resolve the UI state anyway
    }
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  /// Re-creates the same ride and restarts the search.
  Future<void> _retry() async {
    final old = _lastRide;
    if (old == null) return;
    setState(() => _retrying = true);
    final fresh = Ride(
      id: '',
      customerId: old.customerId,
      customerName: old.customerName,
      customerPhone: old.customerPhone,
      status: RideStatus.searching,
      vehicleType: old.vehicleType,
      pickup: old.pickup,
      dropoff: old.dropoff,
      distanceMeters: old.distanceMeters,
      durationSeconds: old.durationSeconds,
      routePolyline: old.routePolyline,
      fare: old.fare,
      paymentMethod: old.paymentMethod,
      parcelInfo: old.parcelInfo,
    );
    try {
      final id = await ref.read(rideServiceProvider).createRide(fresh);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => SearchingScreen(rideId: id),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _retrying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not rebook: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final rideStream = ref.watch(rideServiceProvider);
    return StreamBuilder<Ride?>(
      stream: rideStream.watchRide(widget.rideId),
      builder: (context, snap) {
        final ride = snap.data;
        if (ride != null) _lastRide = ride;

        // Transition to tracking once a captain is assigned.
        if (ride != null &&
            (ride.status == RideStatus.accepted ||
                ride.status == RideStatus.arrived ||
                ride.status == RideStatus.ongoing)) {
          _timeoutTimer?.cancel();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            Navigator.of(context).pushReplacement(MaterialPageRoute(
              builder: (_) => TrackingScreen(rideId: widget.rideId),
            ));
          });
        }

        final terminal = ride != null &&
            (ride.status == RideStatus.cancelled ||
                ride.status == RideStatus.expired);
        final timedOut =
            _timedOut || (ride != null && ride.status == RideStatus.expired);

        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  if (timedOut) ...[
                    const Icon(Icons.search_off_rounded,
                        size: 72, color: AppColors.danger),
                    const SizedBox(height: 16),
                    const Text('No captains nearby', style: AppText.h1),
                    const SizedBox(height: 8),
                    const Text(
                      'We could not find a captain in time. Try again.',
                      style: AppText.bodySoft,
                      textAlign: TextAlign.center,
                    ),
                  ] else if (terminal) ...[
                    const Icon(Icons.cancel_outlined,
                        size: 72, color: AppColors.danger),
                    const SizedBox(height: 16),
                    Text(ride.status.customerLabel, style: AppText.h1),
                    const SizedBox(height: 8),
                    const Text(
                      'Please try booking again.',
                      style: AppText.bodySoft,
                      textAlign: TextAlign.center,
                    ),
                  ] else ...[
                    VehicleLoader(
                      type: ride?.vehicleType ?? VehicleType.bike,
                      width: 260,
                      vehicleSize: 46,
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Finding you a nearby '
                      '${(ride?.vehicleType ?? VehicleType.bike).label}…',
                      style: AppText.h1,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween(
                            begin: const Offset(0, 0.3),
                            end: Offset.zero,
                          ).animate(anim),
                          child: child,
                        ),
                      ),
                      child: Text(
                        _hints[_hintIndex],
                        key: ValueKey(_hintIndex),
                        style: AppText.bodySoft,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    if (ride != null) ...[
                      const SizedBox(height: 28),
                      _TripSummary(ride: ride),
                    ],
                  ],
                  const Spacer(),
                  if (timedOut) ...[
                    PrimaryButton(
                      label: 'Retry',
                      icon: Icons.refresh_rounded,
                      loading: _retrying,
                      onPressed: _retry,
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: () => Navigator.of(context)
                          .popUntil((route) => route.isFirst),
                      child: const Text('Back to home'),
                    ),
                  ] else if (terminal)
                    PrimaryButton(
                      label: 'Back to home',
                      onPressed: () => Navigator.of(context)
                          .popUntil((route) => route.isFirst),
                    )
                  else
                    OutlinedButton(
                      onPressed: _cancelling ? null : _cancel,
                      child: _cancelling
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2.2),
                            )
                          : const Text('Cancel search'),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A calm flat summary of the pending trip: route + fare.
class _TripSummary extends StatelessWidget {
  final Ride ride;
  const _TripSummary({required this.ride});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _line(Icons.trip_origin, AppColors.primary,
              ride.pickup.address ?? 'Pickup'),
          Container(
            margin: const EdgeInsets.only(left: 6),
            width: 2,
            height: 14,
            color: AppColors.line,
          ),
          _line(Icons.location_on_rounded, AppColors.danger,
              ride.dropoff.address ?? 'Destination'),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${ride.vehicleType.label} · ${ride.paymentMethod.label}',
                style: AppText.bodySoft,
              ),
              Text(Fmt.rupees(ride.fare.total), style: AppText.price),
            ],
          ),
        ],
      ),
    );
  }

  Widget _line(IconData icon, Color color, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: AppText.body,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
