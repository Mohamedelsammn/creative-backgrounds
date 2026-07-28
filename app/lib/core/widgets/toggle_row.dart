import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Label (left) + [Switch] (right). Used in Customize (dark) and elsewhere.
class ToggleRow extends StatelessWidget {
  const ToggleRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.enabled = true,
    this.onDark = true,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? subtitle;
  final bool enabled;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final textColor = onDark ? Colors.white : AppColors.textPrimary;
    return Semantics(
      toggled: value,
      label: label,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: enabled ? textColor : textColor.withValues(alpha: 0.4),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: (onDark ? Colors.white70 : AppColors.textSecondary)
                            .withValues(alpha: enabled ? 1 : 0.4),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: enabled ? onChanged : null,
              activeThumbColor: onDark ? Colors.black : Colors.white,
              activeTrackColor: onDark ? Colors.white : AppColors.primary,
              inactiveThumbColor: Colors.white,
              inactiveTrackColor:
                  onDark ? Colors.white24 : const Color(0xFFD8D8DC),
            ),
          ],
        ),
      ),
    );
  }
}
