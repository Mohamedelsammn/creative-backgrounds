import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../channels/wallpaper_channel.dart';
import '../../../../core/error/failures.dart';
import '../../../clock/data/models/clock_config_model.dart';
import '../../../clock/domain/entities/clock_config_entity.dart';
import '../../../depth/domain/entities/depth_config_entity.dart';
import '../../../explore/domain/entities/wallpaper_entity.dart';
import '../../domain/repositories/apply_wallpaper_repository.dart';

/// Downloads the wallpaper (and mask, if depth) to files, then hands the file
/// paths + serialized clock config to the native [WallpaperChannel].
class ApplyWallpaperRepositoryImpl implements ApplyWallpaperRepository {
  ApplyWallpaperRepositoryImpl(this._channel) : _dio = Dio();

  final WallpaperChannel _channel;
  final Dio _dio;

  @override
  Future<Either<Failure, bool>> apply({
    required WallpaperEntity wallpaper,
    required ApplyDestination destination,
    ClockConfigEntity? clockConfig,
    DepthConfigEntity? depthConfig,
  }) async {
    try {
      final dir = await getTemporaryDirectory();
      final imagePath = '${dir.path}/apply_bg_${wallpaper.id}.jpg';
      await _dio.download(wallpaper.fullUrl, imagePath);

      final depthEnabled = depthConfig?.enabled ?? false;
      String? maskPath;
      if (depthEnabled && (wallpaper.foregroundMaskUrl?.isNotEmpty ?? false)) {
        maskPath = '${dir.path}/apply_mask_${wallpaper.id}.png';
        await _dio.download(wallpaper.foregroundMaskUrl!, maskPath);
      }

      final clockJson = clockConfig == null
          ? null
          : jsonEncode(ClockConfigModel.fromEntity(clockConfig).toJson());

      final success = await _channel.applyWallpaper(
        imagePath: imagePath,
        destination: destination,
        clockConfigJson: clockJson,
        depthEnabled: depthEnabled,
        maskPath: maskPath,
      );
      return success
          ? const Right(true)
          : const Left(WallpaperApplyFailure());
    } on DioException {
      return const Left(NoInternetFailure());
    } catch (_) {
      return const Left(WallpaperApplyFailure());
    }
  }
}
