import 'package:flowzaa_shared/flowzaa_shared.dart';
import 'package:flutter/material.dart';

/// Vehicle-type chip picker used on profile setup and profile edit.
/// Each chip pairs a [VehicleIcon] badge with the label and lights up in the
/// vehicle's own accent color when selected.
class VehicleTypeSelector extends StatelessWidget {
  final VehicleType value;
  final ValueChanged<VehicleType> onChanged;

  const VehicleTypeSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: VehicleType.values.map((type) {
        final selected = type == value;
        return ScaleTap(
          onTap: () => onChanged(type),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: const EdgeInsets.fromLTRB(10, 8, 16, 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? type.color : AppColors.line,
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                VehicleIcon(type: type, size: 32, selected: selected),
                const SizedBox(width: 10),
                Text(
                  type.label,
                  style: AppText.title.copyWith(
                    color: selected ? type.color : AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
