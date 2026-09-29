import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/live_preview_playback_gate.dart';
import '../../../../core/widgets/live_wallpaper_player.dart';
import '../../../../core/widgets/frosted_icon_button.dart';
import '../../../../core/widgets/wallpaper_type_badge.dart';
import '../../../../injection.dart';
import '../../../apply_wallpaper/presentation/pages/apply_wallpaper_page.dart';
import '../../../clock/presentation/widgets/design_overlay.dart';
import '../../../../core/widgets/wallpaper_preview_composition.dart';
import '../../../depth/domain/entities/depth_config_entity.dart';
import '../../../explore/domain/entities/wallpaper_entity.dart';
import '../../../explore/domain/entities/wallpaper_type.dart';
import '../bloc/wallpaper_details_bloc.dart';
import '../widgets/wallpaper_info_panel.dart';

class WallpaperDetailsPage extends StatelessWidget {
  const WallpaperDetailsPage({
    super.key,
    required this.id,
    this.knownWallpaper,
  });

  final String id;

  /// The list row the caller already has, when available - lets the screen
  /// paint instantly instead of a loading spinner. See
  /// `WallpaperDetailsFetchRequested.knownWallpaper`.
  final WallpaperEntity? knownWallpaper;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<WallpaperDetailsBloc>()
        ..add(
          WallpaperDetailsFetchRequested(id, knownWallpaper: knownWallpaper),
        ),
      child: _DetailsView(id: id),
    );
  }
}

class _DetailsView extends StatefulWidget {
  const _DetailsView({required this.id});

  final String id;

  @override
  State<_DetailsView> createState() => _DetailsViewState();
}

class _DetailsViewState extends State<_DetailsView> {
  /// Resolves once this route's own push transition has finished, so the
  /// live wallpaper's decoder never starts configuring while the transition
  /// animation is still driving the fade/scale - that contention is what
  /// measured as ~17% jank opening a live wallpaper's Details screen. The
  /// poster/thumbnail is shown throughout regardless (see
  /// `LiveWallpaperPlayer`'s always-painted poster layer), so there is no
  /// blank frame while this is pending.
  final Completer<void> _transitionSettled = Completer<void>();
  Animation<double>? _routeAnimation;

