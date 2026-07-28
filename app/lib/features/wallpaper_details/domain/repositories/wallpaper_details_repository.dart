import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../explore/domain/entities/wallpaper_entity.dart';

abstract class WallpaperDetailsRepository {
  Future<Either<Failure, WallpaperEntity>> getWallpaperDetails(String id);
}
