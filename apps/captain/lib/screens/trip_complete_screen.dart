import 'package:flowzaa_shared/flowzaa_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../widgets/count_up_rupees.dart';

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

  Future<void> _copyUpi(String upiId) async {
    await Clipboard.setData(ClipboardData(text: upiId));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('UPI ID copied')),
    );
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
                padding: const EdgeInsets.fromLTRB(20, 32, 20, 8),
                children: [
                  const Center(
                    child: FadeSlideIn(
                      child: SizedBox(
                        height: 84,
                        width: 84,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.check_rounded,
                              color: Colors.white, size: 46),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const FadeSlideIn(
                    delay: Duration(milliseconds: 120),
                    child: Text('Trip complete',
                        style: AppText.h1, textAlign: TextAlign.center),
                  ),
                  const SizedBox(height: 6),
                  const FadeSlideIn(
                    delay: Duration(milliseconds: 180),
                    child: Text('You earned',
                        style: AppText.bodySoft, textAlign: TextAlign.center),
                  ),
                  const SizedBox(height: 4),
                  CountUpRupees(
                    value: ride.fare.total,
                    style: AppText.display.copyWith(fontSize: 40),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 240),
                    child: Text(
                      "${Fmt.rupees(ride.fare.total)} added to today's earnings",
                      style: AppText.label.copyWith(color: AppColors.success),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 300),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.savings_rounded,
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
                              style: AppText.bodySoft
                                  .copyWith(color: AppColors.ink),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (upiId != null && upiId.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 360),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.line),
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    upiId,
                                    style: AppText.h2.copyWith(
                                      color: AppColors.primary,
                                      fontFamily: 'monospace',
                                      letterSpacing: 0.5,
                                    ),
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  tooltip: 'Copy UPI ID',
                                  onPressed: () => _copyUpi(upiId),
                                  icon: const Icon(Icons.copy_rounded,
                                      size: 18, color: AppColors.primary),
                                ),
                              ],
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
                    ),
                  ],
                  const SizedBox(height: 24),
                  const FadeSlideIn(
                    delay: Duration(milliseconds: 420),
                    child: Text('Rate your rider',
                        style: AppText.title, textAlign: TextAlign.center),
                  ),
                  const SizedBox(height: 10),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 480),
                    child: Center(
                      child: RatingStars(
                        value: _stars.toDouble(),
                        size: 40,
                        onRate: (v) => setState(() => _stars = v),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
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