  /// Owns this screen's Play/Pause control. Independent of Explore's shared
  /// gate - pausing the video the user is directly looking at here must never
  /// pause every other live preview elsewhere in the app.
  final LivePreviewPlaybackGate _playbackGate = LivePreviewPlaybackGate();

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animation = ModalRoute.of(context)?.animation;
    if (animation == null) {
      // No transition to wait for (e.g. this route was not pushed with one) -
      // let the decoder start immediately rather than waiting forever.
      if (!_transitionSettled.isCompleted) _transitionSettled.complete();
      return;
    }
    if (_routeAnimation != animation) {
      _routeAnimation?.removeStatusListener(_onRouteAnimationStatus);
      _routeAnimation = animation;
      animation.addStatusListener(_onRouteAnimationStatus);
      _onRouteAnimationStatus(animation.status);
    }
  }

  void _onRouteAnimationStatus(AnimationStatus status) {
    // `completed` covers the normal forward push; a route can also already be
    // `completed` by the time this listener attaches (transition finished
    // between frames), which the immediate check in `didChangeDependencies`
    // above handles too.
    if (status == AnimationStatus.completed &&
        !_transitionSettled.isCompleted) {
      _transitionSettled.complete();
    }
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_onRouteAnimationStatus);
    _playbackGate.dispose();
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  /// Opens the Apply sheet with the wallpaper's own Dashboard-authored
  /// clock/depth configuration - the mobile app never edits either, so there
  /// is nothing else to pass. Depth is enabled whenever the wallpaper both
  /// supports it and actually resolved both layers (`supportsDepth`); a depth
  /// wallpaper without that flag falls back to applying its flattened image.
  void _apply(BuildContext context, WallpaperEntity wallpaper) {
    showApplyWallpaperSheet(
      context,
      wallpaper: wallpaper,
      clockConfig: wallpaper.remoteClockConfig,
      depthConfig: wallpaper.supportsDepth
          ? DepthConfigEntity(
              wallpaperId: wallpaper.id,
              enabled: true,
              hasForegroundMask: true,
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: BlocBuilder<WallpaperDetailsBloc, WallpaperDetailsState>(
          builder: (context, state) {
            return switch (state) {
              WallpaperDetailsLoading() => const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
              WallpaperDetailsError(:final message) => ErrorView(
                message: message,
                onRetry: () => context.read<WallpaperDetailsBloc>().add(
                  WallpaperDetailsFetchRequested(widget.id),
                ),
              ),
              WallpaperDetailsLoaded(:final wallpaper, :final isFavorite) =>
                _buildLoaded(context, wallpaper, isFavorite),
            };
          },
        ),
      ),
    );
  }

  /// Split out of the `switch` arm so [WallpaperEntity.resolveDetailsVisual]
  /// is resolved exactly once per build rather than once per reference.
  Widget _buildLoaded(
    BuildContext context,
    WallpaperEntity wallpaper,
    bool isFavorite,
  ) {
    final visual = wallpaper.resolveDetailsVisual();
    return Stack(
      fit: StackFit.expand,
      children: [
        // Full-bleed media (behind system bars).
        //
        // A live wallpaper plays its looping clip here so Details
        // shows what will actually be set, not a frozen frame.
        // Everything else is the still image.
        //
        // No Hero: the flight lifted this image out of the tree
        // and left the black Scaffold showing. Instead the
        // already-cached thumbnail paints immediately (zero fade)
        // and the full-resolution image cross-fades in over it, so
        // there is never an empty frame.
        if (wallpaper.type == WallpaperType.live &&
            (wallpaper.video?.url.isNotEmpty ?? false))
          LayoutBuilder(
            builder: (context, constraints) {
              final size = _boundedPhysicalSize(
                context,
                constraints.biggest,
                sourceWidth: wallpaper.width,
                sourceHeight: wallpaper.height,
              );
              return LiveWallpaperPlayer(
                videoUrl: wallpaper.video!.url,
                posterUrl: wallpaper.thumbnailUrl,
                placeholderColor: wallpaper.dominantColor == null
                    ? null
                    : Color(wallpaper.dominantColor!),
                posterCacheWidth: size.$1,
                posterCacheHeight: size.$2,
                // The full-screen clip takes the single global
                // decoder slot from any covered feed preview.
                priority: true,
                // Poster-first: don't let decoder configure()
                // compete with this route's own push transition.
                deferUntil: _transitionSettled.future,
                // This screen's own Play/Pause control, distinct
                // from Explore's shared feed-wide gate.
                playbackGate: _playbackGate,
              );
            },
          )
        else if (visual.useDepthLiveComposition)
          // LIVE depth composition: background -> design -> foreground,
          // reconstructed from the same layers/config Apply uses. Shared
          // with the Apply sheet's own preview via
          // `WallpaperPreviewComposition`, so there is exactly one
          // background->design->foreground implementation for both screens -
          // its own `Center`+`AspectRatio`-locked box (with its own
          // letterbox fill) reproduces the SAME letterboxing
          // `_TwoStageWallpaperImage`'s `BoxFit.contain` would have given
          // the flattened composite.
          Positioned.fill(
            key: ValueKey('details_depth_live_${wallpaper.id}'),
            child: WallpaperPreviewComposition(wallpaper: wallpaper),
          )
        else
          _TwoStageWallpaperImage(
            key: ValueKey('details_image_${wallpaper.id}_${visual.imageUrl}'),
            thumbnailUrl: wallpaper.thumbnailUrl,
            previewUrl: visual.imageUrl,
            // The chosen asset's OWN size - never the wallpaper's full
            // resolution when the asset that resolved is a smaller one.
            sourceWidth: visual.sourceWidth,
            sourceHeight: visual.sourceHeight,
            placeholderColor: wallpaper.dominantColor == null
                ? const Color(0xFF15151A)
                : Color(wallpaper.dominantColor!),
          ),
        // The dashboard-authored design, composed over the media.
        //
        // Renders the SAME `StudioDesign` that the apply pipeline
        // ultimately serializes to the native renderers, so what
        // Details shows is what gets applied - for every media
        // type, not just depth. Painted above the wallpaper but
        // below the UI chrome below, and non-interactive, so it
        // never intercepts a tap meant for a button.
        //
        // `resolveDetailsVisual` decides not just WHICH image but
        // whether that image already has the clock/date baked in
        // - drawing them again on top of a DEPTH composite that
        // already contains them is the exact doubling this
        // resolver exists to prevent.
        //
        // NEVER drawn here when `useDepthLiveComposition` is true:
        // `_DepthLiveViewport`/`DepthLiveComposition` already draws the
        // design INSIDE its own stack, correctly sandwiched BELOW the
        // foreground subject - drawing it again here, above everything
        // including the foreground, would both duplicate it and undo the
        // occlusion the whole point of this composition is to preserve.
        if (!visual.useDepthLiveComposition &&
            wallpaper.hasDesign &&
            (visual.drawClockAndDate || visual.drawWidgets))
          Positioned.fill(
            child: DesignOverlay(
              design: wallpaper.design!,
              // Details is full-bleed, so authored logical pixels
              // map 1:1 onto this surface - the same relationship
              // the applied wallpaper has with the real screen.
              displayScale: 1.0,
              drawClockAndDate: visual.drawClockAndDate,
              drawWidgets: visual.drawWidgets,
            ),
          ),
        // The clip's actual running time, e.g. "0:10" - only
        // known now that the full detail has loaded (the list
        // feed never carries `video.durationMs`, so a Home card
        // shows generic "LIVE" instead; this is the one place
        // that data is actually available to show).
        if (wallpaper.type == WallpaperType.live &&
            (wallpaper.video?.durationMs ?? 0) > 0)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Align(
                alignment: AlignmentDirectional.topStart,
                child: WallpaperTypeBadge(
                  type: wallpaper.type,
                  durationMs: wallpaper.video!.durationMs,
                ),
              ),
            ),
          ),
        // Top action bar — pinned to the very top safe area.
        SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  FrostedIconButton(
                    icon: Icons.arrow_back_ios_new,
                    semanticLabel: 'Back',
                    onPressed: () => context.pop(),
                  ),
                  const Spacer(),
                  _AnimatedHeart(
                    isFavorite: isFavorite,
                    onTap: () => context.read<WallpaperDetailsBloc>().add(
                      const WallpaperFavoriteToggleRequested(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FrostedIconButton(
                    icon: Icons.ios_share,
                    semanticLabel: 'Share',
                    onPressed: () => context.read<WallpaperDetailsBloc>().add(
                      const WallpaperShareRequested(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Bottom info panel.
        Align(
          alignment: Alignment.bottomCenter,
          child: wallpaper.type == WallpaperType.live
              ? ValueListenableBuilder<bool>(
                  valueListenable: _playbackGate,
                  builder: (context, isPlaying, _) => WallpaperInfoPanel(
                    wallpaper: wallpaper,
                    isPlaying: isPlaying,
                    onPlayPauseToggle: () => isPlaying
                        ? _playbackGate.pause()
                        : _playbackGate.resume(),
                    onApply: () => _apply(context, wallpaper),
                  ),
                )
              : WallpaperInfoPanel(
                  wallpaper: wallpaper,
                  onApply: () => _apply(context, wallpaper),
                ),
        ),
      ],
    );
  }

}

/// A stable thumbnail followed by exactly one decoded preview replacement.
///
/// The detail BLoC deliberately emits twice (known feed row, then API detail).
/// A nested `CachedNetworkImage(full, placeholder: thumbnail)` rebuilt for
/// both emissions used to expose the feed-sized bitmap, a newly decoded
/// intrinsic thumbnail, and finally the original. This widget retains its
/// first thumbnail and does not reveal the preview until precaching confirms
/// that the final frame is decoded and ready to paint.
///
/// Both layers render with `BoxFit.cover`, matching the native applied
/// wallpaper's own geometry (`DepthCompositor.drawCoverBitmap`, used by both
/// the live-wallpaper engine and the static apply path): Details must show
/// what the wallpaper will actually look like once applied, and on a source
/// aspect ratio narrower/wider than the device viewport, `BoxFit.contain`
/// used to letterbox in `[placeholderColor]` - a visibly different, and on a
/// dark placeholder colour indistinguishable-from-black, composition than
/// what "With Design" or "Wallpaper Only" ever produced once applied. Cover
/// crops some edge content on a mismatched ratio rather than leaving a gap -
/// the same trade-off already made for every native render path.
/// `[placeholderColor]` still fills the full viewport underneath both
/// layers, purely as the decode-in-progress placeholder, not as a letterbox
/// fill. `DesignOverlay` (drawn separately, above this widget) is unaffected:
/// it positions the clock/date/widgets as fractions of the full Details
/// viewport, independent of this image's own fit/crop.
class _TwoStageWallpaperImage extends StatefulWidget {
  const _TwoStageWallpaperImage({
    super.key,
    required this.thumbnailUrl,
    required this.previewUrl,
    required this.placeholderColor,
    required this.sourceWidth,
    required this.sourceHeight,
  });

  final String thumbnailUrl;
  final String previewUrl;
  final Color placeholderColor;
  final int sourceWidth;
  final int sourceHeight;

  @override
  State<_TwoStageWallpaperImage> createState() =>
      _TwoStageWallpaperImageState();
}

class _TwoStageWallpaperImageState extends State<_TwoStageWallpaperImage> {
  late String _stableThumbnailUrl;
  CachedNetworkImageProvider? _readyPreview;
  String? _scheduledKey;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _stableThumbnailUrl = widget.thumbnailUrl;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _schedulePreviewLoad();
  }

  @override
  void didUpdateWidget(covariant _TwoStageWallpaperImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_stableThumbnailUrl.isEmpty && widget.thumbnailUrl.isNotEmpty) {
      _stableThumbnailUrl = widget.thumbnailUrl;
    }
    if (oldWidget.previewUrl != widget.previewUrl) {
      _schedulePreviewLoad();
    }
  }

  void _schedulePreviewLoad() {
    final url = widget.previewUrl;
    if (url.isEmpty || url == _stableThumbnailUrl) return;

    final screenSize = MediaQuery.sizeOf(context);
    final target = _boundedPhysicalSize(
      context,
      screenSize,
      sourceWidth: widget.sourceWidth,
      sourceHeight: widget.sourceHeight,
    );
    final key = '$url@${target.$1}x${target.$2}';
    if (_scheduledKey == key) return;
    _scheduledKey = key;
    final generation = ++_loadGeneration;
    final provider = CachedNetworkImageProvider(
      url,
      maxWidth: target.$1,
      maxHeight: target.$2,
    );

    // Keep the route transition free of image decode/upload work. After it
    // has settled, decode the final screen-sized preview off the visible
    // image path; only a completed provider is allowed into the widget tree.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 240), () async {
          if (!mounted || generation != _loadGeneration) return;
          try {
            await precacheImage(provider, context);
          } catch (_) {
            return;
          }
          if (!mounted || generation != _loadGeneration) return;
          setState(() => _readyPreview = provider);
        }),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final target = _boundedPhysicalSize(
      context,
      MediaQuery.sizeOf(context),
      sourceWidth: widget.sourceWidth,
      sourceHeight: widget.sourceHeight,
    );
    final preview = _readyPreview;
    return Stack(
      fit: StackFit.expand,
      children: [
        // The placeholder colour fills the full viewport FIRST - it is what
        // shows through as letterbox bars once the image itself switches to
        // BoxFit.contain below, on any wallpaper whose aspect ratio does not
        // exactly match this device's screen.
        ColoredBox(color: widget.placeholderColor),
        if (_stableThumbnailUrl.isNotEmpty)
          CachedNetworkImage(
            imageUrl: _stableThumbnailUrl,
            // BoxFit.cover - see this file's module doc: Details must match
            // the native applied wallpaper's own COVER geometry, not
            // letterbox.
            fit: BoxFit.cover,
            memCacheWidth: target.$1,
            memCacheHeight: target.$2,
            fadeInDuration: Duration.zero,
            fadeOutDuration: Duration.zero,
            placeholderFadeInDuration: Duration.zero,
            placeholder: (context, url) => const SizedBox.shrink(),
            errorWidget: (context, url, error) => const SizedBox.shrink(),
          ),
        if (preview != null)
          Positioned.fill(
            child: TweenAnimationBuilder<double>(
              key: ValueKey(preview),
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 180),
              builder: (context, opacity, child) =>
                  Opacity(opacity: opacity, child: child),
              child: Image(
                image: preview,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.low,
                gaplessPlayback: true,
              ),
            ),
          ),
      ],
    );
  }
}

