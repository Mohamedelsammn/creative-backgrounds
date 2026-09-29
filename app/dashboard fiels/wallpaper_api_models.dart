// wallpaper_api_models.dart
//
// Every setting the Creative Backgrounds API sends the app, as typed Dart models, in one file.
// Generated from docs/openapi.json on 2026-09-27. Pure Dart: no Flutter import and no package,
// so it drops into any layer of the app. Colours are returned as ARGB ints; wrap them in
// `Color(value)` where you draw.
//
// Every parser is forgiving: an absent or malformed field falls back to the default the
// dashboard itself uses, numbers are clamped to the documented range, and an unknown enum value
// falls back to the default rather than throwing. An older or newer backend never crashes the app.
//
// ENDPOINTS (base: /api/v1/public)
//
//   GET  /wallpapers              -> FeedPage.fromJson           (cursor paged: ?cursor=&limit=)
//   GET  /wallpapers/{idOrSlug}   -> WallpaperDetail.fromJson
//   GET  /wallpapers/{id}/related -> ListResponse.fromJson(json, WallpaperCard.fromJson)
//   GET  /search?q=               -> ListResponse.fromJson(json, WallpaperCard.fromJson)
//   POST /wallpapers/{id}/download-> DownloadResponse.fromJson
//   POST /wallpapers/{id}/view    -> no body
//   GET  /categories              -> ListResponse.fromJson(json, PublicCategory.fromJson)
//   GET  /config                  -> PublicConfig.fromJson       (fetch once at start)
//
// HOW TO DRAW A WALLPAPER (docs/MOBILE_APP_CONTRACT.md has the long version)
//
// Grid tile:
//   if (card.thumbnailIncludesLook) -> show card.thumbnailUrl as it is. The clock, date, extras
//                                      and photo filter are already in the picture. Draw nothing
//                                      over it, or the tile shows two clocks.
//   else                            -> show card.thumbnailUrl and draw card.look over it.
//
// Full screen and the applied wallpaper (always live, never the thumbnail):
//   DEPTH:            background -> clock (card.clockToDraw) -> foreground, with card.depthConfig
//                     for the foreground's scale/offset/blur/shadow/parallax. clock.depth is how
//                     much of the clock the subject hides (0 fully behind, 1 fully in front).
//   STANDARD / VIDEO: the picture (or the loop) -> studio.scene grade -> studio.clock,
//                     studio.dateWidget, studio.widgets on top.
//   Any type: studio.scene is the colour grade, or use studio.styledPreviewUrl when it is not
//   null, which is the same grade already baked into a still.
//
// Fonts: load every PublicConfig.studio.fonts entry (by family) before drawing a clock that
// names it; a family with no file is one the app bundles.
//
// Positions: customX / customY are 0..1 of the PHONE SCREEN (9:20), measured from the top left,
// and place the centre of the piece. `position`/`anchor` is used when they are null.

// ---------------------------------------------------------------------------------------------
// Pages and small responses
// ---------------------------------------------------------------------------------------------

class FeedPage {
  final List<WallpaperCard> items;
  final String? nextCursor;
  final bool hasMore;

  const FeedPage({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
  });

  factory FeedPage.fromJson(Map<String, dynamic> json) {
    final meta = _map(json['meta']);
    return FeedPage(
      items: _list(json['data'])
          .map((e) => WallpaperCard.fromJson(_map(e)))
          .toList(),
      nextCursor: _strOrNull(meta['nextCursor']),
      hasMore: _bool(meta['hasMore'], false),
    );
  }
}

/// `{ "data": [...] }`, the shape of related, search and categories.
class ListResponse<T> {
  final List<T> items;
  const ListResponse(this.items);

  factory ListResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) item,
  ) => ListResponse(_list(json['data']).map((e) => item(_map(e))).toList());
}

class DownloadResponse {
  final String downloadUrl;
  final int expiresInSeconds;
  const DownloadResponse({
    required this.downloadUrl,
    required this.expiresInSeconds,
  });

  factory DownloadResponse.fromJson(Map<String, dynamic> json) =>
      DownloadResponse(
        downloadUrl: _str(json['downloadUrl'], ''),
        expiresInSeconds: _int(json['expiresInSeconds'], 300),
      );
}

class PublicCategory {
  final String id;
  final String slug;
  final String nameEn;
  final String? nameAr;
  final String? iconUrl;

  /// The category's own picture. Prefer it over [coverThumbnailUrl] on a browse tile.
  final String? imageUrl;
  final int? color;
  final String? coverThumbnailUrl;
  final int wallpaperCount;

  const PublicCategory({
    required this.id,
    required this.slug,
    required this.nameEn,
    required this.nameAr,
    required this.iconUrl,
    required this.imageUrl,
    required this.color,
    required this.coverThumbnailUrl,
    required this.wallpaperCount,
  });

  factory PublicCategory.fromJson(Map<String, dynamic> json) => PublicCategory(
    id: _str(json['id'], ''),
    slug: _str(json['slug'], ''),
    nameEn: _str(json['nameEn'], ''),
    nameAr: _strOrNull(json['nameAr']),
    iconUrl: _strOrNull(json['iconUrl']),
    imageUrl: _strOrNull(json['imageUrl']),
    color: _colorOrNull(json['color']),
    coverThumbnailUrl: _strOrNull(json['coverThumbnailUrl']),
    wallpaperCount: _int(json['wallpaperCount'], 0),
  );

  String? get tileImageUrl => imageUrl ?? coverThumbnailUrl;
}

