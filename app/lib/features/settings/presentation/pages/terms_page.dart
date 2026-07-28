import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.termsOfService)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenH),
        children: [
          Text(l10n.termsOfService, style: AppTextStyles.sectionTitle),
          const SizedBox(height: 12),
          Text(
            l10n.termsBody,
            style: AppTextStyles.bodyMedium
                .copyWith(height: 1.6, color: const Color(0xFF3A3A3A)),
          ),
        ],
      ),
    );
  }
}
