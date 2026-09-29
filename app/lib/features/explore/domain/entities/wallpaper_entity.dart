import 'package:equatable/equatable.dart';

import '../../../clock/domain/entities/clock_config_entity.dart';
import '../../../clock/domain/entities/studio_design_entity.dart';
import '../../../depth/domain/entities/depth_config_entity.dart';
import 'category_entity.dart';
import 'wallpaper_assets.dart';
import 'wallpaper_type.dart';

/// What [WallpaperEntity.resolveDetailsVisual] decided Details should paint.
///
/// A plain value type rather than a bool pair scattered across call sites, so
/// "which asset" and "does the overlay still need to draw" are always
/// resolved together, in the one place that understands why - see that
/// method's own doc for the evidence behind each field.
class DetailsVisual extends Equatable {
  const DetailsVisual({
    required this.imageUrl,
    required this.sourceWidth,
    required this.sourceHeight,
    required this.containsBakedClockAndDate,
    required this.drawClockAndDate,
    required this.drawWidgets,
    this.useDepthLiveComposition = false,
    this.foregroundUrl,
  });

  /// True when Details must render the LIVE background -> design -> foreground
  /// stack (see `DepthLiveComposition`/`DepthLayerStack`) instead of painting
  /// a single flattened [imageUrl].
  ///
  /// Only ever true for a depth wallpaper that has everything required to
  /// reconstruct the design live: both raw layer plates AND a usable clock/
  /// date/widget config. A depth wallpaper's server composite is baked at
  /// publish time - `bunny`'s reads "10:12" forever, never the viewer's
  /// actual time - so Details must prefer reconstructing the design live
  /// from the same layers/config Apply already uses, exactly like every
  /// other type already does. [imageUrl] still resolves to the flattened
  /// composite in this case (used only as [backgroundFallbackColor]-style
  /// placeholder before the layers are ready, never as the final paint).
  final bool useDepthLiveComposition;

  /// The cut-out subject to composite ABOVE the live design when
  /// [useDepthLiveComposition] is true. Null otherwise.
  final String? foregroundUrl;

  /// The base image Details should paint - a `STYLED_PREVIEW` when the
  /// wallpaper has one, otherwise the same asset [WallpaperEntity
  /// .detailsPreviewUrl] would have chosen. When [useDepthLiveComposition] is
  /// true, this is the BACKGROUND plate, not a flattened composite.
  final String imageUrl;

  /// [imageUrl]'s OWN intrinsic pixel size, so the decoder is never told to
  /// decode a small asset at a larger asset's dimensions.
  ///
  /// This is not cosmetic: opened from a feed row (which carries no `assets`
  /// map at all) a depth wallpaper used to resolve [imageUrl] to the 360x640
  /// `THUMBNAIL` while still reporting the wallpaper's full 941x1672 as the
  /// decode target - a guaranteed 2.6x upscale of an already-small image,
  /// which is exactly the soft/wrong-looking Details reported for `bunny`.
  final int sourceWidth;
  final int sourceHeight;

  /// Whether [imageUrl] ALREADY has the clock and date burned into its
  /// pixels by the backend's compositor.
  ///
  /// Stated explicitly about the chosen asset rather than inferred from the
  /// wallpaper's type at the call site: the same wallpaper resolves to a
  /// baked composite (`PREVIEW`) or an unbaked plate (`BACKGROUND`) depending
  /// on what the payload actually carried, so "is it baked" is a property of
  /// the ASSET, not of the type.
  final bool containsBakedClockAndDate;

  /// Whether [DesignOverlay] must still draw the clock and the independent
  /// date widget on top of [imageUrl] - false when
  /// [containsBakedClockAndDate] is true, since drawing them again would
  /// double every glyph.
  final bool drawClockAndDate;

  /// Whether [DesignOverlay] must still draw studio widgets (`batteryRing`)
  /// on top of [imageUrl] - always true whenever a design exists, since a
  /// widget reading live device state can never be baked server-side.
  final bool drawWidgets;

  @override
  List<Object?> get props => [
    imageUrl,
    sourceWidth,
    sourceHeight,
    containsBakedClockAndDate,
    drawClockAndDate,
    drawWidgets,
    useDepthLiveComposition,
    foregroundUrl,
  ];
}

