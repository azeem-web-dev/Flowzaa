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

class _SearchingScreenState extends ConsumerState<SearchingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();
  bool _cancelling = false;
  bool _timedOut = false;
  bool _retrying = false;
  Timer? _timeoutTimer;

  /// Last snapshot of the ride, used to re-create it on Retry.
  Ride? _lastRide;

  @override
  void initState() {
    super.initState();
    _timeoutTimer = Timer(_searchTimeout, _onTimeout);
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _pulse.dispose();
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
        final timedOut = _timedOut ||
            (ride != null && ride.status == RideStatus.expired);

        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
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
                    _PulsingIcon(controller: _pulse),
                    const SizedBox(height: 28),
                    const Text('Finding you a captain…', style: AppText.h1),
                    const SizedBox(height: 8),
                    const Text(
                      'Hang tight, we are matching you with a nearby captain.',
                      style: AppText.bodySoft,
                      textAlign: TextAlign.center,
                    ),
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

class _PulsingIcon extends StatelessWidget {
  final AnimationController controller;
  const _PulsingIcon({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final t = controller.value;
        return SizedBox(
          width: 140,
          height: 140,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 60 + 80 * t,
                height: 60 + 80 * t,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withOpacity(0.18 * (1 - t)),
                ),
              ),
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                ),
                child: const Icon(Icons.electric_bike_rounded,
                    color: Colors.white, size: 38),
              ),
            ],
          ),
        );
      },
    );
  }
}