/// Physical decode ceiling for full-screen previews on low-end devices.
/// 1440x2880 is above the tested phone's 1080x2340 display while avoiding a
/// multi-thousand-pixel original allocation. Expands whichever dimension the
/// source's own aspect ratio needs, so the decode never undersamples the
/// axis `BoxFit.cover` will crop most tightly, and the modest 5% margin
/// prevents undersampling at the edges.
(int, int) _boundedPhysicalSize(
  BuildContext context,
  Size logicalSize, {
  int sourceWidth = 0,
  int sourceHeight = 0,
}) {
  final dpr = MediaQuery.devicePixelRatioOf(context);
  var width = (logicalSize.width * dpr * 1.05).ceil().clamp(1, 1440).toInt();
  var height = (logicalSize.height * dpr * 1.05).ceil().clamp(1, 2880).toInt();
  if (sourceWidth > 0 && sourceHeight > 0) {
    final sourceAspect = sourceWidth / sourceHeight;
    final boxAspect = width / height;
    if (sourceAspect > boxAspect) {
      width = (height * sourceAspect).ceil();
    } else {
      height = (width / sourceAspect).ceil();
    }
    final scale = [
      1.0,
      1440 / width,
      2880 / height,
    ].reduce((a, b) => a < b ? a : b);
    width = (width * scale).round().clamp(1, 1440);
    height = (height * scale).round().clamp(1, 2880);
  }
  return (width, height);
}

/// Heart button with a spring scale bounce + fill cross-fade on toggle.
class _AnimatedHeart extends StatelessWidget {
  const _AnimatedHeart({required this.isFavorite, required this.onTap});

  final bool isFavorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: isFavorite ? 'Remove from favorites' : 'Add to favorites',
      child: FrostedIconButton(
        icon: isFavorite ? Icons.favorite : Icons.favorite_border,
        iconColor: isFavorite ? const Color(0xFFFF4D6D) : Colors.white,
        onPressed: onTap,
      ),
    );
  }
}
