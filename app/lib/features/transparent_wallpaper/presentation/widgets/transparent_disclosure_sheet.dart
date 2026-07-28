import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shapes.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/bottom_sheet_handle.dart';

/// Prominent camera disclosure shown before any camera access, as required by
/// Google Play's background-camera policy. Returns true if the user accepts.
class TransparentDisclosureSheet {
  const TransparentDisclosureSheet._();

  static Future<bool> show(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (_) => const _DisclosureBody(),
    );
    return result ?? false;
  }
}

class _DisclosureBody extends StatelessWidget {
  const _DisclosureBody();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BottomSheetHandle(),
                const SizedBox(height: 12),
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: AppColors.surfaceVariant,
                  ),
                  child: const Icon(Icons.photo_camera_outlined,
                      color: AppColors.textPrimary, size: 26),
                ),
                const SizedBox(height: 16),
                Text(l10n.twDisclosureTitle,
                    style: AppTextStyles.displayLarge.copyWith(fontSize: 24)),
                const SizedBox(height: 12),
                Text(
                  l10n.twDisclosureBody,
                  style: AppTextStyles.bodyMedium.copyWith(height: 1.5),
                ),
                const SizedBox(height: 24),
                _FilledButton(
                  label: l10n.twDisclosureAccept,
                  onTap: () => Navigator.of(context).pop(true),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(
                      l10n.twDisclosureDecline,
                      style: AppTextStyles.bodyLarge
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FilledButton extends StatelessWidget {
  const _FilledButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: AppColors.primary,
        borderRadius: AppShapes.pill,
        child: InkWell(
          borderRadius: AppShapes.pill,
          onTap: onTap,
          child: Container(
            height: 54,
            alignment: Alignment.center,
            child: Text(label,
                style: AppTextStyles.bodyLarge
                    .copyWith(color: AppColors.onPrimary)),
          ),
        ),
      ),
    );
  }
}
