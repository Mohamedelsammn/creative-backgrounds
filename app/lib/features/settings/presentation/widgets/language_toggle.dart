import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Two-segment English / العربية pill toggle. Selected = black fill / white text.
class LanguageToggle extends StatelessWidget {
  const LanguageToggle({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  /// 'en' or 'ar'.
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segment('English', 'en'),
          _segment('العربية', 'ar'),
        ],
      ),
    );
  }

  Widget _segment(String label, String code) {
    final isSelected = selected == code;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onSelected(code),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: isSelected ? Colors.white : AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
