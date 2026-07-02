import 'package:flowzaa_shared/flowzaa_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';

class TripCompleteScreen extends ConsumerStatefulWidget {
  final Ride ride;
  const TripCompleteScreen({super.key, required this.ride});

  @override
  ConsumerState<TripCompleteScreen> createState() => _TripCompleteScreenState();
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
    final captain = ref.watch(captainProvider).valueOrNull;
    final upiId = captain?.upiId;
    final isUpi = ride.paymentMethod == PaymentMethod.upi;

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 8),
                children: [
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
                  const SizedBox(height: 6),
                  Text(
                    "${Fmt.rupees(ride.fare.total)} added to today's earnings",
                    style: AppText.label.copyWith(color: AppColors.success),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
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
                            isUpi
                                ? 'Collect ${Fmt.rupees(ride.fare.total)} — show '
                                    'your UPI QR to the rider. Flowzaa takes '
                                    '0% commission.'
                                : 'Collect ${Fmt.rupees(ride.fare.total)} in cash '
                                    'directly from the rider — Flowzaa takes '
                                    '0% commission.',
                            style:
                                AppText.bodySoft.copyWith(color: AppColors.ink),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (upiId != null && upiId.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: AppColors.primary.withOpacity(0.3)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.qr_code_2_rounded,
                                  color: AppColors.primary, size: 20),
                              const SizedBox(width: 8),
                              Text('YOUR UPI ID',
                                  style: AppText.label
                                      .copyWith(color: AppColors.primary)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            upiId,
                            style:
                                AppText.h2.copyWith(color: AppColors.primary),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'The rider pays this ID directly — no middleman.',
                            style: AppText.bodySoft,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
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
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: PrimaryButton(
                label: 'Done',
                loading: _busy,
                onPressed: _done,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
