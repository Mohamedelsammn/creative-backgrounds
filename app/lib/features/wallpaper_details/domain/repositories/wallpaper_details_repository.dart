import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../explore/domain/entities/wallpaper_entity.dart';

abstract class WallpaperDetailsRepository {
  /// [idOrSlug] accepts either identifier - the API route takes both, so a
  /// deep link by slug resolves the same way a tap from a list does.
  Future<Either<Failure, WallpaperEntity>> getWallpaperDetails(String idOrSlug);

  /// Records a view for analytics. Fire-and-forget: never throws, never
  /// blocks the screen.
  Future<void> recordView(String idOrSlug);
}