// ---------------------------------------------------------------------------------------------
// The wallpaper: a feed card, and the detail that extends it
// ---------------------------------------------------------------------------------------------

enum WallpaperType { standard, depth, video }

class Tag {
  final String slug;
  final String name;
  const Tag(this.slug, this.name);
  factory Tag.fromJson(Map<String, dynamic> json) =>
      Tag(_str(json['slug'], ''), _str(json['name'], ''));
}

/// One card on the feed, related and search. Carries the whole look, always.
class WallpaperCard {
  final String id;
  final String slug;
  final String title;
  final WallpaperType type;
  final int width;
  final int height;
  final String resolutionLabel;
  final int? dominantColor;
  final bool isPremium;
  final bool isFeatured;
  final String? categorySlug;

  /// The 360x640 grid picture. See [thumbnailIncludesLook].
  final String? thumbnailUrl;

  /// True: [thumbnailUrl] already shows the finished look. Draw nothing over it on a tile.
  final bool thumbnailIncludesLook;
  final List<Tag> tags;
  final int downloads;
  final int? fileSizeBytes;
  final String? blurhash;
  final DateTime? publishedAt;

  /// DEPTH only: the two layers, full size.
  final String? background;
  final String? foreground;

  /// DEPTH only: the clock, drawn between [background] and [foreground].
  final ClockConfig? clockConfig;

  /// DEPTH only: how the foreground layer is drawn.
  final DepthLayerConfig? depthConfig;

  /// VIDEO only, and only when the request asked for `include=video`.
  final VideoAsset? video;

  /// The grade, the STANDARD/VIDEO clock, the date, the extras and the behaviour. Null when
  /// nothing is saved or an administrator pulled the look back.
  final StudioLook? studio;

  const WallpaperCard({
    required this.id,
    required this.slug,
    required this.title,
    required this.type,
    required this.width,
    required this.height,
    required this.resolutionLabel,
    required this.dominantColor,
    required this.isPremium,
    required this.isFeatured,
    required this.categorySlug,
    required this.thumbnailUrl,
    required this.thumbnailIncludesLook,
    required this.tags,
    required this.downloads,
    required this.fileSizeBytes,
    required this.blurhash,
    required this.publishedAt,
    required this.background,
    required this.foreground,
    required this.clockConfig,
    required this.depthConfig,
    required this.video,
    required this.studio,
  });

  factory WallpaperCard.fromJson(Map<String, dynamic> json) {
    final category = json['category'];
    return WallpaperCard(
      id: _str(json['id'], ''),
      slug: _str(json['slug'], ''),
      title: _str(json['title'], ''),
      type: _enum(json['type'], WallpaperType.values, WallpaperType.standard),
      width: _int(json['width'], 0),
      height: _int(json['height'], 0),
      resolutionLabel: _str(json['resolutionLabel'], ''),
      dominantColor: _colorOrNull(json['dominantColor']),
      isPremium: _bool(json['isPremium'], false),
      isFeatured: _bool(json['isFeatured'], false),
      // The card says `categorySlug`; the detail nests it in `category`.
      categorySlug:
          _strOrNull(json['categorySlug']) ??
          (category is Map ? _strOrNull(category['slug']) : null),
      // The card says `thumbnailUrl`; the detail says `thumbnail`.
      thumbnailUrl:
          _strOrNull(json['thumbnailUrl']) ?? _strOrNull(json['thumbnail']),
      thumbnailIncludesLook: _bool(json['thumbnailIncludesLook'], false),
      tags: _list(json['tags']).map((e) => Tag.fromJson(_map(e))).toList(),
      downloads: _int(json['downloads'], 0),
      fileSizeBytes: _intOrNull(json['fileSizeBytes']),
      blurhash: _strOrNull(json['blurhash']),
      publishedAt: DateTime.tryParse(_str(json['publishedAt'], '')),
      background: _strOrNull(json['background']),
      foreground: _strOrNull(json['foreground']),
      clockConfig: json['clockConfig'] is Map
          ? ClockConfig.fromJson(_map(json['clockConfig']))
          : null,
      depthConfig: json['depthConfig'] is Map
          ? DepthLayerConfig.fromJson(_map(json['depthConfig']))
          : null,
      video: json['video'] is Map
          ? VideoAsset.fromJson(_map(json['video']))
          : null,
      studio: json['studio'] is Map
          ? StudioLook.fromJson(_map(json['studio']))
          : null,
    );
  }

  /// The clock to draw, whatever the type: DEPTH uses [clockConfig], the others `studio.clock`.
  /// Null, or `enabled == false`, means no clock.
  ClockConfig? get clockToDraw =>
      type == WallpaperType.depth ? clockConfig : studio?.clock;

  /// Whether a grid tile draws the look over [thumbnailUrl].
  bool get tileDrawsLook => !thumbnailIncludesLook;
}

/// `GET /wallpapers/{idOrSlug}`: everything a card has, and more.
class WallpaperDetail extends WallpaperCard {
  final String? description;
  final String language;
  final String? categoryNameEn;
  final String? categoryNameAr;

  /// Every stored asset by kind: THUMBNAIL, PREVIEW (the full screen still), FOREGROUND,
  /// BACKGROUND, POSTER, VIDEO_LOOP, STYLED_PREVIEW.
  final Map<String, PublicAsset> assets;

