import '../../explore/domain/entities/category_entity.dart';

/// The "Live Wallpapers" browse tile.
///
/// Deliberately a CLIENT-SIDE pseudo-category, not a backend category row:
/// live-ness is a property of the wallpaper (`WallpaperType.live`), not a
/// taxonomy bucket a wallpaper is filed under. Inventing a real `live`
/// category server-side would mean every live wallpaper had to be re-tagged
/// (losing its actual category - a live Cars wallpaper belongs in Cars too)
/// and would drift the moment a new live wallpaper was published without the
/// extra tag.
///
/// Instead this slug is recognised by `CategoryDetailsBloc`, which serves it
/// from the existing server-side `type=video` feed
/// (`GetLiveWallpapersUseCase`) rather than the per-category feed. Everything
/// downstream - grid, cards, shimmer, pagination, favourites, the single
/// bottom banner - is the unmodified Category Details screen.
class LiveCategory {
  const LiveCategory._();

  /// Reserved slug for the pseudo-category. Chosen to not collide with any
  /// real backend slug; `CategoryDetailsBloc.isLiveSlug` is the single place
  /// that interprets it.
  static const String slug = '__live__';

  /// The tile shown first in the Categories tab.
  ///
  /// [wallpaperCount] is null because the pseudo-category has no backend
  /// count metadata - the Categories card already renders no count line when
  /// it is null, so nothing fabricates a number here.
  static const CategoryEntity entity = CategoryEntity(
    id: slug,
    name: 'Live Wallpapers',
    nameAr: 'خلفيات حية',
    slug: slug,
  );
}
