import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Standard empty state: icon + headline + subtext.
class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    super.key,
    required this.headline,
    required this.subtext,
    this.icon = Icons.favorite_border_rounded,
  });

  final String headline;
  final String subtext;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(headline,
                style: AppTextStyles.sectionTitle, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(subtext, style: AppTextStyles.bodySmall, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
