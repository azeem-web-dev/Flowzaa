import 'package:flowzaa_shared/flowzaa_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/providers.dart';
import '../util/earnings.dart';

/// Full earnings breakdown: totals + a date-grouped list of completed trips.
class EarningsScreen extends ConsumerWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(rideHistoryProvider);

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppBar(
        title: const Text('Earnings'),
        backgroundColor: AppColors.scaffold,
        elevation: 0,
      ),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('$e', style: AppText.bodySoft),
          ),
        ),
        data: (rides) => _body(context, rides),
      ),
    );
  }

  Widget _body(BuildContext context, List<Ride> rides) {
    final summary = EarningsSummary.fromRides(rides);
    final completed = rides
        .where((r) => r.status == RideStatus.completed)
        .toList();

    return Column(
      children: [
        _zeroCommissionBanner(),
        _totalsCard(summary),
        Expanded(
          child: completed.isEmpty
              ? _emptyState()
              : _tripList(completed),
        ),
      ],
    );
  }

  Widget _zeroCommissionBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.savings_outlined, color: AppColors.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Flowzaa takes 0% — riders pay you directly '
              '(cash or your UPI QR).',
              style: AppText.bodySoft.copyWith(color: AppColors.ink),
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalsCard(EarningsSummary s) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          InfoPill(
            icon: Icons.today_rounded,
            label: 'Today',
            value: Fmt.rupees(s.today),
          ),
          InfoPill(
            icon: Icons.date_range_rounded,
            label: 'This Week',
            value: Fmt.rupees(s.week),
            color: AppColors.accent,
          ),
          InfoPill(
            icon: Icons.account_balance_wallet_outlined,
            label: 'All time',
            value: Fmt.rupees(s.allTime),
            color: AppColors.info,
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.route_outlined,
              size: 48, color: AppColors.offlineGrey),
          const SizedBox(height: 12),
          Text('No trips yet — go online!',
              style: AppText.title.copyWith(color: AppColors.inkSoft)),
        ],
      ),
    );
  }

  Widget _tripList(List<Ride> completed) {
    // Rides arrive newest first; build a flat list of headers + rows.
    final items = <Widget>[];
    String? lastLabel;
    for (final ride in completed) {
      final at = rideEarnedAt(ride);
      final label = _dateLabel(at);
      if (label != lastLabel) {
        items.add(Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
          child: Text(label.toUpperCase(), style: AppText.label),
        ));
        lastLabel = label;
      }
      items.add(_tripRow(ride, at));
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: items,
    );
  }

  String _dateLabel(DateTime? at) {
    if (at == null) return 'Earlier';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(at.year, at.month, at.day);
    if (day == today) return 'Today';
    if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return DateFormat('d MMM').format(at);
  }

  Widget _tripRow(Ride ride, DateTime? at) {
    final dropArea = ride.dropoff.address ?? 'Drop point';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Text(ride.vehicleType.emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dropArea,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body,
                ),
                const SizedBox(height: 2),
                Text(
                  at == null ? '—' : DateFormat('h:mm a').format(at),
                  style: AppText.label,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(Fmt.rupees(ride.fare.total),
              style: AppText.title.copyWith(color: AppColors.success)),
        ],
      ),
    );
  }
}
