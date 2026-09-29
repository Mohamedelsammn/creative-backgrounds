import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/ads/ad_manager.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/localization/locale_cubit.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../core/widgets/settings_row.dart';
import '../../../../features/update/domain/update_config.dart';
import '../../../../injection.dart';
import '../bloc/settings_bloc.dart';
import '../widgets/language_toggle.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<SettingsBloc>()..add(const SettingsLoadRequested()),
      child: const _SettingsView(),
    );
  }
}

class _SettingsView extends StatelessWidget {
  const _SettingsView();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, state) {
          final settings = state is SettingsLoaded ? state.settings : null;
          final clearing = state is SettingsCacheClearing;
          final l10n = context.l10n;
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              16,
              AppSpacing.screenH,
              140,
            ),
            children: [
              Text(l10n.settings, style: AppTextStyles.displayLarge),
              const SizedBox(height: 16),
              SettingsRow(
                title: l10n.language,
                subtitle: l10n.languageSubtitle,
                trailing: LanguageToggle(
                  selected: settings?.language ?? 'en',
                  onSelected: (code) {
                    context.read<LocaleCubit>().setLocale(code);
                    context.read<SettingsBloc>().add(
                      SettingsLanguageChanged(code),
                    );
                  },
                ),
              ),
              SettingsRow(
                title: l10n.clearCache,
                subtitle: clearing
                    ? l10n.clearingLabel
                    : l10n.cacheUsed(
                        formatBytes(settings?.cachedSizeBytes ?? 0),
                      ),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: AppColors.textSecondary,
                ),
                onTap: clearing ? null : () => _confirmClear(context),
              ),
              SettingsRow(
                title: l10n.rateApp,
                subtitle: l10n.rateAppSubtitle,
                trailing: const Icon(
                  Icons.chevron_right,
                  color: AppColors.textSecondary,
                ),
                onTap: () => _rateApp(context),
              ),
              SettingsRow(
                title: l10n.shareApp,
                subtitle: l10n.shareAppSubtitle,
                trailing: const Icon(
                  Icons.chevron_right,
                  color: AppColors.textSecondary,
                ),
                onTap: () => _shareApp(context),
              ),

              SettingsRow(
                title: l10n.about,
                subtitle: l10n.aboutSubtitle,
                trailing: const Icon(
                  Icons.chevron_right,
                  color: AppColors.textSecondary,
                ),
                onTap: () => context.push(RouteNames.about),
              ),
              FutureBuilder<PrivacyOptionsRequirementStatus>(
                future: ConsentInformation.instance
                    .getPrivacyOptionsRequirementStatus(),
                builder: (context, snapshot) {
                  // UMP policy requires this entry point only when consent
                  // was actually required (EEA/UK) - hidden elsewhere rather
                  // than always shown, matching the rest of this screen's
                  // sparse, only-what's-relevant style.
                  if (snapshot.data != PrivacyOptionsRequirementStatus.required) {
                    return const SizedBox.shrink();
                  }
                  return SettingsRow(
                    title: l10n.privacyOptions,
                    subtitle: l10n.privacyOptionsSubtitle,
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: AppColors.textSecondary,
                    ),
                    onTap: () => AdManager.instance.showPrivacyOptionsForm(),
                    showDivider: false,
                  );
                },
              ),
              const SizedBox(height: 40),
              Center(
                child: Text(
                  'Creative Backgrounds · ${settings?.appVersion ?? '1.0.0'}',
                  style: AppTextStyles.caption,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Rates the app.
  ///
  /// This is the USER-INITIATED entry point, so it deliberately ignores
  /// `ReviewService`'s engagement threshold and once-per-version guard -
  /// those exist to stop the app nagging on its own, not to refuse someone
  /// who went looking for this row. It still prefers Play's in-app sheet
  /// (no context switch) and falls back to the store listing whenever Play
  /// declines or is unavailable.
  Future<void> _rateApp(BuildContext context) async {
    final review = InAppReview.instance;
    try {
      if (await review.isAvailable()) {
        await review.requestReview();
        return;
      }
    } catch (_) {
      // Fall through to the listing below.
    }

    if (!context.mounted) return;
    final uri = Uri.parse(UpdateConfig.playStoreUrl);
    var launched = false;
    try {
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      launched = false;
    }
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.storeUnavailable)));
    }
  }

  void _shareApp(BuildContext context) {
    Share.share(context.l10n.shareAppMessage(UpdateConfig.playStoreUrl));
  }

  void _confirmClear(BuildContext context) {
    final bloc = context.read<SettingsBloc>();
    final l10n = context.l10n;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.clearCacheConfirmTitle),
        content: Text(l10n.clearCacheConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              bloc.add(const SettingsClearCacheRequested());
              Navigator.of(dialogContext).pop();
            },
            child: Text(l10n.clear),
          ),
        ],
      ),
    );
  }
}
