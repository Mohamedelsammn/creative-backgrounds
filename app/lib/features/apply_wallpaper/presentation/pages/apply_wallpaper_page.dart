import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../channels/wallpaper_channel.dart';
import '../../../../core/ads/ad_manager.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shapes.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/bottom_sheet_handle.dart';
import '../../../../core/widgets/wallpaper_preview_composition.dart';
import '../../../../injection.dart';
import '../../../clock/domain/entities/clock_config_entity.dart';
import '../../../clock/domain/entities/studio_design_entity.dart';
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
    // Without this the sheet is capped at 50% of the screen, which is
    // shorter than this layout's natural height - so the Apply CTA and
    // Cancel ended up only reachable by scrolling. The sheet still sizes
    // itself to its content (see `_ApplySheetState.build`'s own maxHeight);
    // this only lifts the framework's default ceiling out of the way.
    isScrollControlled: true,
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

class _ApplySheet extends StatefulWidget {
  const _ApplySheet({
    required this.wallpaper,
    this.clockConfig,
    this.depthConfig,
  });

  final WallpaperEntity wallpaper;
  final ClockConfigEntity? clockConfig;
  final DepthConfigEntity? depthConfig;

  @override
  State<_ApplySheet> createState() => _ApplySheetState();
}

class _ApplySheetState extends State<_ApplySheet> {
  /// Destination the user has picked but not yet confirmed. Home is
  /// pre-selected, matching the reference design's default state.
  ApplyDestination _selected = ApplyDestination.homeScreen;

  /// Whether to apply the dashboard-authored design along with the wallpaper.
  ///
  /// Only meaningful when [_offersDesignChoice]; the design is pre-selected,
  /// since it is what the content team authored and what the user saw on the
  /// details screen.
  bool _withDesign = true;

  WallpaperEntity get wallpaper => widget.wallpaper;

  /// Whether the dashboard asked the app to let the user choose.
  ///
  /// `applyTarget: "ask"` is the server-side signal for this (see
  /// `docs/DESIGN_RENDERING_CONTRACT.md`). The other two modes let the
  /// dashboard decide, so no selector is shown for them. A wallpaper with no
  /// authored design never shows one either - there is nothing to choose
  /// between, and the sheet stays exactly as it was.
  bool get _offersDesignChoice =>
      wallpaper.hasDesign &&
      wallpaper.design?.applyTarget == StudioApplyTarget.ask;

  /// Whether the authored design is deliberately being left OFF.
  ///
  /// Only ever true for a wallpaper that actually has an authored design: when
  /// the dashboard chose `wallpaperOnly`, or when it asked and the user picked
  /// "Wallpaper Only". A wallpaper with no parsed design is never affected -
  /// whatever config the caller passed is applied exactly as before.
  bool get _suppressDesign {
    if (!wallpaper.hasDesign) return false;
    return switch (wallpaper.design!.applyTarget) {
      StudioApplyTarget.withDesign => false,
      StudioApplyTarget.wallpaperOnly => true,
      StudioApplyTarget.ask => !_withDesign,
    };
  }

  /// The clock actually sent to the apply pipeline.
  ///
  /// Suppressed only for a deliberate "Wallpaper Only" apply, which is what
  /// makes that choice real rather than cosmetic: with no clock config,
  /// `isLiveApply` routes the wallpaper down the ordinary static path instead
  /// of the live engine. Every other case passes the caller's config through
  /// untouched.
  ClockConfigEntity? get clockConfig =>
      _suppressDesign ? null : widget.clockConfig;

  /// The studio widgets actually sent to the apply pipeline.
  ///
  /// Suppressed alongside the clock for a "Wallpaper Only" apply, so the ring
  /// disappears from the applied wallpaper exactly as the clock does.
  List<StudioWidget> get widgets =>
      _suppressDesign ? const [] : (wallpaper.design?.widgets ?? const []);

  /// The independently-positioned date element actually sent to apply.
  /// Suppressed alongside the clock and the widgets for "Wallpaper Only".
  StudioDateWidget? get dateWidget =>
      _suppressDesign ? null : wallpaper.design?.dateWidget;

  DepthConfigEntity? get depthConfig => widget.depthConfig;

  bool get _isLive =>
      wallpaper.isLiveApply(clockConfig: clockConfig, depthConfig: depthConfig);

  Future<void> _apply(
    BuildContext context,
    ApplyDestination destination,
  ) async {
    if (wallpaper.isPremium) {
      final unlocked = await _showRewardedGate(context);
      if (!unlocked || !context.mounted) return;
    }
    // The system wallpaper picker may open; returning from it must not
    // trigger an App Open.
    AdManager.instance.beginWallpaperApply();
    context.read<ApplyWallpaperBloc>().add(
      ApplyWallpaperRequested(
        wallpaper: wallpaper,
        destination: destination,
        clockConfig: clockConfig,
        depthConfig: depthConfig,
        widgets: widgets,
        dateWidget: dateWidget,
      ),
    );
  }