/// Core wallpaper domain model, shared across explore, search, view-all,
/// details and favorites.
///
/// One model represents all three content types; [type] says which, and the
/// type-specific payloads hang off it:
///
///  * [WallpaperType.normal] - [thumbnailUrl] + [fullUrl]
///  * [WallpaperType.depth]  - [backgroundUrl] + [foregroundUrl] +
///                             [remoteClockConfig] + [depthRenderConfig]
///  * [WallpaperType.live]   - [video]
///
/// List responses carry only the lightweight fields; the detail response fills
/// in [assets], [description] and the layer URLs. [isDetailed] says which of
/// the two you are holding, so callers never mistake a list row for a fully
/// loaded wallpaper.
class WallpaperEntity extends Equatable {
  const WallpaperEntity({
    required this.id,
    required this.title,
    required this.category,
    required this.thumbnailUrl,
    required this.fullUrl,
    required this.resolution,
    this.type = WallpaperType.normal,
    this.slug = '',
    this.description,
    this.isPremium = false,
    this.isFeatured = false,
    this.hasForegroundMask = false,
    this.foregroundMaskUrl,
    this.backgroundUrl,
    this.remoteClockConfig,
    this.design,
    this.depthRenderConfig,
    this.video,
    this.assets = const {},
    this.width = 0,
    this.height = 0,
    this.dominantColor,
    this.blurhash,
    this.downloadCount = 0,
    this.fileSizeBytes,
    this.tags = const [],
    this.createdAt,
    this.isDetailed = false,
  });

  final String id;

  /// Public slug. Either this or [id] can be used as `idOrSlug` on the detail,
  /// download, view and related endpoints.
  final String slug;

  final String title;

  /// Long-form copy. Only present on the detail response.
  final String? description;

  final CategoryEntity category;

  /// Which of the three content types this is. Derived from the backend's
  /// `type` field - never inferred from an id or a filename.
  final WallpaperType type;

  /// Small preview image used by every list and grid. Always prefer this over
  /// [fullUrl] when browsing.
  final String thumbnailUrl;

  /// Best full-resolution image known so far. On a list row this falls back to
  /// [thumbnailUrl]; the detail response upgrades it to the real asset.
  final String fullUrl;

  /// e.g. "2160x3840" (the backend's `resolutionLabel`).
  final String resolution;

  final int width;
  final int height;

  final bool isPremium;
  final bool isFeatured;

  /// Whether a cut-out foreground exists, enabling the depth effect. True for
  /// a depth wallpaper whose foreground layer has been resolved.
  final bool hasForegroundMask;

  /// The cut-out subject that renders *in front of* the clock.
  final String? foregroundMaskUrl;

  /// The plate that renders *behind* the clock. Null for non-depth wallpapers,
  /// where [fullUrl] is the whole image.
  final String? backgroundUrl;

  /// The clock configuration the content team authored for this wallpaper.
  /// Null when the wallpaper ships without a clock. The mobile app never
  /// edits this - it is the single source of truth for how the clock renders
  /// in Details and once applied.
  final ClockConfigEntity? remoteClockConfig;

  /// The full dashboard-authored design for this wallpaper: the clock plus any
  /// scene treatment, date element and widgets. Null when the wallpaper ships
  /// bare.
  ///
  /// [remoteClockConfig] is this design's clock, kept as its own field because
  /// every existing renderer and the apply pipeline already read it there.
  final StudioDesign? design;

  /// How the foreground layer is placed. Null falls back to
  /// [DepthRenderConfig.defaults].
  final DepthRenderConfig? depthRenderConfig;

  /// The looping video, for [WallpaperType.live].
  final VideoAsset? video;

  /// Every stored asset by kind (`ORIGINAL`, `BACKGROUND`, ...). Detail only.
  final Map<String, RemoteAsset> assets;

  /// Average color as an ARGB int, for an instant placeholder instead of grey.
  final int? dominantColor;

  /// BlurHash string, when the backend computed one.
  final String? blurhash;

  final int downloadCount;
  final int? fileSizeBytes;
  final List<String> tags;

  /// `publishedAt` from the API.
  final DateTime? createdAt;

  /// True when this came from the detail endpoint and therefore carries
  /// [assets], [description] and the resolved layer URLs.
  final bool isDetailed;

  /// True when the depth effect can actually be composited: the type says so
  /// and both layers resolved.
  bool get supportsDepth =>
      type == WallpaperType.depth &&
      (backgroundUrl?.isNotEmpty ?? false) &&
      (foregroundMaskUrl?.isNotEmpty ?? false);

