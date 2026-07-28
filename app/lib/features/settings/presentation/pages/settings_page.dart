import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/localization/locale_cubit.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../core/widgets/settings_row.dart';
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
                AppSpacing.screenH, 16, AppSpacing.screenH, 140),
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
                    context
                        .read<SettingsBloc>()
                        .add(SettingsLanguageChanged(code));
                  },
                ),
              ),
              SettingsRow(
                title: l10n.clearCache,
                subtitle: clearing
                    ? l10n.clearingLabel
                    : l10n.cacheUsed(formatBytes(settings?.cachedSizeBytes ?? 0)),
                trailing: const Icon(Icons.chevron_right,
                    color: AppColors.textSecondary),
                onTap: clearing ? null : () => _confirmClear(context),
              ),
              SettingsRow(
                title: l10n.about,
                subtitle: l10n.aboutSubtitle,
                trailing: const Icon(Icons.chevron_right,
                    color: AppColors.textSecondary),
                onTap: () => context.push(RouteNames.about),
                showDivider: false,
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
