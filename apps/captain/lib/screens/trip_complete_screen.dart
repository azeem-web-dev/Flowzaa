import 'package:flowzaa_shared/flowzaa_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';

class TripCompleteScreen extends ConsumerStatefulWidget {
  final Ride ride;
  const TripCompleteScreen({super.key, required this.ride});

  @override
  ConsumerState<TripCompleteScreen> createState() =>
      _TripCompleteScreenState();
}

class _TripCompleteScreenState extends ConsumerState<TripCompleteScreen> {
  int _stars = 0;
  bool _busy = false;

  Future<void> _done() async {
    setState(() => _busy = true);
    try {
      if (_stars > 0) {
        await ref
            .read(rideServiceProvider)
            .rateByCaptain(widget.ride.id, _stars, null);
      }
    } catch (_) {
      // Non-fatal — still let the captain return home.
    }
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final ride = widget.ride;
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Center(
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: AppColors.success,
                  child: Icon(Icons.check_rounded,
                      color: Colors.white, size: 44),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Trip complete',
                  style: AppText.h1, textAlign: TextAlign.center),
              const SizedBox(height: 6),
              const Text('You earned',
                  style: AppText.bodySoft, textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(
                Fmt.rupees(ride.fare.total),
                style: AppText.display.copyWith(fontSize: 40),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.savings_outlined,
                        color: AppColors.accent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Collect ${Fmt.rupees(ride.fare.total)} directly from '
                        'the rider by ${ride.paymentMethod.label} — '
                        'Flowzaa takes 0% commission.',
                        style: AppText.bodySoft.copyWith(color: AppColors.ink),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              const Text('Rate your rider',
                  style: AppText.title, textAlign: TextAlign.center),
              const SizedBox(height: 10),
              Center(
                child: RatingStars(
                  value: _stars.toDouble(),
                  size: 40,
                  onRate: (v) => setState(() => _stars = v),
                ),
              ),
              const Spacer(),
              PrimaryButton(
                label: 'Done',
                loading: _busy,
                onPressed: _done,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