  /// The image to paint behind the clock: the background plate for a depth
  /// wallpaper, otherwise the full image.
  String get compositeBackgroundUrl {
    final bg = backgroundUrl;
    if (bg != null && bg.isNotEmpty) return bg;
    return fullUrl;
  }

  /// The base image Apply should actually download and set for a
  /// **non-depth** wallpaper - `STYLED_PREVIEW` when a scene grade was
  /// baked into one, otherwise [fullUrl] unchanged.
  ///
  /// Without this, Apply always downloaded [fullUrl] (the raw, ungraded
  /// original/`PREVIEW`), so a wallpaper with an authored `studio.scene`
  /// grade (verified in production: `red-earth`, contrast +0.1, warmth
  /// +0.35) would show its graded look on Details - which already prefers
  /// `STYLED_PREVIEW`, see [resolveDetailsVisual] - and then silently
  /// revert to the flat original the moment it was actually applied. This
  /// closes that gap the same way [resolveDetailsVisual] closed it for
  /// Details: by consuming the backend's own server-rendered composite
  /// rather than building a second, independent Flutter/native colour-
  /// grading engine.
  ///
  /// Deliberately NOT used for depth: [compositeBackgroundUrl] must stay the
  /// raw background PLATE so the foreground subject can still be composited
  /// on top of it without doubling - `STYLED_PREVIEW` for a depth wallpaper
  /// is a flattened composite (background+subject+grade already merged) that
  /// cannot be decomposed back into separate layers. No production depth
  /// wallpaper carries a scene grade today (`bunny`'s `scene` is empty), so
  /// this gap has no live symptom yet, but it is a real, currently
  /// unsupported case - documented rather than hidden.
  String get applyBackgroundUrl {
    final styled = design?.styledPreviewUrl;
    if (styled != null && styled.isNotEmpty) return styled;
    return fullUrl;
  }

  /// Best asset for the full-screen Details *preview*.
  ///
  /// The original remains available through [fullUrl] for applying and
  /// downloading. Painting a 4K original on a phone screen wastes decode and
  /// GPU-upload work, so Details prefers the backend's bounded PREVIEW asset
  /// when one exists.
  ///
  /// Superseded by [resolveDetailsVisual] for the actual Details screen - this
  /// remains only as the plain "no design" fallback that resolver already
  /// falls back to, and for any other caller that just wants a bounded image
  /// without caring about the design overlay question.
  String get detailsPreviewUrl {
    final preview = assets[AssetKind.preview]?.url;
    if (preview != null && preview.isNotEmpty) return preview;
    return fullUrl;
  }

  int get detailsPreviewWidth => assets[AssetKind.preview]?.width ?? width;

  int get detailsPreviewHeight => assets[AssetKind.preview]?.height ?? height;

