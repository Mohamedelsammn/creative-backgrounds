import 'package:dartz/dartz.dart';

import '../../../../core/error/error_handler.dart';
import '../../../../core/error/failures.dart';
import '../../../explore/domain/entities/wallpaper_entity.dart';
import '../../domain/repositories/wallpaper_details_repository.dart';
import '../datasources/wallpaper_details_remote_datasource.dart';

class WallpaperDetailsRepositoryImpl implements WallpaperDetailsRepository {
  WallpaperDetailsRepositoryImpl(this._remote);

  final WallpaperDetailsRemoteDatasource _remote;

  @override
  Future<Either<Failure, WallpaperEntity>> getWallpaperDetails(String id) async {
    try {
      final model = await _remote.getWallpaperDetails(id);
      return Right(model.toEntity());
    } catch (e) {
      return Left(ErrorHandler.mapExceptionToFailure(e));
    }
  }
}