  const WallpaperDetail({
    required super.id,
    required super.slug,
    required super.title,
    required super.type,
    required super.width,
    required super.height,
    required super.resolutionLabel,
    required super.dominantColor,
    required super.isPremium,
    required super.isFeatured,
    required super.categorySlug,
    required super.thumbnailUrl,
    required super.thumbnailIncludesLook,
    required super.tags,
    required super.downloads,
    required super.fileSizeBytes,
    required super.blurhash,
    required super.publishedAt,
    required super.background,
    required super.foreground,
    required super.clockConfig,
    required super.depthConfig,
    required super.video,
    required super.studio,
    required this.description,
    required this.language,
    required this.categoryNameEn,
    required this.categoryNameAr,
    required this.assets,
  });

  factory WallpaperDetail.fromJson(Map<String, dynamic> json) {
    final card = WallpaperCard.fromJson(json);
    final category = _map(json['category']);
    return WallpaperDetail(
      id: card.id,
      slug: card.slug,
      title: card.title,
      type: card.type,
      width: card.width,
      height: card.height,
      resolutionLabel: card.resolutionLabel,
      dominantColor: card.dominantColor,
      isPremium: card.isPremium,
      isFeatured: card.isFeatured,
      categorySlug: card.categorySlug,
      thumbnailUrl: card.thumbnailUrl,
      thumbnailIncludesLook: card.thumbnailIncludesLook,
      tags: card.tags,
      downloads: card.downloads,
      fileSizeBytes: card.fileSizeBytes,
      blurhash: card.blurhash,
      publishedAt: card.publishedAt,
      background: card.background,
      foreground: card.foreground,
      clockConfig: card.clockConfig,
      depthConfig: card.depthConfig,
      video: card.video,
      studio: card.studio,
      description: _strOrNull(json['description']),
      language: _str(json['language'], 'en'),
      categoryNameEn: _strOrNull(category['nameEn']),
      categoryNameAr: _strOrNull(category['nameAr']),
      assets: _map(
        json['assets'],
      ).map((kind, value) => MapEntry(kind, PublicAsset.fromJson(_map(value)))),
    );
  }

  /// The full screen still: PREVIEW, falling back to the thumbnail on very old wallpapers.
  String? get fullScreenUrl => assets['PREVIEW']?.url ?? thumbnailUrl;
}

class PublicAsset {
  final String url;
  final String mime;
  final int? width;
  final int? height;
  final int bytes;

  const PublicAsset({
    required this.url,
    required this.mime,
    required this.width,
    required this.height,
    required this.bytes,
  });

  factory PublicAsset.fromJson(Map<String, dynamic> json) => PublicAsset(
    url: _str(json['url'], ''),
    mime: _str(json['mime'], ''),
    width: _intOrNull(json['width']),
    height: _intOrNull(json['height']),
    bytes: _int(json['bytes'], 0),
  );
}

class VideoAsset {
  final String url;
  final String mime;
  final int width;
  final int height;
  final int durationMs;
  final double fps;
  final int sizeBytes;
  final String codec;

  const VideoAsset({
    required this.url,
    required this.mime,
    required this.width,
    required this.height,
    required this.durationMs,
    required this.fps,
    required this.sizeBytes,
    required this.codec,
  });

  factory VideoAsset.fromJson(Map<String, dynamic> json) => VideoAsset(
    url: _str(json['url'], ''),
    mime: _str(json['mime'], 'video/mp4'),
    width: _int(json['width'], 0),
    height: _int(json['height'], 0),
    durationMs: _int(json['durationMs'], 0),
    fps: _double(json['fps'], 30, min: 0, max: 240),
    sizeBytes: _int(json['sizeBytes'], 0),
    codec: _str(json['codec'], ''),
  );
}

// ---------------------------------------------------------------------------------------------
// The clock (depth `clockConfig` and studio `clock` share this shape)
// ---------------------------------------------------------------------------------------------

enum ClockStyle {
  modern,
  minimal,
  elegant,
  digital,
  condensed,
  poster,
  outline,
  split,
  futuristic,
  editorial,
  monument,
  stencil,
  soft,
  outlined,
  solid,
  thin,
  bold,
  classic,
  rounded,
}

enum ClockPosition { top, center, bottom, custom }

enum FontWeightPreset {
  extraLight,
  light,
  regular,
  medium,
  semiBold,
  bold,
  extraBold,
  black,
}

/// single: [ClockConfig.color]. split: hours/minutes colours. auto: pick a colour from the
/// picture behind the clock (docs/CLOCK_AUTO_COLOR.md). gradient: gradientFrom -> gradientTo.
enum ClockColorMode { single, split, auto, gradient }

enum ColonColor { hours, minutes, custom }

enum TimeLayout { inline, stacked, stackedCompact, offsetStack, verticalPoster }

/// Whether the stroke is drawn behind the fill or on top of it.
enum StrokeOrder { behind, front }

enum FadeDirection { bottom, top, both }

enum DatePosition { above, below }

/// Studio clock only. `auto` follows the phone's own 12/24 hour setting.
enum HourFormat { h12, h24, auto }

class ClockShadow {
  final bool enabled;
  final double strength;
  const ClockShadow({required this.enabled, required this.strength});

  factory ClockShadow.fromJson(Map<String, dynamic> json) => ClockShadow(
    enabled: _bool(json['enabled'], true),
    strength: _double(json['strength'], 0.4, min: 0, max: 1),
  );
}

/// The date the clock carries with it, directly above or below the time.
class ClockDate {
  final bool enabled;
  final DatePosition position;
  final int color;
  const ClockDate({
    required this.enabled,
    required this.position,
    required this.color,
  });

  factory ClockDate.fromJson(Map<String, dynamic> json) => ClockDate(
    enabled: _bool(json['enabled'], true),
    position: _enum(json['position'], DatePosition.values, DatePosition.below),
    color: _color(json['color'], 0xCCFFFFFF),
  );
}