  /// The single, deterministic answer to "what should Details paint, and does
  /// it still need the live [DesignOverlay] on top?"
  ///
  /// Facts driving this, verified against real production payloads (see
  /// `docs/DESIGN_RENDERING_CONTRACT.md`), that must not be re-derived ad hoc
  /// elsewhere:
  ///
  ///  1. A DEPTH wallpaper with both layers AND a usable design is rendered
  ///     LIVE - background plate -> [DesignOverlay] -> foreground subject -
  ///     never from the server's flattened composite. That composite is
  ///     baked once at publish time (`bunny`'s reads "10:12" forever), so
  ///     painting it as "the design" would show a frozen clock/date/battery
  ///     that can never match the viewer's actual time - the reported bug.
  ///     Apply already reconstructs the wallpaper this same way (background
  ///     + live overlay + foreground, see `ApplyWallpaperRepositoryImpl` and
  ///     `DepthCompositor.kt`); this makes Details consume the identical
  ///     inputs instead of a separate, frozen artifact. See
  ///     [DetailsVisual.useDepthLiveComposition].
  ///  2. Every other case (no depth support, missing a layer, or no design at
  ///     all) falls back to painting ONE flattened asset, same as before:
  ///     `STYLED_PREVIEW`, when present, is always the most faithful static
  ///     asset - it is [detailsPreviewUrl]'s own base PLUS `studio.scene`'s
  ///     colour grade baked in by the backend's `STUDIO_RENDER` job.
  ///  3. Whether the CLOCK/DATE are also already baked into that flattened
  ///     asset depends on the type, not on whether `STYLED_PREVIEW`
  ///     specifically exists:
  ///     - A depth wallpaper that falls back to its composite (missing a
  ///       layer, or no design) has the clock and date burned in by the
  ///       legacy compositor this backend inherited - confirmed: `bunny`'s
  ///       PREVIEW contains "10"/"12" baked in.
  ///     - STANDARD's `STYLED_PREVIEW` bakes ONLY the scene grade - confirmed
  ///       directly against `red-earth-bd5vue` (`clock.enabled: true`,
  ///       `dateWidget.enabled: true`, has a `STYLED_PREVIEW`): the baked
  ///       image contains neither. So a STANDARD wallpaper's overlay must
  ///       keep drawing the clock/date regardless of which base asset is
  ///       chosen.
  ///     - LIVE plays the raw clip; nothing is ever baked into video frames.
  ///
  ///  A widget like `batteryRing` reads the *viewing device's* live battery -
  ///  a server-side render cannot know that value, so it is never baked into
  ///  any asset of any type. [DesignOverlay] always draws widgets when
  ///  [hasDesign] is true, independent of this resolver's `drawOverlay`.
  DetailsVisual resolveDetailsVisual() {
    // DEPTH LIVE COMPOSITION - checked first, and entirely bypasses the
    // flattened-asset selection below when it applies. Requires BOTH raw
    // layer plates (so the compositor has something real to stack - see
    // `DepthLiveComposition`'s background -> design -> foreground order) and
    // an authored design (there is nothing to render live otherwise) -
    // `supportsDepth` already requires both `backgroundUrl` and
    // `foregroundMaskUrl` to be non-empty. Deliberately NOT further gated on
    // `remoteClockConfig` being non-null: a depth wallpaper whose design is
    // dateWidget/widgets-only (no clock authored at all) must still render
    // live rather than falling back to a frozen composite - `DesignOverlay`
    // already tolerates a null/disabled clock inside `design`.
    if (supportsDepth && hasDesign) {
      return DetailsVisual(
        imageUrl: backgroundUrl!,
        // The background plate's own geometry - depth assets are always
        // published at matching background/foreground/composite dimensions,
        // so the wallpaper's own `width`/`height` (itself sourced from the
        // detail response) is the correct decode target here.
        sourceWidth: width,
        sourceHeight: height,
        containsBakedClockAndDate: false,
        drawClockAndDate: true,
        drawWidgets: design?.widgets.isNotEmpty ?? false,
        useDepthLiveComposition: true,
        foregroundUrl: foregroundMaskUrl,
      );
    }

    // Resolve the asset and its OWN dimensions together, so the decode target
    // always belongs to the image actually being painted.
    final styledAsset = assets[AssetKind.styledPreview];
    final styledUrl = design?.styledPreviewUrl;
    final previewAsset = assets[AssetKind.preview];

    final String url;
    final int? assetWidth;
    final int? assetHeight;
    if (styledUrl != null && styledUrl.isNotEmpty) {
      url = styledUrl;
      // The URL may come from `studio.styledPreviewUrl` while the sizes live
      // in the `assets` map; only trust those sizes when they describe this
      // very URL.
      final matches = styledAsset != null && styledAsset.url == styledUrl;
      assetWidth = matches ? styledAsset.width : null;
      assetHeight = matches ? styledAsset.height : null;
    } else if (previewAsset != null && previewAsset.url.isNotEmpty) {
      url = previewAsset.url;
      assetWidth = previewAsset.width;
      assetHeight = previewAsset.height;
    } else {
      // No `assets` map at all - the case a FEED row always hits, since a
      // list row carries none. `fullUrl` is then the thumbnail (see
      // `WallpaperModel.fromApiFeedItem`, which deliberately avoids putting a
      // multi-megabyte URL on a list row), so the decode target must be the
      // THUMBNAIL's size, never the wallpaper's full resolution.
      url = fullUrl;
      final thumb = assets[AssetKind.thumbnail];
      final isThumbnail = url == thumbnailUrl;
      assetWidth = isThumbnail ? thumb?.width : null;
      assetHeight = isThumbnail ? thumb?.height : null;
    }

    // DEPTH's server-side composite (`PREVIEW`, and the `THUMBNAIL` cut from
    // it, and any `STYLED_PREVIEW` built on top of it) has the clock and date
    // burned into its pixels by the legacy compositor this backend inherited
    // - verified directly against `bunny`'s own `preview.webp`, which
    // contains "10"/"12" and "10 NOV 2025". The RAW layer plates
    // (`BACKGROUND`/`FOREGROUND`) never do; `bunny`'s BACKGROUND is a 2.8 kB
    // pure-black plate.
    //
    // This branch is reached precisely when live composition did NOT apply,
    // which includes a depth wallpaper missing one layer (`supportsDepth ==
    // false` in that exact case) - that wallpaper still went through the
    // backend's depth pipeline and its composite is still baked, so
    // `containsBaked` must stay true there. Gating on `type == depth` alone
    // would go too far, though: a depth-typed wallpaper with NEITHER layer
    // published at all (no evidence real depth authoring ever happened) has
    // no basis to assume its `fullUrl` fallback is a baked composite either -
    // treating it as baked risks a permanently missing clock if it turns out
    // not to be, which is exactly the failure mode this whole resolver
    // exists to prevent. `hasAnyDepthLayer` is that evidence: at least one of
    // the two layer URLs was actually published for this wallpaper.
    final hasAnyDepthLayer =
        (backgroundUrl?.isNotEmpty ?? false) ||
        (foregroundMaskUrl?.isNotEmpty ?? false);
    final resolvedIsComposite =
        url != backgroundUrl && url != foregroundMaskUrl;
    final containsBaked = hasDesign &&
        type == WallpaperType.depth &&
        hasAnyDepthLayer &&
        resolvedIsComposite;

    return DetailsVisual(
      imageUrl: url,
      // Fall back to the wallpaper's own resolution only when the asset did
      // not declare its own - never the other way round.
      sourceWidth: assetWidth ?? width,
      sourceHeight: assetHeight ?? height,
      containsBakedClockAndDate: containsBaked,
      drawClockAndDate: hasDesign && !containsBaked,
      // Widgets (batteryRing) are never baked by the backend for any type,
      // so they draw whenever any are actually authored - not merely
      // whenever *some* design exists, or a depth wallpaper with a baked
      // clock but zero widgets would wrongly report something left to draw.
      drawWidgets: hasDesign && (design?.widgets.isNotEmpty ?? false),
    );
  }

