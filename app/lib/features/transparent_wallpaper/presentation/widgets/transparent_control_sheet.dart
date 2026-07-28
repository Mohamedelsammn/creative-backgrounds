import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shapes.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/bottom_sheet_handle.dart';
import '../../domain/entities/compatibility_report.dart';
import '../../domain/entities/tw_permissions.dart';
import '../bloc/transparent_wallpaper_bloc.dart';
import 'transparent_disclosure_sheet.dart';
import 'transparent_status_pill.dart';

/// Bottom sheet that surfaces every status state for the transparent wallpaper:
/// compatibility, permission state, live runtime status, and the primary
/// action. Opened from the Explore feature card.
class TransparentControlSheet {
  const TransparentControlSheet._();

  static Future<void> show(
    BuildContext context, {
    required TransparentWallpaperBloc bloc,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => BlocProvider.value(
        value: bloc,
        child: _Body(
          onContinue: () {
            Navigator.of(sheetContext).pop();
            context.push(RouteNames.transparentPreview);
          },
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.onContinue});

  final VoidCallback onContinue;

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
            // Extra bottom clearance so content never hides behind the
            // always-visible floating bottom nav.
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 96),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BottomSheetHandle(),
                const SizedBox(height: 8),
                Text(l10n.transparentWallpaper,
                    style: AppTextStyles.displayLarge.copyWith(fontSize: 24)),
                const SizedBox(height: 6),
                Text(l10n.transparentWallpaperSubtitle,
                    style: AppTextStyles.bodySmall),
                const SizedBox(height: 20),
                BlocBuilder<TransparentWallpaperBloc, TransparentWallpaperState>(
                  builder: (context, state) {
                    if (state.phase == TwViewPhase.loading) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    return _content(context, state);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, TransparentWallpaperState state) {
    if (!state.isSupported) {
      return _UnsupportedContent(report: state.compatibility);
    }
    final oemWarning = state.compatibility?.manufacturerWarning;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(alignment: Alignment.centerLeft, child: TransparentStatusPill(state: state)),
        const SizedBox(height: 16),
        Text(context.l10n.twPermissionRationale,
            style: AppTextStyles.bodyMedium.copyWith(height: 1.4)),
        if (oemWarning != null) ...[
          const SizedBox(height: 16),
          _OemWarning(detail: oemWarning.detail),
        ],
        if (state.errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(state.errorMessage!,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
        ],
        const SizedBox(height: 24),
        _PrimaryAction(state: state, onContinue: onContinue),
      ],
    );
  }
}

/// Shows why the feature can't run + the blocking checks.
class _UnsupportedContent extends StatelessWidget {
  const _UnsupportedContent({required this.report});

  final CompatibilityReport? report;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final failing = report?.checks
            .where((c) => c.status == TwCheckStatus.fail)
            .toList() ??
        const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.block, color: AppColors.error, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(l10n.twUnsupportedTitle,
                  style: AppTextStyles.bodyLarge),
            ),
          ],
        ),
        if (report?.summary.isNotEmpty ?? false) ...[
          const SizedBox(height: 8),
          Text(report!.summary, style: AppTextStyles.bodySmall),
        ],
        const SizedBox(height: 16),
        for (final check in failing)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.close, size: 16, color: AppColors.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${check.label}: ${check.detail}',
                      style: AppTextStyles.bodySmall),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Amber advisory card for aggressive-OEM devices, with a shortcut to the
/// system battery-optimization settings so the wallpaper survives backgrounding.
class _OemWarning extends StatelessWidget {
  const _OemWarning({required this.detail});

  final String detail;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const amber = Color(0xFFFF9500);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: amber.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: amber.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.battery_alert_outlined, size: 18, color: amber),
              const SizedBox(width: 8),
              Expanded(
                child: Text(l10n.twOemWarningTitle,
                    style: AppTextStyles.bodyLarge.copyWith(fontSize: 14)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(detail, style: AppTextStyles.bodySmall.copyWith(height: 1.4)),
          const SizedBox(height: 10),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () => context
                  .read<TransparentWallpaperBloc>()
                  .add(const TransparentBatterySettingsRequested()),
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              child: Text(l10n.twBatterySettings,
                  style: AppTextStyles.bodyLarge
                      .copyWith(fontSize: 14, color: AppColors.textPrimary)),
            ),
          ),
        ],
      ),
    );
  }
}

/// The context-aware primary button (grant / continue / turn off).
class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({required this.state, required this.onContinue});

  final TransparentWallpaperState state;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bloc = context.read<TransparentWallpaperBloc>();

    // Already running → offer to turn off.
    if (state.isActive) {
      return _Button(
        label: l10n.twTurnOff,
        busy: state.busy,
        filled: false,
        onTap: () => bloc.add(const TransparentDeactivationRequested()),
      );
    }
    // Camera permanently denied → send to settings.
    final perm = state.permissions?.camera;
    if (perm == TwPermissionStatus.permanentlyDenied ||
        perm == TwPermissionStatus.restricted) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.twCameraPermanentlyDenied,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
          const SizedBox(height: 12),
          _Button(
            label: l10n.twOpenSettings,
            busy: false,
            onTap: () => bloc.add(const TransparentSettingsRequested()),
          ),
        ],
      );
    }
    // Camera not granted yet → disclosure, then request it.
    if (!state.cameraGranted) {
      return _Button(
        label: l10n.twGrantCameraPermission,
        busy: state.busy,
        onTap: () async {
          if (await _ensureDisclosed(context, bloc)) {
            bloc.add(const TransparentPermissionsRequested());
          }
        },
      );
    }
    // Supported + permitted → disclosure (if not yet shown), then live preview.
    return _Button(
      label: l10n.twContinue,
      busy: state.busy,
      onTap: () async {
        if (await _ensureDisclosed(context, bloc)) onContinue();
      },
    );
  }

  /// Guarantees the prominent camera disclosure has been accepted before any
  /// camera access (permission request or preview). Returns false if declined.
  Future<bool> _ensureDisclosed(
    BuildContext context,
    TransparentWallpaperBloc bloc,
  ) async {
    if (state.disclosureAccepted) return true;
    final accepted = await TransparentDisclosureSheet.show(context);
    if (accepted) bloc.add(const TransparentDisclosureAccepted());
    return accepted;
  }
}

class _Button extends StatelessWidget {
  const _Button({
    required this.label,
    required this.onTap,
    this.busy = false,
    this.filled = true,
  });

  final String label;
  final VoidCallback onTap;
  final bool busy;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final bg = filled ? AppColors.primary : AppColors.surfaceVariant;
    final fg = filled ? AppColors.onPrimary : AppColors.textPrimary;
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: bg,
        borderRadius: AppShapes.pill,
        child: InkWell(
          borderRadius: AppShapes.pill,
          onTap: busy ? null : onTap,
          child: Container(
            height: 54,
            alignment: Alignment.center,
            child: busy
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                  )
                : Text(label, style: AppTextStyles.bodyLarge.copyWith(color: fg)),
          ),
        ),
      ),
    );
  }
}