class ClockConfig {
  final bool enabled;
  final ClockStyle style;
  final ClockPosition position;
  final double? customX;
  final double? customY;
  final String font;
  final int weight;

  /// A multiplier on the size; see [sizePx].
  final double scale;

  /// Degrees, -180..180.
  final double rotation;
  final int color;
  final double opacity;

  /// DEPTH: how much of the clock the foreground hides. 0 fully behind the subject, 1 in front.
  final double depth;
  final ClockShadow shadow;
  final ClockDate date;

  /// The digit size in logical pixels on a 1080-wide reference screen, 24..320.
  final double sizePx;
  final double horizontalScale;
  final double stretchY;
  final FontWeightPreset fontWeightPreset;
  final ClockColorMode colorMode;
  final int? hoursColor;
  final int? minutesColor;
  final ColonColor colonColor;
  final int? colonColorCustom;
  final TimeLayout timeLayout;
  final bool showColon;
  final double lineSpacing;
  final double minuteOffsetX;
  final bool is24Hour;
  final bool showSeconds;

  /// A 12 hour clock's AM/PM mark, drawn small after the minutes.
  final bool showAmPm;
  final double dateScale;
  final bool showGlow;
  final bool showStroke;
  final double strokeWidth;
  final int? gradientFrom;
  final int? gradientTo;

  /// CSS convention: 0 runs bottom to top, 90 left to right, 180 top to bottom.
  final double gradientAngleDeg;

  /// A different font for the hours or the minutes; null uses [font].
  final String? hoursFont;
  final String? minutesFont;
  final int strokeColor;
  final StrokeOrder strokeOrder;

  /// Scales the fill only; at 0 with a stroke the digits are outlines.
  final double fillOpacity;

  /// The share of the clock's height that fades out at [fadeDirection], 0..1.
  final double fadeAmount;
  final FadeDirection fadeDirection;

  /// Gaussian blur of the time, 0..20 logical pixels. The date stays sharp.
  final double blur;

  /// Studio clock only (null on a depth clock). Prefer it over [is24Hour] when set.
  final HourFormat? hourFormat;

  /// Studio clock only: blink the colon once a second.
  final bool separatorBlink;
  final int schemaVersion;

  const ClockConfig({
    required this.enabled,
    required this.style,
    required this.position,
    required this.customX,
    required this.customY,
    required this.font,
    required this.weight,
    required this.scale,
    required this.rotation,
    required this.color,
    required this.opacity,
    required this.depth,
    required this.shadow,
    required this.date,
    required this.sizePx,
    required this.horizontalScale,
    required this.stretchY,
    required this.fontWeightPreset,
    required this.colorMode,
    required this.hoursColor,
    required this.minutesColor,
    required this.colonColor,
    required this.colonColorCustom,
    required this.timeLayout,
    required this.showColon,
    required this.lineSpacing,
    required this.minuteOffsetX,
    required this.is24Hour,
    required this.showSeconds,
    required this.showAmPm,
    required this.dateScale,
    required this.showGlow,
    required this.showStroke,
    required this.strokeWidth,
    required this.gradientFrom,
    required this.gradientTo,
    required this.gradientAngleDeg,
    required this.hoursFont,
    required this.minutesFont,
    required this.strokeColor,
    required this.strokeOrder,
    required this.fillOpacity,
    required this.fadeAmount,
    required this.fadeDirection,
    required this.blur,
    required this.hourFormat,
    required this.separatorBlink,
    required this.schemaVersion,
  });