  /// Confirms with the user before showing a rewarded ad, then only
  /// unlocks Apply if it actually plays to completion.
  ///
  /// Never an inescapable loop: the dialog always offers Cancel, and a
  /// skipped/failed/unavailable ad simply returns to the sheet with nothing
  /// applied - the user can always back out.
  Future<bool> _showRewardedGate(BuildContext context) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.watchAdToApplyTitle),
        content: Text(l10n.watchAdToApplyBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.watchAd),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return false;

    if (!AdManager.instance.isRewardedReady) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.rewardedAdUnavailable)));
      return false;
    }
    return AdManager.instance.showRewardedAdForUnlock();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ApplyWallpaperBloc, ApplyWallpaperState>(
      listener: (context, state) {
        if (state is ApplyWallpaperSuccess) {
          Navigator.of(context).pop();
          if (state.isLive) {
            // For a live/depth wallpaper this only means "Android's system
            // picker was launched" - the picker is the user's real
            // confirmation, not this app, and it can take an unpredictable
            // amount of time (or the user may switch away entirely). Rather
            // than leaving the app sitting on Details/Customize underneath
            // waiting for an outcome that may never come back promptly,
            // return straight to Home now - `MainShell` reports what
            // actually happened via a toast once the app resumes and the
            // picker's result is known.
            context.go(RouteNames.explore);
          } else {
            context.push(RouteNames.success);
          }
        } else if (state is ApplyWallpaperError) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.message)));
        }
      },
      builder: (context, state) {
        final inProgress = state is ApplyWallpaperInProgress;
        // Laid out to match the supplied reference: handle, title + subtitle,
        // small portrait preview, a single row of three destination pills
        // (icon over label, selected = black), then one primary CTA and
        // Cancel. Sized from the viewport rather than fixed heights so it
        // fits small screens; SingleChildScrollView remains only as an
        // overflow fallback for extreme text scaling, not the normal path.
        final maxSheet = MediaQuery.sizeOf(context).height * 0.72;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxSheet),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const BottomSheetHandle(color: Color(0xFFDDDDDD)),
                  const SizedBox(height: 14),
                  Text(
                    context.l10n.setAsWallpaperTitle,
                    style: AppTextStyles.sectionTitle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.l10n.applyTo,
                    style: AppTextStyles.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: _PreviewThumbnail(
                      wallpaper: wallpaper,
                      // "Wallpaper Only" must be reflected in the preview
                      // the same way it changes what actually gets applied -
                      // see `_suppressDesign`'s own doc.
                      suppressDesign: _suppressDesign,
                      // Scales with the viewport instead of a single
                      // hardcoded size, so a short screen shrinks the
                      // preview rather than pushing the CTA off the sheet.
                      // ~155 on a typical phone, down to 96 on a very short
                      // screen; everything else on the sheet is fixed-height
                      // text/controls, so this is the one elastic element.
                      height: (maxSheet - 320).clamp(96.0, 180.0),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Shown only when the dashboard authored a design AND asked
                  // the app to let the user choose (`applyTarget: "ask"`).
                  // Every other wallpaper keeps the sheet exactly as it was.
                  if (_offersDesignChoice) ...[
                    _DesignChoice(
                      withDesign: _withDesign,
                      enabled: !inProgress,
                      onChanged: (value) => setState(() => _withDesign = value),
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (_isLive)
                    _PrimaryButton(
                      label: context.l10n.setAsLiveWallpaper,
                      busy: inProgress,
                      onTap: inProgress
                          ? null
                          : () => _apply(context, ApplyDestination.both),
                    )
                  else ...[
                    // IntrinsicHeight + stretch gives all three tiles one
                    // shared height regardless of whether a label wraps to a
                    // second line, so the row reads as a single band of
                    // controls rather than three differently-sized pills.
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _DestinationTile(
                              icon: Icons.smartphone_outlined,
                              label: context.l10n.homeScreen,
                              selected:
                                  _selected == ApplyDestination.homeScreen,
                              onTap: inProgress
                                  ? null
                                  : () => setState(
                                      () => _selected =
                                          ApplyDestination.homeScreen,
                                    ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _DestinationTile(
                              icon: Icons.lock_outline,
                              label: context.l10n.lockScreen,
                              selected:
                                  _selected == ApplyDestination.lockScreen,
                              onTap: inProgress
                                  ? null
                                  : () => setState(
                                      () => _selected =
                                          ApplyDestination.lockScreen,
                                    ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _DestinationTile(
                              icon: Icons.splitscreen_outlined,
                              label: context.l10n.bothScreens,
                              selected: _selected == ApplyDestination.both,
                              onTap: inProgress
                                  ? null
                                  : () => setState(
                                      () => _selected = ApplyDestination.both,
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _PrimaryButton(
                      label: context.l10n.applyWallpaper,
                      busy: inProgress,
                      onTap: inProgress
                          ? null
                          : () => _apply(context, _selected),
                    ),
                  ],
                  TextButton(
                    onPressed: inProgress
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: Text(context.l10n.cancel),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// One selectable destination: icon over label in a rounded tile, matching
/// the reference design. Selected reads as black-on-white; unselected as a
/// light outlined tile. Selection alone never applies anything - the primary
/// CTA below confirms, which is what keeps the premium/rewarded-ad gate in
/// one place.
class _DestinationTile extends StatelessWidget {
  const _DestinationTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AppColors.primary : AppColors.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected ? AppColors.surfaceVariant : Colors.transparent,
        borderRadius: AppShapes.card,
        child: InkWell(
          borderRadius: AppShapes.card,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
            decoration: BoxDecoration(
              borderRadius: AppShapes.card,
              border: Border.all(
                color: selected ? AppColors.primary : const Color(0xFFE2E2E2),
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 22, color: foreground),
                const SizedBox(height: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: selected ? AppColors.textPrimary : foreground,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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

/// The sheet's single confirming CTA - black pill, white label, and an
/// inline spinner while the apply is in flight so the sheet never changes
/// height mid-operation.
class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.onTap,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: onTap == null && !busy
          ? AppColors.primary.withValues(alpha: 0.5)
          : AppColors.primary,
      borderRadius: AppShapes.pill,
      child: InkWell(
        borderRadius: AppShapes.pill,
        onTap: onTap,
        child: Container(
          height: 54,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              : Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyLarge.copyWith(color: Colors.white),
                ),
        ),
      ),
    );
  }
}

/// Small phone-proportioned preview of the wallpaper being applied.
///
/// Renders the same composition Details would show for this wallpaper (via
/// [WallpaperPreviewComposition]) rather than the raw thumbnail - the user
/// should preview what will actually be applied, including a live design
/// where one is authored, not the unstyled original. See
/// [WallpaperPreviewComposition]'s own doc for why VIDEO uses its poster
/// frame here rather than actually playing.
class _PreviewThumbnail extends StatelessWidget {
  const _PreviewThumbnail({
    required this.wallpaper,
    required this.suppressDesign,
    this.height = 160,
  });

  final WallpaperEntity wallpaper;

  /// Mirrors `_ApplySheetState._suppressDesign` - true for a "Wallpaper
  /// Only" apply, so the preview shows exactly what that choice will
  /// actually produce.
  final bool suppressDesign;

  /// Preview height in logical pixels; width follows the 3:5 phone-ish
  /// proportion the reference design uses.
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: height * 0.6,
      height: height,
      child: WallpaperPreviewComposition(
        wallpaper: wallpaper,
        forceSuppressDesign: suppressDesign,
        borderRadius: AppShapes.card,
      ),
    );
  }
}

/// Compact two-option selector for "With Design" vs "Wallpaper Only".
///
/// Shown only when the dashboard authored a design and set
/// `studio.behavior.applyTarget` to `ask`. It is deliberately a segmented row
/// rather than a second screen - the brief's requirement is one extra choice
/// on the existing sheet, not a new step in the flow.
class _DesignChoice extends StatelessWidget {
  const _DesignChoice({
    required this.withDesign,
    required this.enabled,
    required this.onChanged,
  });

  final bool withDesign;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      children: [
        Expanded(
          child: _DesignChoiceTile(
            icon: Icons.auto_awesome,
            label: l10n.withDesign,
            selected: withDesign,
            onTap: enabled && !withDesign ? () => onChanged(true) : null,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _DesignChoiceTile(
            icon: Icons.image_outlined,
            label: l10n.wallpaperOnly,
            selected: !withDesign,
            onTap: enabled && withDesign ? () => onChanged(false) : null,
          ),
        ),
      ],
    );
  }
}

class _DesignChoiceTile extends StatelessWidget {
  const _DesignChoiceTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AppColors.primary : AppColors.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected ? AppColors.surfaceVariant : Colors.transparent,
        borderRadius: AppShapes.card,
        child: InkWell(
          borderRadius: AppShapes.card,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(
              borderRadius: AppShapes.card,
              border: Border.all(
                color: selected ? AppColors.primary : const Color(0xFFE2E2E2),
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: foreground),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: foreground,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
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
