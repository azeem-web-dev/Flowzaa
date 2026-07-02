import 'package:flowzaa_shared/flowzaa_shared.dart';
import 'package:flutter/material.dart';

/// A slim horizontal ride-progress timeline:
/// Searching → Accepted → Arrived → On trip → Done.
class StatusTimeline extends StatelessWidget {
  final RideStatus status;
  const StatusTimeline({super.key, required this.status});

  static const _steps = ['Searching', 'Accepted', 'Arrived', 'On trip', 'Done'];

  int get _index {
    switch (status) {
      case RideStatus.searching:
        return 0;
      case RideStatus.accepted:
        return 1;
      case RideStatus.arrived:
        return 2;
      case RideStatus.ongoing:
        return 3;
      case RideStatus.completed:
        return 4;
      case RideStatus.cancelled:
      case RideStatus.expired:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = _index;
    return Row(
      children: List.generate(_steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          // Connector line between dots.
          final leftStep = i ~/ 2;
          final done = leftStep < current;
          return Expanded(
            child: Container(
              height: 2.5,
              margin: const EdgeInsets.only(bottom: 16),
              color: done ? AppColors.primary : AppColors.line,
            ),
          );
        }
        final step = i ~/ 2;
        final done = step < current;
        final active = step == current;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done || active ? AppColors.primary : Colors.white,
                border: Border.all(
                  color: done || active ? AppColors.primary : AppColors.line,
                  width: 2,
                ),
              ),
              child: done
                  ? const Icon(Icons.check, size: 9, color: Colors.white)
                  : null,
            ),
            const SizedBox(height: 4),
            Text(
              _steps[step],
              style: AppText.label.copyWith(
                fontSize: 10,
                color: active
                    ? AppColors.primaryDark
                    : (done ? AppColors.ink : AppColors.inkSoft),
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        );
      }),
    );
  }
}
