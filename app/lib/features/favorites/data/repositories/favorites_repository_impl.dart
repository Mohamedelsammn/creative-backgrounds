import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../explore/data/models/model_mappers.dart';
import '../../../explore/domain/entities/wallpaper_entity.dart';
import '../../domain/repositories/favorites_repository.dart';
import '../datasources/favorites_local_datasource.dart';

class FavoritesRepositoryImpl implements FavoritesRepository {
  FavoritesRepositoryImpl(this._local);

  final FavoritesLocalDatasource _local;

  @override
  Future<Either<Failure, List<WallpaperEntity>>> getFavorites() async {
    try {
      final favorites = _local.getFavorites().map((m) => m.toEntity()).toList();
      return Right(favorites);
    } catch (_) {
      return const Left(CacheFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> addFavorite(WallpaperEntity wallpaper) async {
    try {
      await _local.addFavorite(wallpaper.toModel());
      return const Right(unit);
    } catch (_) {
      return const Left(CacheFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> removeFavorite(String wallpaperId) async {
    try {
      await _local.removeFavorite(wallpaperId);
      return const Right(unit);
    } catch (_) {
      return const Left(CacheFailure());
    }
  }

  @override
  bool isFavorite(String wallpaperId) => _local.isFavorite(wallpaperId);

  @override
  Stream<void> watchChanges() => _local.watch();
}