  factory ClockConfig.fromJson(Map<String, dynamic> json) {
    final rawHourFormat = _strOrNull(json['hourFormat']);
    return ClockConfig(
      enabled: _bool(json['enabled'], true),
      style: _enum(json['style'], ClockStyle.values, ClockStyle.outlined),
      position: _enum(
        json['position'],
        ClockPosition.values,
        ClockPosition.center,
      ),
      customX: _doubleOrNull(json['customX'], min: 0, max: 1),
      customY: _doubleOrNull(json['customY'], min: 0, max: 1),
      font: _str(json['font'], 'Inter'),
      weight: _int(json['weight'], 700, min: 100, max: 900),
      scale: _double(json['scale'], 1, min: 0.5, max: 3),
      rotation: _double(json['rotation'], 0, min: -180, max: 180),
      color: _color(json['color'], 0xFFFFFFFF),
      opacity: _double(json['opacity'], 1, min: 0, max: 1),
      depth: _double(json['depth'], 0.45, min: 0, max: 1),
      shadow: ClockShadow.fromJson(_map(json['shadow'])),
      date: ClockDate.fromJson(_map(json['date'])),
      sizePx: _double(json['sizePx'], 65, min: 24, max: 320),
      horizontalScale: _double(json['horizontalScale'], 1, min: 0.55, max: 1.5),
      stretchY: _double(json['stretchY'], 1, min: 1, max: 3),
      fontWeightPreset: _enum(
        json['fontWeightPreset'],
        FontWeightPreset.values,
        FontWeightPreset.regular,
      ),
      colorMode: _enum(
        json['colorMode'],
        ClockColorMode.values,
        ClockColorMode.single,
      ),
      hoursColor: _colorOrNull(json['hoursColor']),
      minutesColor: _colorOrNull(json['minutesColor']),
      colonColor: _enum(
        json['colonColor'],
        ColonColor.values,
        ColonColor.hours,
      ),
      colonColorCustom: _colorOrNull(json['colonColorCustom']),
      timeLayout: _enum(
        json['timeLayout'],
        TimeLayout.values,
        TimeLayout.inline,
      ),
      showColon: _bool(json['showColon'], true),
      lineSpacing: _double(json['lineSpacing'], 1, min: 0.5, max: 2),
      minuteOffsetX: _double(json['minuteOffsetX'], 0, min: -1, max: 1),
      is24Hour: _bool(json['is24Hour'], false),
      showSeconds: _bool(json['showSeconds'], false),
      showAmPm: _bool(json['showAmPm'], true),
      dateScale: _double(json['dateScale'], 1, min: 0.5, max: 2),
      showGlow: _bool(json['showGlow'], false),
      showStroke: _bool(json['showStroke'], false),
      strokeWidth: _double(json['strokeWidth'], 2, min: 0.5, max: 20),
      gradientFrom: _colorOrNull(json['gradientFrom']),
      gradientTo: _colorOrNull(json['gradientTo']),
      gradientAngleDeg: _double(
        json['gradientAngleDeg'],
        180,
        min: 0,
        max: 360,
      ),
      hoursFont: _strOrNull(json['hoursFont']),
      minutesFont: _strOrNull(json['minutesFont']),
      strokeColor: _color(json['strokeColor'], 0xFF000000),
      strokeOrder: _enum(
        json['strokeOrder'],
        StrokeOrder.values,
        StrokeOrder.behind,
      ),
      fillOpacity: _double(json['fillOpacity'], 1, min: 0, max: 1),
      fadeAmount: _double(json['fadeAmount'], 0, min: 0, max: 1),
      fadeDirection: _enum(
        json['fadeDirection'],
        FadeDirection.values,
        FadeDirection.bottom,
      ),
      blur: _double(json['blur'], 0, min: 0, max: 20),
      hourFormat: switch (rawHourFormat) {
        '12' => HourFormat.h12,
        '24' => HourFormat.h24,
        'auto' => HourFormat.auto,
        _ => null,
      },
      separatorBlink: _bool(json['separatorBlink'], false),
      schemaVersion: _int(json['schemaVersion'], 1),
    );
  }

  /// Whether to draw a 24 hour clock, given the phone's own setting for `hourFormat: auto`.
  bool uses24Hour({required bool deviceIs24Hour}) => switch (hourFormat) {
    HourFormat.h24 => true,
    HourFormat.h12 => false,
    HourFormat.auto => deviceIs24Hour,
    null => is24Hour,
  };

  bool get hasExactPosition => customX != null && customY != null;
}

// ---------------------------------------------------------------------------------------------
// Depth layers
// ---------------------------------------------------------------------------------------------

class DepthLayerConfig {
  /// The foreground's scale around its centre, 0.5..3.
  final double foregroundScale;

  /// The foreground's offset as a share of the screen, -1..1 (x of the width, y of the height).
  final double foregroundOffsetX;
  final double foregroundOffsetY;

  /// Blur of the foreground in pixels of the full size image, 0..100. Scale it to the screen.
  final double blurRadius;

  /// Drop shadow under the subject, 0..1.
  final double shadowStrength;

  /// How far the two layers move against each other as the phone tilts, 0..1. 0 keeps them still.
  final double parallaxStrength;

  const DepthLayerConfig({
    required this.foregroundScale,
    required this.foregroundOffsetX,
    required this.foregroundOffsetY,
    required this.blurRadius,
    required this.shadowStrength,
    required this.parallaxStrength,
  });

  factory DepthLayerConfig.fromJson(
    Map<String, dynamic> json,
  ) => DepthLayerConfig(
    foregroundScale: _double(json['foregroundScale'], 1, min: 0.5, max: 3),
    foregroundOffsetX: _double(json['foregroundOffsetX'], 0, min: -1, max: 1),
    foregroundOffsetY: _double(json['foregroundOffsetY'], 0, min: -1, max: 1),
    blurRadius: _double(json['blurRadius'], 0, min: 0, max: 100),
    shadowStrength: _double(json['shadowStrength'], 0.35, min: 0, max: 1),
    parallaxStrength: _double(json['parallaxStrength'], 0, min: 0, max: 1),
  );
}

// ---------------------------------------------------------------------------------------------
// The studio look: grade, clock, date, extras, behaviour
// ---------------------------------------------------------------------------------------------

class StudioLook {
  final SceneAdjustments scene;

  /// STANDARD and VIDEO only; always null on DEPTH, whose clock is the card's `clockConfig`.
  final ClockConfig? clock;
  final DateWidget dateWidget;
  final List<StudioWidget> widgets;
  final WallpaperBehavior behavior;

  /// The picture with [scene] already applied, or null when there is no bake yet.
  final String? styledPreviewUrl;

  const StudioLook({
    required this.scene,
    required this.clock,
    required this.dateWidget,
    required this.widgets,
    required this.behavior,
    required this.styledPreviewUrl,
  });

  factory StudioLook.fromJson(Map<String, dynamic> json) => StudioLook(
    scene: SceneAdjustments.fromJson(_map(json['scene'])),
    clock: json['clock'] is Map
        ? ClockConfig.fromJson(_map(json['clock']))
        : null,
    dateWidget: DateWidget.fromJson(_map(json['dateWidget'])),
    widgets: _list(json['widgets'])
        .map((e) => StudioWidget.fromJson(_map(e)))
        .whereType<StudioWidget>()
        .toList(),
    behavior: WallpaperBehavior.fromJson(_map(json['behavior'])),
    styledPreviewUrl: _strOrNull(json['styledPreviewUrl']),
  );
}