  /// Whether this build can render and apply this wallpaper at all.
  bool get isRenderable => type.isSupported;

  /// Whether applying this wallpaper (with the given chosen configs) only
  /// launches Android's system live-wallpaper picker rather than completing
  /// synchronously via `WallpaperManager.setBitmap`.
  ///
  /// True for: a video wallpaper (always applied through the picker, even
  /// though it carries neither config below); a clock config being applied
  /// at all; or an enabled depth effect. The picker is a fire-and-forget
  /// intent launch, not a synchronous result - callers use this to decide
  /// whether the app's own success screen would double up with the system
  /// picker's own confirmation.
  ///
  /// The single source of truth for that distinction: it used to be
  /// duplicated between the apply sheet (which button set to show) and
  /// `ApplyWallpaperBloc` (whether to skip the app's Done screen), kept in
  /// sync only by a comment - a video wallpaper apply fell through both of
  /// them, since it carries neither config, until this was unified here.
  bool isLiveApply({
    ClockConfigEntity? clockConfig,
    DepthConfigEntity? depthConfig,
  }) =>
      type == WallpaperType.live ||
      clockConfig != null ||
      (depthConfig?.enabled ?? false);

  /// Whether the dashboard authored a design for this wallpaper.
  ///
  /// THE single canonical answer - no screen re-derives it. A wallpaper has a
  /// design when its parsed configuration carries meaningful authored content:
  /// an enabled clock, a scene that would visibly change the image, an enabled
  /// date element, or at least one supported widget.
  ///
  /// Deliberately independent of [type]: STATIC / LIVE / DEPTH describe the
  /// media and how it is rendered, not whether something was designed on top
  /// of it. A static wallpaper can carry a full design; a depth wallpaper can
  /// carry none.
  bool get hasDesign => design?.hasDesign ?? false;

  /// How this wallpaper's design must be rendered to stay faithful to it.
  ///
  /// [DesignRenderMode.none] when nothing was authored, [static_] when every
  /// authored element is fixed (so it can be composed once into a bitmap), and
  /// [dynamic_] when at least one element changes at runtime.
  DesignRenderMode get designRenderMode =>
      design?.renderMode ?? DesignRenderMode.none;

