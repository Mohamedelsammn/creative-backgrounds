import 'package:equatable/equatable.dart';

/// A wallpaper category.
///
/// The public API identifies categories by [slug] (that is what feed items
/// carry) and names them in both English and Arabic, matching the app's two
/// locales. [id] is the server's UUID; when a category is synthesized from a
/// slug we could not resolve, [id] falls back to the slug itself.
class CategoryEntity extends Equatable {
  const CategoryEntity({
    required this.id,
    required this.name,
    this.slug = '',
    this.nameAr,
    this.color,
    this.thumbnailUrl,
    this.wallpaperCount,
  });

  final String id;

  /// English display name (`nameEn`). Kept as `name` so existing callers and
  /// the sort/search paths are unaffected.
  final String name;

  /// Stable URL-safe identifier, e.g. `amoled`. This is the key feed items use
  /// (`categorySlug`) and the value to send back as the `categorySlug` filter.
  final String slug;

  /// Arabic display name, when the backend has one.
  final String? nameAr;

  /// ARGB color parsed from the API hex string (e.g. "#F5A623"). Nullable -
  /// the UI falls back to `AppColors.categoryAccents` by name.
  final int? color;

  /// `imageUrl` on the public API's current contract (verified against
  /// production - see `CategoryModel.fromApi`'s own doc); falls back to
  /// `coverThumbnailUrl`/`iconUrl` for an older or differently-shaped
  /// response. The single source of a category's cover art - the app no
  /// longer bundles any local category cover image.
  final String? thumbnailUrl;

  final int? wallpaperCount;

  /// Picks the name for [localeCode] ('ar' or 'en'), falling back to English
  /// whenever the Arabic name is missing or blank.
  String displayName(String localeCode) {
    if (localeCode.toLowerCase().startsWith('ar')) {
      final ar = nameAr;
      if (ar != null && ar.trim().isNotEmpty) return ar;
    }
    return name;
  }

  /// Builds a placeholder for a slug that is not in the category directory -
  /// e.g. a category published after the cached list was fetched. Turns
  /// `city-lights` into `City Lights` so the UI always has something to show.
  factory CategoryEntity.fromSlug(String slug) {
    final name = slug
        .split(RegExp(r'[-_]'))
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
    return CategoryEntity(
      id: slug,
      name: name.isEmpty ? slug : name,
      slug: slug,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    slug,
    nameAr,
    color,
    thumbnailUrl,
    wallpaperCount,
  ];
}
