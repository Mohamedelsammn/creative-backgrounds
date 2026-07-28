import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../channels/wallpaper_channel.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shapes.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/bottom_sheet_handle.dart';
import '../../../../injection.dart';
import '../../../clock/domain/entities/clock_config_entity.dart';
import '../../../depth/domain/entities/depth_config_entity.dart';
import '../../../explore/domain/entities/wallpaper_entity.dart';
import '../bloc/apply_wallpaper_bloc.dart';

/// Opens the apply destination sheet. Plain wallpapers show Home/Lock/Both;
/// clock/depth wallpapers show a single "Set as live wallpaper" (opens the
/// system picker), matching Android's live-wallpaper constraints.
Future<void> showApplyWallpaperSheet(
  BuildContext context, {
  required WallpaperEntity wallpaper,
  ClockConfigEntity? clockConfig,
  DepthConfigEntity? depthConfig,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    isDismissible: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => BlocProvider(
      create: (_) => sl<ApplyWallpaperBloc>(),
      child: _ApplySheet(
        wallpaper: wallpaper,
        clockConfig: clockConfig,
        depthConfig: depthConfig,
      ),
    ),
  );
}

class _ApplySheet extends StatelessWidget {
  const _ApplySheet({
    required this.wallpaper,
    this.clockConfig,
    this.depthConfig,
  });

  final WallpaperEntity wallpaper;
  final ClockConfigEntity? clockConfig;
  final DepthConfigEntity? depthConfig;

  bool get _isLive =>
      clockConfig != null || (depthConfig?.enabled ?? false);

  void _apply(BuildContext context, ApplyDestination destination) {
    context.read<ApplyWallpaperBloc>().add(ApplyWallpaperRequested(
          wallpaper: wallpaper,
          destination: destination,
          clockConfig: clockConfig,
          depthConfig: depthConfig,
        ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ApplyWallpaperBloc, ApplyWallpaperState>(
      listener: (context, state) {
        if (state is ApplyWallpaperSuccess) {
          Navigator.of(context).pop();
          context.push(RouteNames.success);
        } else if (state is ApplyWallpaperError) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(state.message)));
        }
      },
      builder: (context, state) {
        final inProgress = state is ApplyWallpaperInProgress;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const BottomSheetHandle(color: Color(0xFFDDDDDD)),
                const SizedBox(height: 8),
                Text(context.l10n.applyTo,
                    style: AppTextStyles.sectionTitle,
                    textAlign: TextAlign.center),
                const SizedBox(height: 20),
                if (inProgress)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_isLive)
                  _DestinationButton(
                    label: context.l10n.setAsLiveWallpaper,
                    filled: true,
                    onTap: () => _apply(context, ApplyDestination.both),
                  )
                else ...[
                  _DestinationButton(
                    label: context.l10n.homeScreen,
                    filled: true,
                    onTap: () => _apply(context, ApplyDestination.homeScreen),
                  ),
                  const SizedBox(height: 10),
                  _DestinationButton(
                    label: context.l10n.lockScreen,
                    onTap: () => _apply(context, ApplyDestination.lockScreen),
                  ),
                  const SizedBox(height: 10),
                  _DestinationButton(
                    label: context.l10n.homeAndLockScreen,
                    onTap: () => _apply(context, ApplyDestination.both),
                  ),
                ],
                const SizedBox(height: 8),
                if (!inProgress)
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(context.l10n.cancel),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DestinationButton extends StatelessWidget {
  const _DestinationButton({
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? AppColors.primary : AppColors.surfaceVariant,
      borderRadius: AppShapes.pill,
      child: InkWell(
        borderRadius: AppShapes.pill,
        onTap: onTap,
        child: Container(
          height: 54,
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTextStyles.bodyLarge.copyWith(
              color: filled ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
