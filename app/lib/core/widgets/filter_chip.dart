import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Light pill with a leading icon + label. Used for the View All
/// "Filters" / "Sort" chips. [active] darkens the pill when a filter/sort is
/// applied.
class IconPillChip extends StatelessWidget {
  const IconPillChip({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final fg = active ? Colors.white : AppColors.textPrimary;
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: active ? AppColors.primary : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTextStyles.bodySmall
                    .copyWith(color: fg, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Filters" pill.
class FilterPill extends StatelessWidget {
  const FilterPill({super.key, required this.onTap, this.active = false});
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) => IconPillChip(
        icon: Icons.tune_rounded,
        label: 'Filters',
        onTap: onTap,
        active: active,
      );
}
