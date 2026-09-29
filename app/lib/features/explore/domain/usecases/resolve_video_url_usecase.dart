import '../entities/wallpaper_entity.dart';
import '../entities/wallpaper_type.dart';
import '../repositories/explore_repository.dart';

/// Resolves the looping clip URL for a live wallpaper.
///
/// ## Why this exists
///
/// The backend can include the `video` object directly on a feed row; when it
/// does, [call] returns it immediately with no request at all. Older/other
/// feed shapes may still omit it (only `GET /wallpapers/{idOrSlug}` is
/// guaranteed to carry it), so a fallback is still needed for that case.
///
/// Rather than firing a detail request per card while scrolling, that fallback
/// resolution is:
///  * **lazy** - requested only when a card actually becomes visible and is
///    about to play;
///  * **cached in memory** for the session, so scrolling back never refetches;
///  * **deduplicated** - concurrent callers for the same id share one request.
///
/// Returns null for anything that is not a live wallpaper, and on any failure:
/// the caller then simply shows the poster, which is the correct degradation.
class ResolveVideoUrlUseCase {
  ResolveVideoUrlUseCase(this._repository);

  final ExploreRepository _repository;

  /// Resolved clip URLs by wallpaper id. A null value is a remembered miss, so
  /// a wallpaper whose detail carries no clip is not retried on every scroll.
  final Map<String, String?> _cache = {};

  /// In-flight requests, so two visible cards for the same wallpaper issue one.
  final Map<String, Future<String?>> _inFlight = {};

  Future<String?> call(WallpaperEntity wallpaper) {
    if (wallpaper.type != WallpaperType.live) return Future.value(null);

    // Already on the entity (details already loaded it) - nothing to do.
    final existing = wallpaper.video?.url;
    if (existing != null && existing.isNotEmpty) return Future.value(existing);

    final id = wallpaper.id;
    if (_cache.containsKey(id)) return Future.value(_cache[id]);

    return _inFlight[id] ??= _fetch(id);
  }

  Future<String?> _fetch(String id) async {
    try {
      final result = await _repository.getWallpaperVideoUrl(id);
      final url = result.fold((_) => null, (u) => u);
      _cache[id] = url;
      return url;
    } finally {
      _inFlight.remove(id);
    }
  }

  /// Drops memoised results. Used when the catalog is refreshed.
  void clear() {
    _cache.clear();
    _inFlight.clear();
  }
}
