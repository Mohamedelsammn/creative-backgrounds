import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../explore/domain/entities/wallpaper_entity.dart';

/// Favorites are stored locally in Hive (no remote sync in V1).
abstract class FavoritesRepository {
  Future<Either<Failure, List<WallpaperEntity>>> getFavorites();
  Future<Either<Failure, Unit>> addFavorite(WallpaperEntity wallpaper);
  Future<Either<Failure, Unit>> removeFavorite(String wallpaperId);
  bool isFavorite(String wallpaperId);

  /// Emits whenever the favorites store changes (for live UI sync).
  Stream<void> watchChanges();
}
