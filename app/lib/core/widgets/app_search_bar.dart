import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/app_colors.dart';
import '../theme/app_shapes.dart';
import '../theme/app_text_styles.dart';

/// Pill-shaped search field used on Explore and View All.
///
/// In "tap-to-navigate" mode (default) it renders as a non-editable pill and
/// fires [onTap]. When [onChanged] is provided it becomes an active text field
/// (used on the Search screen).
class AppSearchBar extends StatelessWidget {
  const AppSearchBar({
    super.key,
    this.hintText,
    this.onTap,
    this.onChanged,
    this.onSubmitted,
    this.controller,
    this.autofocus = false,
    this.enabled = true,
  });

  /// Overrides the default localized "Search wallpapers…" hint.
  final String? hintText;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextEditingController? controller;
  final bool autofocus;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final bool interactive = onChanged != null || autofocus;
    final String hint = hintText ?? context.l10n.searchWallpapers;

    return Semantics(
      textField: true,
      label: hint,
      button: !interactive,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppShapes.pill,
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 20,
              offset: Offset(0, 6),
            ),
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            const Icon(Icons.search, size: 20, color: AppColors.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: interactive
                  ? TextField(
                      controller: controller,
                      autofocus: autofocus,
                      enabled: enabled,
                      onChanged: onChanged,
                      onSubmitted: onSubmitted,
                      textInputAction: TextInputAction.search,
                      style: AppTextStyles.bodyMedium,
                      cursorColor: AppColors.primary,
                      decoration: InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        hintText: hint,
                        hintStyle: AppTextStyles.bodyMedium
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    )
                  : GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onTap,
                      child: Text(
                        hint,
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
