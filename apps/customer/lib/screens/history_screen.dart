import 'package:flowzaa_shared/flowzaa_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/providers.dart';
import '../widgets/sheet_card.dart';
import '../widgets/tinted_circle_icon.dart';

/// The customer's past (and active) rides, newest first.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(rideHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Your rides')),
      body: history.when(
        loading: () => const _HistoryShimmer(),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Could not load rides: $e', style: AppText.bodySoft),
          ),
        ),
        data: (rides) {
          if (rides.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const TintedCircleIcon(
                    icon: Icons.receipt_long_rounded,
                    color: AppColors.primary,
                    size: 88,
                  ),
                  const SizedBox(height: 16),
                  const Text('No rides yet', style: AppText.h2),
                  const SizedBox(height: 4),
                  Text('Book your first ride!',
                      style:
                          AppText.bodySoft.copyWith(color: AppColors.inkSoft)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: rides.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 76),
            itemBuilder: (_, i) {
              final tile = _RideTile(ride: rides[i]);
              if (i >= 10) return tile;
              return FadeSlideIn(
                delay: Duration(milliseconds: 40 * i),
                duration: const Duration(milliseconds: 300),
                child: tile,
              );
            },
          );
        },
      ),
    );
  }
}

/// Skeleton list shown while the ride history first loads.
class _HistoryShimmer extends StatelessWidget {
  const _HistoryShimmer();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        for (var i = 0; i < 6; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(
                  width: 44,
                  height: 44,
                  borderRadius: BorderRadius.circular(14),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const ShimmerBox(width: 140, height: 12),
                      const SizedBox(height: 8),
                      ShimmerBox(
                        width: double.infinity,
                        height: 12,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      const SizedBox(height: 8),
                      const ShimmerBox(width: 200, height: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

Color _statusColor(RideStatus status) {
  switch (status) {
    case RideStatus.completed:
      return AppColors.success;
    case RideStatus.cancelled:
    case RideStatus.expired:
      return AppColors.danger;
    default:
      return AppColors.primary;
  }
}

String _statusText(RideStatus status) {
  switch (status) {
    case RideStatus.completed:
      return 'Completed';
    case RideStatus.cancelled:
      return 'Cancelled';
    case RideStatus.expired:
      return 'Expired';
    default:
      return 'Active';
  }
}

class _RideTile extends StatelessWidget {
  final Ride ride;
  const _RideTile({required this.ride});

  @override
  Widget build(BuildContext context) {
    final when = ride.createdAt == null
        ? ''
        : DateFormat('d MMM yyyy · h:mm a').format(ride.createdAt!);

    return ScaleTap(
      onTap: () => _showDetail(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            VehicleIcon(type: ride.vehicleType, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(when, style: AppText.label)),
                      _StatusChip(status: ride.status),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _addressLine(Icons.trip_origin, AppColors.primary,
                      ride.pickup.address ?? 'Pickup'),
                  const SizedBox(height: 4),
                  _addressLine(Icons.location_on_rounded, AppColors.danger,
                      ride.dropoff.address ?? 'Destination'),
                  const SizedBox(height: 6),
                  Text(Fmt.rupees(ride.fare.total), style: AppText.title),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _addressLine(IconData icon, Color color, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: AppText.bodySoft,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _RideDetailSheet(ride: ride),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final RideStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _statusText(status),
        style: AppText.label.copyWith(color: color, fontSize: 12),
      ),
    );
  }
}

class _RideDetailSheet extends StatelessWidget {
  final Ride ride;
  const _RideDetailSheet({required this.ride});

  @override
  Widget build(BuildContext context) {
    final fare = ride.fare;
    final when = ride.createdAt == null
        ? '—'
        : DateFormat('EEE, d MMM yyyy · h:mm a').format(ride.createdAt!);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(),
            Row(
              children: [
                VehicleIcon(type: ride.vehicleType, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child:
                      Text('${ride.vehicleType.label} ride', style: AppText.h2),
                ),
                _StatusChip(status: ride.status),
              ],
            ),
            const SizedBox(height: 4),
            Text(when, style: AppText.bodySoft),
            const SizedBox(height: 16),

            // Addresses.
            _detailRow(Icons.trip_origin, AppColors.primary, 'From',
                ride.pickup.address ?? '—'),
            const SizedBox(height: 10),
            _detailRow(Icons.location_on_rounded, AppColors.danger, 'To',
                ride.dropoff.address ?? '—'),
            const Divider(height: 28),

            // Fare breakdown.
            const Text('Fare', style: AppText.title),
            const SizedBox(height: 8),
            _fareRow('Base fare', Fmt.rupees(fare.base, decimals: true)),
            _fareRow('Distance (${Fmt.distance(ride.distanceMeters)})',
                Fmt.rupees(fare.distanceFare, decimals: true)),
            _fareRow('Time (${Fmt.duration(ride.durationSeconds)})',
                Fmt.rupees(fare.timeFare, decimals: true)),
            if (fare.surge > 0)
              _fareRow('Surge', Fmt.rupees(fare.surge, decimals: true)),
            const Divider(height: 20),
            _fareRow('Total', Fmt.rupees(fare.total), bold: true),
            const Divider(height: 28),

            // Captain + payment.
            _kv('Captain', ride.captainName ?? '—'),
            const SizedBox(height: 6),
            _kv('Payment', ride.paymentMethod.label),
            if (ride.cancelReason != null && ride.cancelReason!.isNotEmpty) ...[
              const SizedBox(height: 6),
              _kv('Cancel reason', ride.cancelReason!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, Color color, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppText.label),
              const SizedBox(height: 2),
              Text(value, style: AppText.body),
            ],
          ),
        ),
      ],
    );
  }

  Widget _fareRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: bold ? AppText.title : AppText.bodySoft),
          Text(value, style: bold ? AppText.price : AppText.body),
        ],
      ),
    );
  }

  Widget _kv(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppText.bodySoft),
        Flexible(
          child:
              Text(value, style: AppText.body, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}
