import 'package:flowzaa_shared/flowzaa_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import 'tracking_screen.dart';

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

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final rideStream = ref.watch(rideServiceProvider);
    return StreamBuilder<Ride?>(
      stream: rideStream.watchRide(widget.rideId),
      builder: (context, snap) {
        final ride = snap.data;

        // Transition to tracking once a captain is assigned.
        if (ride != null &&
            (ride.status == RideStatus.accepted ||
                ride.status == RideStatus.arrived ||
                ride.status == RideStatus.ongoing)) {
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

        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  if (terminal) ...[
                    Icon(
                      ride.status == RideStatus.expired
                          ? Icons.search_off_rounded
                          : Icons.cancel_outlined,
                      size: 72,
                      color: AppColors.danger,
                    ),
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
                  if (terminal)
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
