import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shapes.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../injection.dart';
import '../bloc/transparent_wallpaper_bloc.dart';
import '../widgets/transparent_status_pill.dart';
import '../widgets/tw_status_messages.dart';

/// Settings / control screen for the transparent wallpaper. Minimal in Phase 9
/// (status + turn-off); resolution / FPS / mirror controls arrive in Phase 16.
class TransparentSettingsPage extends StatelessWidget {
  const TransparentSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<TransparentWallpaperBloc>.value(
      value: sl<TransparentWallpaperBloc>()
        ..add(const TransparentWallpaperStarted()),
      child: const _SettingsView(),
    );
  }
}

class _SettingsView extends StatelessWidget {
  const _SettingsView();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(l10n.transparentWallpaper, style: AppTextStyles.bodyLarge),
      ),
      body: BlocBuilder<TransparentWallpaperBloc, TransparentWallpaperState>(
        builder: (context, state) {
          if (state.phase == TwViewPhase.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      l10n.transparentWallpaper,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.sectionTitle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TransparentStatusPill(state: state),
                ],
              ),
              const SizedBox(height: 12),
              Builder(
                builder: (context) {
                  final msg = twStatusMessage(context, state.runtime);
                  return Text(
                    msg ?? l10n.twPermissionRationale,
                    style: AppTextStyles.bodySmall.copyWith(
                      height: 1.4,
                      color: state.runtime.isError
                          ? AppColors.error
                          : AppColors.textSecondary,
                    ),
                  );
                },
              ),
              const SizedBox(height: 28),

              // Quality preset (drives native FPS + resolution).
              Text(l10n.twQuality, style: AppTextStyles.sectionTitle),
              const SizedBox(height: 12),
              _QualitySelector(
                fps: state.settings.fps,
                onChanged: (fps) => context
                    .read<TransparentWallpaperBloc>()
                    .add(TransparentFpsChanged(fps)),
              ),
              const SizedBox(height: 8),
              Text(l10n.twQualityHint, style: AppTextStyles.bodySmall),
              const SizedBox(height: 28),

              if (state.isActive)
                _ActionButton(
                  label: l10n.twTurnOff,
                  busy: state.busy,
                  onTap: () => context
                      .read<TransparentWallpaperBloc>()
                      .add(const TransparentDeactivationRequested()),
                ),
              if (state.runtime.isError) ...[
                if (state.isActive) const SizedBox(height: 12),
                _ActionButton(
                  label: l10n.twRetry,
                  busy: state.busy,
                  onTap: () => context
                      .read<TransparentWallpaperBloc>()
                      .add(const TransparentActivationRequested()),
                ),
              ],
              const SizedBox(height: 12),
              _ActionButton(
                label: l10n.twRestoreWallpaper,
                busy: state.busy,
                filled: false,
                onTap: () => context
                    .read<TransparentWallpaperBloc>()
                    .add(const TransparentRestoreRequested()),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
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
                : Text(label,
                    style: AppTextStyles.bodyLarge.copyWith(color: fg)),
          ),
        ),
      ),
    );
  }
}

/// Light 3-way quality selector (Smooth 30 / Balanced 24 / Saver 15 fps).
class _QualitySelector extends StatelessWidget {
  const _QualitySelector({required this.fps, required this.onChanged});

  final int fps;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final options = <int, String>{
      30: l10n.twQualitySmooth,
      24: l10n.twQualityBalanced,
      15: l10n.twQualitySaver,
    };
    return Row(
      children: [
        for (final entry in options.entries) ...[
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(entry.key),
              child: Container(
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: entry.key == fps
                      ? AppColors.primary
                      : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  entry.value,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: entry.key == fps
                        ? AppColors.onPrimary
                        : AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
          if (entry.key != options.keys.last) const SizedBox(width: 8),
        ],
      ],
    );
  }
}
