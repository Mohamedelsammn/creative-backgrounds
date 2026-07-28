import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_logo.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  String _version = '1.0.0';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _version = info.version);
    } catch (_) {
      // Keep the default version.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.about)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenH),
        children: [
          const SizedBox(height: 24),
          const Center(child: AppLogo(size: 72)),
          const SizedBox(height: 16),
          Center(
            child: Text('Creative Backgrounds',
                style: AppTextStyles.sectionTitle),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(l10n.appVersion(_version),
                style: AppTextStyles.bodySmall),
          ),
          const SizedBox(height: 32),
          _tile(
            context,
            l10n.privacyPolicy,
            Icons.privacy_tip_outlined,
            () => context.push(RouteNames.privacy),
          ),
          _tile(
            context,
            l10n.termsOfService,
            Icons.description_outlined,
            () => context.push(RouteNames.terms),
          ),
          const SizedBox(height: 32),
          Center(
            child: Text(l10n.madeWithFlutter, style: AppTextStyles.caption),
          ),
        ],
      ),
    );
  }

  Widget _tile(
      BuildContext context, String title, IconData icon, VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.textPrimary),
      title: Text(title, style: AppTextStyles.bodyLarge),
      trailing:
          const Icon(Icons.chevron_right, color: AppColors.textSecondary),
      onTap: onTap,
    );
  }
}