enum BlendMode {
  normal,
  multiply,
  screen,
  overlay,
  softLight,
  hardLight,
  colorDodge,
  colorBurn,
  darken,
  lighten,
  difference,
  exclusion,
}

BlendMode _blend(Object? value, BlendMode fallback) {
  // The API spells these the CSS way: 'soft-light', 'color-dodge'.
  final raw = _strOrNull(value)
      ?.replaceAllMapped(RegExp(r'-([a-z])'), (m) => m.group(1)!.toUpperCase());
  return _enum(raw, BlendMode.values, fallback);
}

/// The photo filter. Every value at its default is "no change".
class SceneAdjustments {
  final double brightness; // -1..1
  final double contrast; // -1..1
  final double saturation; // -1..1
  final double warmth; // -1..1, negative cooler
  final double exposure; // -1..1, in stops
  final double sharpen; // 0..1
  final double blur; // 0..100 pixels of the full size image
  final double vignetteAmount; // 0..1
  final double vignetteSoftness; // 0..1
  final double grainAmount; // 0..1
  final double grainSize; // 0.5..4
  final GradientOverlay gradientOverlay;
  final Tint tint;
  final Duotone duotone;

  const SceneAdjustments({
    required this.brightness,
    required this.contrast,
    required this.saturation,
    required this.warmth,
    required this.exposure,
    required this.sharpen,
    required this.blur,
    required this.vignetteAmount,
    required this.vignetteSoftness,
    required this.grainAmount,
    required this.grainSize,
    required this.gradientOverlay,
    required this.tint,
    required this.duotone,
  });

  factory SceneAdjustments.fromJson(Map<String, dynamic> json) {
    final vignette = _map(json['vignette']);
    final grain = _map(json['grain']);
    return SceneAdjustments(
      brightness: _double(json['brightness'], 0, min: -1, max: 1),
      contrast: _double(json['contrast'], 0, min: -1, max: 1),
      saturation: _double(json['saturation'], 0, min: -1, max: 1),
      warmth: _double(json['warmth'], 0, min: -1, max: 1),
      exposure: _double(json['exposure'], 0, min: -1, max: 1),
      sharpen: _double(json['sharpen'], 0, min: 0, max: 1),
      blur: _double(json['blur'], 0, min: 0, max: 100),
      vignetteAmount: _double(vignette['amount'], 0, min: 0, max: 1),
      vignetteSoftness: _double(vignette['softness'], 0.5, min: 0, max: 1),
      grainAmount: _double(grain['amount'], 0, min: 0, max: 1),
      grainSize: _double(grain['size'], 1, min: 0.5, max: 4),
      gradientOverlay: GradientOverlay.fromJson(_map(json['gradientOverlay'])),
      tint: Tint.fromJson(_map(json['tint'])),
      duotone: Duotone.fromJson(_map(json['duotone'])),
    );
  }

  bool get isIdentity =>
      brightness == 0 &&
      contrast == 0 &&
      saturation == 0 &&
      warmth == 0 &&
      exposure == 0 &&
      sharpen == 0 &&
      blur == 0 &&
      vignetteAmount == 0 &&
      grainAmount == 0 &&
      !gradientOverlay.enabled &&
      !tint.enabled &&
      !duotone.enabled;
}

class GradientOverlay {
  final bool enabled;
  final int from;
  final int to;
  final double angleDeg; // CSS convention, like the clock's gradient
  final double opacity;
  final BlendMode blendMode;

  const GradientOverlay({
    required this.enabled,
    required this.from,
    required this.to,
    required this.angleDeg,
    required this.opacity,
    required this.blendMode,
  });

  factory GradientOverlay.fromJson(Map<String, dynamic> json) =>
      GradientOverlay(
        enabled: _bool(json['enabled'], false),
        from: _color(json['from'], 0x00000000),
        to: _color(json['to'], 0xFF000000),
        angleDeg: _double(json['angleDeg'], 180, min: 0, max: 360),
        opacity: _double(json['opacity'], 0.5, min: 0, max: 1),
        blendMode: _blend(json['blendMode'], BlendMode.normal),
      );
}

class Tint {
  final bool enabled;
  final int color;
  final double opacity;
  final BlendMode blendMode;

  const Tint({
    required this.enabled,
    required this.color,
    required this.opacity,
    required this.blendMode,
  });

  factory Tint.fromJson(Map<String, dynamic> json) => Tint(
    enabled: _bool(json['enabled'], false),
    color: _color(json['color'], 0xFF000000),
    opacity: _double(json['opacity'], 0.2, min: 0, max: 1),
    blendMode: _blend(json['blendMode'], BlendMode.softLight),
  );
}

class Duotone {
  final bool enabled;
  final int shadow;
  final int highlight;

  const Duotone({
    required this.enabled,
    required this.shadow,
    required this.highlight,
  });

  factory Duotone.fromJson(Map<String, dynamic> json) => Duotone(
    enabled: _bool(json['enabled'], false),
    shadow: _color(json['shadow'], 0xFF000000),
    highlight: _color(json['highlight'], 0xFFFFFFFF),
  );
}

enum DateFormat { weekday, short, medium, long, numeric, custom }

enum WidgetPosition { top, center, bottom, custom }

/// The date as its own piece on the screen (separate from the date a clock carries).
class DateWidget {
  final bool enabled;
  final DateFormat format;

  /// With format `custom`: a date-fns style pattern, e.g. `EEEE, d MMMM yyyy`. Map it to intl's
  /// DateFormat; the letters are the same for everything the dashboard offers.
  final String? pattern;

