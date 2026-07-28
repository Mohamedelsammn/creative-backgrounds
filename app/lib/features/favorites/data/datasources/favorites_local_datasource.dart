import 'dart:convert';

import '../../../../core/storage/hive_storage.dart';
import '../../../../core/storage/storage_keys.dart';
import '../../../explore/data/models/wallpaper_model.dart';

/// Reads/writes favorites in the Hive `favorites` box, keyed by wallpaper id
/// with the serialized wallpaper JSON as value.
abstract class FavoritesLocalDatasource {
  List<WallpaperModel> getFavorites();
  Future<void> addFavorite(WallpaperModel wallpaper);
  Future<void> removeFavorite(String wallpaperId);
  bool isFavorite(String wallpaperId);
  Stream<void> watch();
}

class FavoritesLocalDatasourceImpl implements FavoritesLocalDatasource {
  FavoritesLocalDatasourceImpl(this._storage);

  final HiveStorage _storage;

  @override
  List<WallpaperModel> getFavorites() {
    final raw = _storage.values(HiveBoxes.favorites).toList();
    final result = <WallpaperModel>[];
    for (final entry in raw) {
      try {
        final map = jsonDecode(entry as String) as Map<String, dynamic>;
        result.add(WallpaperModel.fromJson(map));
      } catch (_) {
        // Skip corrupt entries.
      }
    }
    // Most recently added first.
    return result.reversed.toList();
  }

  @override
  Future<void> addFavorite(WallpaperModel wallpaper) {
    return _storage.write(
      HiveBoxes.favorites,
      wallpaper.id,
      jsonEncode(wallpaper.toJson()),
    );
  }

  @override
  Future<void> removeFavorite(String wallpaperId) {
    return _storage.delete(HiveBoxes.favorites, wallpaperId);
  }

  @override
  bool isFavorite(String wallpaperId) {
    return _storage.containsKey(HiveBoxes.favorites, wallpaperId);
  }

  @override
  Stream<void> watch() => _storage.watch(HiveBoxes.favorites);
}
