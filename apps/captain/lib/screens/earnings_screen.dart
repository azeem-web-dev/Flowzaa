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
        loading: () => _loadingShimmer(),
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
        FadeSlideIn(child: _zeroCommissionBanner()),
        FadeSlideIn(
          delay: const Duration(milliseconds: 60),
          child: _totalsCard(summary),
        ),
        Expanded(
          child: completed.isEmpty
              ? _emptyState()
              : _tripList(completed),
        ),
      ],
    );
  }

  /// Skeleton layout mirroring the banner, totals card and trip rows.
  Widget _loadingShimmer() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        const ShimmerBox(
            height: 56, borderRadius: BorderRadius.all(Radius.circular(14))),
        const SizedBox(height: 12),
        const ShimmerBox(
            height: 96, borderRadius: BorderRadius.all(Radius.circular(18))),
        const SizedBox(height: 24),
        const ShimmerBox(height: 14, width: 80),
        const SizedBox(height: 12),
        for (var i = 0; i < 6; i++) ...[
          const ShimmerBox(
              height: 68,
              borderRadius: BorderRadius.all(Radius.circular(14))),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _zeroCommissionBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.savings_outlined, color: AppColors.primary),
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
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: IntrinsicHeight(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: InfoPill(
                icon: Icons.today_rounded,
                label: 'Today',
                value: Fmt.rupees(s.today),
              ),
            ),
            const VerticalDivider(
                width: 1, thickness: 1, color: AppColors.line),
            Expanded(
              child: InfoPill(
                icon: Icons.date_range_rounded,
                label: 'This Week',
                value: Fmt.rupees(s.week),
              ),
            ),
            const VerticalDivider(
                width: 1, thickness: 1, color: AppColors.line),
            Expanded(
              child: InfoPill(
                icon: Icons.account_balance_wallet_outlined,
                label: 'All time',
                value: Fmt.rupees(s.allTime),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: FadeSlideIn(
        delay: const Duration(milliseconds: 120),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: AppColors.iconSurface,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.savings_rounded,
                  size: 40, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 14),
            Text('No trips yet — go online!',
                style: AppText.title.copyWith(color: AppColors.inkSoft)),
            const SizedBox(height: 4),
            const Text('Every rupee you earn shows up here.',
                style: AppText.bodySoft),
          ],
        ),
      ),
    );
  }

  Widget _tripList(List<Ride> completed) {
    // Rides arrive newest first; build a flat list of headers + rows with a
    // staggered entrance (capped so long histories don't wait forever).
    final items = <Widget>[];
    String? lastLabel;
    var index = 0;
    for (final ride in completed) {
      final at = rideEarnedAt(ride);
      final label = _dateLabel(at);
      final delay = Duration(milliseconds: 50 * (index < 10 ? index : 10));
      if (label != lastLabel) {
        items.add(FadeSlideIn(
          delay: delay,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
            child: Text(label.toUpperCase(), style: AppText.label),
          ),
        ));
        lastLabel = label;
      }
      items.add(FadeSlideIn(delay: delay, child: _tripRow(ride, at)));
      index++;
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
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          VehicleIcon(type: ride.vehicleType, size: 38),
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