  /// BCP 47, e.g. `en`, `ar`. Format in this locale, not the phone's.
  final String locale;
  final WidgetPosition position;
  final double? customX;
  final double? customY;
  final int color;
  final double scale;
  final String font;
  final int weight;
  final bool uppercase;

  const DateWidget({
    required this.enabled,
    required this.format,
    required this.pattern,
    required this.locale,
    required this.position,
    required this.customX,
    required this.customY,
    required this.color,
    required this.scale,
    required this.font,
    required this.weight,
    required this.uppercase,
  });

  factory DateWidget.fromJson(Map<String, dynamic> json) => DateWidget(
    enabled: _bool(json['enabled'], false),
    format: _enum(json['format'], DateFormat.values, DateFormat.medium),
    pattern: _strOrNull(json['pattern']),
    locale: _str(json['locale'], 'en'),
    position: _enum(
      json['position'],
      WidgetPosition.values,
      WidgetPosition.bottom,
    ),
    customX: _doubleOrNull(json['customX'], min: 0, max: 1),
    customY: _doubleOrNull(json['customY'], min: 0, max: 1),
    color: _color(json['color'], 0xFFFFFFFF),
    scale: _double(json['scale'], 1, min: 0.5, max: 3),
    font: _str(json['font'], 'Inter'),
    weight: _int(json['weight'], 400, min: 100, max: 900),
    uppercase: _bool(json['uppercase'], false),
  );
}

enum WidgetAnchor { top, center, bottom }

/// An extra on the lock screen. Switch on the subtype.
sealed class StudioWidget {
  final WidgetAnchor anchor;
  final double? customX;
  final double? customY;
  final double rotation;
  final int color;
  final double scale;

  const StudioWidget({
    required this.anchor,
    required this.customX,
    required this.customY,
    required this.rotation,
    required this.color,
    required this.scale,
  });

  /// Null for a kind this app version does not know yet, which is then skipped.
  static StudioWidget? fromJson(Map<String, dynamic> json) {
    final anchor = _enum(json['anchor'], WidgetAnchor.values, WidgetAnchor.top);
    final customX = _doubleOrNull(json['customX'], min: 0, max: 1);
    final customY = _doubleOrNull(json['customY'], min: 0, max: 1);
    final rotation = _double(json['rotation'], 0, min: -180, max: 180);
    final color = _color(json['color'], 0xFFFFFFFF);
    final scale = _double(json['scale'], 1, min: 0.5, max: 3);

    switch (_strOrNull(json['kind'])) {
      case 'weather':
        return WeatherWidget(
          anchor: anchor,
          customX: customX,
          customY: customY,
          rotation: rotation,
          color: color,
          scale: scale,
          celsius: _str(json['unit'], 'celsius') != 'fahrenheit',
          showCondition: _bool(json['showCondition'], true),
          font: _str(json['font'], 'Inter'),
          weight: _int(json['weight'], 400, min: 100, max: 900),
          layout: _enum(
            json['layout'],
            WeatherLayout.values,
            WeatherLayout.inline,
          ),
          iconStyle: _enum(
            json['iconStyle'],
            WeatherIconStyle.values,
            WeatherIconStyle.none,
          ),
          showCity: _bool(json['showCity'], false),
          showHighLow: _bool(json['showHighLow'], false),
        );
      case 'batteryRing':
        return BatteryRingWidget(
          anchor: anchor,
          customX: customX,
          customY: customY,
          rotation: rotation,
          color: color,
          scale: scale,
          showPercentage: _bool(json['showPercentage'], true),
        );
      case 'textLabel':
        return TextLabelWidget(
          anchor: anchor,
          customX: customX,
          customY: customY,
          rotation: rotation,
          color: color,
          scale: scale,
          text: _str(json['text'], ''),
          font: _str(json['font'], 'Inter'),
          weight: _int(json['weight'], 400, min: 100, max: 900),
          uppercase: _bool(json['uppercase'], false),
        );
      default:
        return null;
    }
  }
}

enum WeatherLayout { inline, stacked, compact }

enum WeatherIconStyle { none, filled, outline }

class WeatherWidget extends StudioWidget {
  final bool celsius;
  final bool showCondition;
  final String font;
  final int weight;
  final WeatherLayout layout;
  final WeatherIconStyle iconStyle;
  final bool showCity;
  final bool showHighLow;

  const WeatherWidget({
    required super.anchor,
    required super.customX,
    required super.customY,
    required super.rotation,
    required super.color,
    required super.scale,
    required this.celsius,
    required this.showCondition,
    required this.font,
    required this.weight,
    required this.layout,
    required this.iconStyle,
    required this.showCity,
    required this.showHighLow,
  });
}

class BatteryRingWidget extends StudioWidget {
  final bool showPercentage;

  const BatteryRingWidget({
    required super.anchor,
    required super.customX,
    required super.customY,
    required super.rotation,
    required super.color,
    required super.scale,
    required this.showPercentage,
  });
}

class TextLabelWidget extends StudioWidget {
  final String text;
  final String font;
  final int weight;
  final bool uppercase;

  const TextLabelWidget({
    required super.anchor,
    required super.customX,
    required super.customY,
    required super.rotation,
    required super.color,
    required super.scale,
    required this.text,
    required this.font,
    required this.weight,
    required this.uppercase,
  });
}

/// ask: let the user pick. lock / home / both: set it there without asking.
enum ApplyTarget { ask, lock, home, both }

enum ClockEntrance { none, fade, rise, scale }

