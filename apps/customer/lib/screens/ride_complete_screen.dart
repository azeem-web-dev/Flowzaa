import 'package:flowzaa_shared/flowzaa_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../providers/providers.dart';

class RideCompleteScreen extends ConsumerStatefulWidget {
  final String rideId;
  const RideCompleteScreen({super.key, required this.rideId});

  @override
  ConsumerState<RideCompleteScreen> createState() => _RideCompleteScreenState();
}

class _RideCompleteScreenState extends ConsumerState<RideCompleteScreen> {
  final _reviewCtrl = TextEditingController();
  int _stars = 0;
  bool _saving = false;

  @override
  void dispose() {
    _reviewCtrl.dispose();
    super.dispose();
  }

  Future<void> _done() async {
    if (_stars > 0) {
      setState(() => _saving = true);
      try {
        await ref.read(rideServiceProvider).rateByCustomer(
              widget.rideId,
              _stars,
              _reviewCtrl.text.trim().isEmpty ? null : _reviewCtrl.text.trim(),
            );
      } catch (_) {
        // best-effort rating
      }
    }
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final rideStream = ref.watch(rideServiceProvider);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Trip complete'),
      ),
      body: StreamBuilder<Ride?>(
        stream: rideStream.watchRide(widget.rideId),
        builder: (context, snap) {
          final ride = snap.data;
          if (ride == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final fare = ride.fare;
          final upiId = (ride.captainVehicle?['upiId'] as String?) ?? '';

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const SizedBox(height: 8),
              // Success check — pops in with a scale + fade.
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.6, end: 1.0),
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeOutBack,
                builder: (context, t, child) => Transform.scale(
                  scale: t,
                  child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
                ),
                child: Center(
                  child: Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.success.withOpacity(0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.check_rounded,
                        color: Colors.white, size: 40),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const FadeSlideIn(
                delay: Duration(milliseconds: 100),
                child: Center(child: Text('Ride completed', style: AppText.h1)),
              ),
              const SizedBox(height: 4),
              const FadeSlideIn(
                delay: Duration(milliseconds: 160),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.celebration_rounded,
                          size: 16, color: AppColors.accent),
                      SizedBox(width: 6),
                      Text('Thanks for riding with Flowzaa',
                          style: AppText.bodySoft),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Fare breakdown card.
              FadeSlideIn(
                delay: const Duration(milliseconds: 220),
                child: _Card(
                  child: Column(
                    children: [
                      _row('Base fare', Fmt.rupees(fare.base, decimals: true)),
                      _row('Distance (${Fmt.distance(ride.distanceMeters)})',
                          Fmt.rupees(fare.distanceFare, decimals: true)),
                      _row('Time (${Fmt.duration(ride.durationSeconds)})',
                          Fmt.rupees(fare.timeFare, decimals: true)),
                      if (fare.surge > 0)
                        _row('Surge', Fmt.rupees(fare.surge, decimals: true)),
                      const Divider(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total', style: AppText.title),
                            // Fare number scales in for a satisfying reveal.
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.8, end: 1.0),
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.easeOutBack,
                              builder: (context, t, child) => Transform.scale(
                                scale: t,
                                child: Opacity(
                                  opacity: t.clamp(0.0, 1.0),
                                  child: child,
                                ),
                              ),
                              child: Text(Fmt.rupees(fare.total),
                                  style: AppText.price),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Payment reminder / UPI QR.
              FadeSlideIn(
                delay: const Duration(milliseconds: 280),
                child: _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            ride.paymentMethod == PaymentMethod.upi
                                ? Icons.qr_code_rounded
                                : Icons.payments_rounded,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(ride.paymentMethod.label, style: AppText.title),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (ride.paymentMethod == PaymentMethod.upi &&
                          upiId.isNotEmpty)
                        Center(
                          child: QrImageView(
                            data:
                                'upi://pay?pa=$upiId&pn=${Uri.encodeComponent(ride.captainName ?? 'Captain')}&am=${fare.total}&cu=INR',
                            size: 180,
                          ),
                        )
                      else
                        Text(
                          'Pay ${Fmt.rupees(fare.total)} directly to your captain by '
                          '${ride.paymentMethod == PaymentMethod.upi ? 'UPI' : 'Cash'} — Flowzaa takes 0%.',
                          style: AppText.bodySoft,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Rating.
              FadeSlideIn(
                delay: const Duration(milliseconds: 340),
                child: _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Rate your captain', style: AppText.title),
                      const SizedBox(height: 8),
                      Center(
                        child: RatingStars(
                          value: _stars.toDouble(),
                          size: 40,
                          onRate: (v) => setState(() => _stars = v),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _reviewCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          hintText: 'Add a note (optional)',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FadeSlideIn(
                delay: const Duration(milliseconds: 400),
                child: PrimaryButton(
                  label: 'Done',
                  loading: _saving,
                  onPressed: _done,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: bold ? AppText.title : AppText.bodySoft),
          Text(value, style: bold ? AppText.price : AppText.body),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: child,
    );
  }
}