  /// Whether the authored design needs a live wallpaper engine to stay
  /// truthful - a ticking clock or a battery ring cannot be baked into a
  /// bitmap, a colour grade can.
  bool get hasDynamicDesign => designRenderMode == DesignRenderMode.dynamic_;

  /// Whether the authored design is entirely fixed, so it can be composed once
  /// and applied through the ordinary static wallpaper path.
  bool get hasStaticOnlyDesign => designRenderMode == DesignRenderMode.static_;

  /// Whether the image Details paints ALREADY has the clock/date rendered
  /// into it by the backend.
  ///
  /// Deprecated in favour of [resolveDetailsVisual], which additionally knows
  /// WHICH asset is baked (`STYLED_PREVIEW` vs the plain composite) and
  /// whether widgets need drawing too - kept only so any external reference
  /// to this specific fact still resolves, via the same single resolver
  /// rather than a second, independently-maintained rule.
  ///
  /// Gated on [hasDesign] because [DetailsVisual.drawClockAndDate] is also
  /// `false` when there is nothing authored at all - a fact this getter must
  /// not conflate with "baked", since nothing baked ran for a wallpaper with
  /// no design in the first place.
  bool get previewHasBakedDesign =>
      hasDesign && !resolveDetailsVisual().drawClockAndDate;

  /// Deprecated in favour of [resolveDetailsVisual].`drawClockAndDate ||
  /// drawWidgets` (combined with [hasDesign] the way Details itself checks
  /// it) - kept only for source compatibility.
  bool get shouldRenderDesignOverlay {
    if (!hasDesign) return false;
    final visual = resolveDetailsVisual();
    return visual.drawClockAndDate || visual.drawWidgets;
  }

  WallpaperEntity copyWith({
    String? id,
    String? slug,
    String? title,
    String? description,
    CategoryEntity? category,
    WallpaperType? type,
    String? thumbnailUrl,
    String? fullUrl,
    String? resolution,
    int? width,
    int? height,
    bool? isPremium,
    bool? isFeatured,
    bool? hasForegroundMask,
    String? foregroundMaskUrl,
    String? backgroundUrl,
    ClockConfigEntity? remoteClockConfig,
    StudioDesign? design,
    DepthRenderConfig? depthRenderConfig,
    VideoAsset? video,
    Map<String, RemoteAsset>? assets,
    int? dominantColor,
    String? blurhash,
    int? downloadCount,
    int? fileSizeBytes,
    List<String>? tags,
    DateTime? createdAt,
    bool? isDetailed,
  }) {
    return WallpaperEntity(
      id: id ?? this.id,
      slug: slug ?? this.slug,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      type: type ?? this.type,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      fullUrl: fullUrl ?? this.fullUrl,
      resolution: resolution ?? this.resolution,
      width: width ?? this.width,
      height: height ?? this.height,
      isPremium: isPremium ?? this.isPremium,
      isFeatured: isFeatured ?? this.isFeatured,
      hasForegroundMask: hasForegroundMask ?? this.hasForegroundMask,
      foregroundMaskUrl: foregroundMaskUrl ?? this.foregroundMaskUrl,
      backgroundUrl: backgroundUrl ?? this.backgroundUrl,
      remoteClockConfig: remoteClockConfig ?? this.remoteClockConfig,
      design: design ?? this.design,
      depthRenderConfig: depthRenderConfig ?? this.depthRenderConfig,
      video: video ?? this.video,
      assets: assets ?? this.assets,
      dominantColor: dominantColor ?? this.dominantColor,
      blurhash: blurhash ?? this.blurhash,
      downloadCount: downloadCount ?? this.downloadCount,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      isDetailed: isDetailed ?? this.isDetailed,
    );
  }

  @override
  List<Object?> get props => [
    id,
    slug,
    title,
    description,
    category,
    type,
    thumbnailUrl,
    fullUrl,
    resolution,
    width,
    height,
    isPremium,
    isFeatured,
    hasForegroundMask,
    foregroundMaskUrl,
    backgroundUrl,
    remoteClockConfig,
    design,
    depthRenderConfig,
    video,
    assets,
    dominantColor,
    blurhash,
    downloadCount,
    fileSizeBytes,
    tags,
    createdAt,
    isDetailed,
  ];
}