/// What the app does when the wallpaper is set.
class WallpaperBehavior {
  final ApplyTarget applyTarget;
  final ClockEntrance clockEntrance;
  final int clockEntranceMs; // 100..3000

  const WallpaperBehavior({
    required this.applyTarget,
    required this.clockEntrance,
    required this.clockEntranceMs,
  });

  factory WallpaperBehavior.fromJson(Map<String, dynamic> json) =>
      WallpaperBehavior(
        applyTarget: _enum(
          json['applyTarget'],
          ApplyTarget.values,
          ApplyTarget.ask,
        ),
        clockEntrance: _enum(
          json['clockEntrance'],
          ClockEntrance.values,
          ClockEntrance.none,
        ),
        clockEntranceMs: _int(
          json['clockEntranceMs'],
          600,
          min: 100,
          max: 3000,
        ),
      );
}

// ---------------------------------------------------------------------------------------------
// App config: fonts and the rest
// ---------------------------------------------------------------------------------------------

class PublicConfig {
  final String minSupportedVersion;
  final String cdnBaseUrl;
  final Map<String, bool> featureFlags;

  /// Changes when the category list changes; refetch categories when it does.
  final String categoriesHash;
  final StudioSettings studio;

  const PublicConfig({
    required this.minSupportedVersion,
    required this.cdnBaseUrl,
    required this.featureFlags,
    required this.categoriesHash,
    required this.studio,
  });

  factory PublicConfig.fromJson(Map<String, dynamic> json) => PublicConfig(
    minSupportedVersion: _str(json['minSupportedVersion'], '0.0.0'),
    cdnBaseUrl: _str(json['cdnBaseUrl'], ''),
    featureFlags: _map(json['featureFlags'])
        .map((k, v) => MapEntry(k, v == true)),
    categoriesHash: _str(json['categoriesHash'], ''),
    studio: StudioSettings.fromJson(_map(json['studio'])),
  );
}

class StudioSettings {
  final int schemaVersion;
  final List<String> allowedClockFonts;

  /// Font files to download and register by [ClockFontFile.family]. Cache by checksum.
  final List<ClockFontFile> fonts;
  final List<String> allowedDateLocales;

  const StudioSettings({
    required this.schemaVersion,
    required this.allowedClockFonts,
    required this.fonts,
    required this.allowedDateLocales,
  });

  factory StudioSettings.fromJson(Map<String, dynamic> json) => StudioSettings(
    schemaVersion: _int(json['schemaVersion'], 1),
    allowedClockFonts: _list(json['allowedClockFonts'])
        .map((e) => '$e')
        .toList(),
    fonts: _list(json['fonts'])
        .map((e) => ClockFontFile.fromJson(_map(e)))
        .toList(),
    allowedDateLocales: _list(json['allowedDateLocales'])
        .map((e) => '$e')
        .toList(),
  );
}

class ClockFontFile {
  final String family;
  final String url;
  final String format; // ttf | otf
  final int bytes;
  final String checksum;

  const ClockFontFile({
    required this.family,
    required this.url,
    required this.format,
    required this.bytes,
    required this.checksum,
  });

  factory ClockFontFile.fromJson(Map<String, dynamic> json) => ClockFontFile(
    family: _str(json['family'], ''),
    url: _str(json['url'], ''),
    format: _str(json['format'], 'ttf'),
    bytes: _int(json['bytes'], 0),
    checksum: _str(json['checksum'], ''),
  );
}

// ---------------------------------------------------------------------------------------------
// Forgiving readers
// ---------------------------------------------------------------------------------------------

Map<String, dynamic> _map(Object? value) =>
    value is Map ? value.map((k, v) => MapEntry('$k', v)) : <String, dynamic>{};

List<Object?> _list(Object? value) => value is List ? value : const [];

String _str(Object? value, String fallback) =>
    value is String ? value : fallback;

String? _strOrNull(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

bool _bool(Object? value, bool fallback) => value is bool ? value : fallback;

int _int(Object? value, int fallback, {int? min, int? max}) {
  final parsed = value is num ? value.round() : fallback;
  if (min != null && parsed < min) return min;
  if (max != null && parsed > max) return max;
  return parsed;
}

int? _intOrNull(Object? value) => value is num ? value.round() : null;

double _double(
  Object? value,
  double fallback, {
  required double min,
  required double max,
}) {
  final parsed = value is num && value.isFinite ? value.toDouble() : fallback;
  return parsed.clamp(min, max).toDouble();
}

double? _doubleOrNull(
  Object? value, {
  required double min,
  required double max,
}) => value is num && value.isFinite
    ? value.toDouble().clamp(min, max).toDouble()
    : null;

/// The enum value whose name matches, or [fallback].
T _enum<T extends Enum>(Object? value, List<T> values, T fallback) {
  if (value is! String) return fallback;
  for (final candidate in values) {
    if (candidate.name == value) return candidate;
  }
  return fallback;
}

/// `#RRGGBB` or `#RRGGBBAA` (the API's spelling) as a Flutter ARGB int.
int? _colorOrNull(Object? value) {
  if (value is! String) return null;
  final hex = value.startsWith('#') ? value.substring(1) : value;
  if (hex.length != 6 && hex.length != 8) return null;
  final rgb = int.tryParse(hex.substring(0, 6), radix: 16);
  final alpha = hex.length == 8
      ? int.tryParse(hex.substring(6, 8), radix: 16)
      : 0xFF;
  if (rgb == null || alpha == null) return null;
  return (alpha << 24) | rgb;
}

int _color(Object? value, int fallback) => _colorOrNull(value) ?? fallback;
