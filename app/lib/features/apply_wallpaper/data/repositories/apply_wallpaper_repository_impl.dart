import 'dart:convert';
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../channels/wallpaper_channel.dart';
import '../../../../core/error/failures.dart';
import '../../../clock/data/models/clock_config_model.dart';
import '../../../clock/domain/entities/clock_config_entity.dart';
import '../../../clock/data/models/studio_widget_serializer.dart';
import '../../../clock/domain/entities/studio_design_entity.dart';
import '../../../depth/domain/entities/depth_config_entity.dart';
import '../../../explore/domain/entities/wallpaper_entity.dart';
import '../../../explore/domain/entities/wallpaper_type.dart';
import '../../domain/repositories/apply_wallpaper_repository.dart';

/// Downloads the wallpaper's layers to files, then hands the file paths plus
/// the serialized clock/depth configuration to the native [WallpaperChannel].
///
/// Which image is downloaded depends on the type, and getting this wrong is
/// visible immediately:
///
///  * depth  -> the **background plate**, never the flattened original. The
///    original already contains the subject, so compositing the foreground on
///    top of it would draw the subject twice.
///  * normal -> the full-resolution image.
class ApplyWallpaperRepositoryImpl implements ApplyWallpaperRepository {
  ApplyWallpaperRepositoryImpl(this._channel, {Dio? dio}) : _dio = dio ?? Dio();

  final WallpaperChannel _channel;
  final Dio _dio;

  /// Directory the applied wallpaper's files live in for as long as it stays
  /// applied - `LiveWallpaperService`/`VideoWallpaperService` read this same
  /// path back on every engine recreation (unlock, launcher restart, reboot),
  /// which happens for the entire time the user has this wallpaper set, not
  /// just during this one apply call.
  ///
  /// This must NOT be `getTemporaryDirectory()` (the OS cache dir): Android is
  /// explicitly free to clear that at any time under storage pressure, with
  /// no notice to the app. When it does, the live wallpaper engine's next
  /// `File(path).exists()` check silently fails and it falls back to the
  /// poster/placeholder forever - exactly "opens to a static image, video
  /// never plays again" - since nothing here ever re-downloads on its own.
  /// `getApplicationSupportDirectory()` is the app's own persistent storage,
  /// which the OS does not clear behind the app's back.
  Future<Directory> _liveAssetsDir() async {
    final dir = await getApplicationSupportDirectory();
    final liveDir = Directory('${dir.path}/live_wallpaper');
    if (!await liveDir.exists()) await liveDir.create(recursive: true);
    return liveDir;
  }

  /// Removes whatever a previous apply left in [_liveAssetsDir], since only
  /// one live wallpaper can be active at a time - keeps this persistent
  /// directory from growing with every reapply.
  Future<void> _clearLiveAssetsDir(Directory dir) async {
    await for (final entity in dir.list()) {
      try {
        await entity.delete();
      } catch (_) {
        // Best-effort cleanup; a stray leftover file costs disk space, not
        // correctness - the next apply's downloads still overwrite by name.
      }
    }
  }

  @override
  Future<Either<Failure, bool>> apply({
    required WallpaperEntity wallpaper,
    required ApplyDestination destination,
    ClockConfigEntity? clockConfig,
    DepthConfigEntity? depthConfig,
    List<StudioWidget> widgets = const [],
    StudioDateWidget? dateWidget,
  }) async {
    // A type this build cannot render must fail loudly here rather than
    // silently applying a thumbnail as someone's wallpaper.
    if (!wallpaper.isRenderable) {
      return const Left(UnsupportedWallpaperFailure());
    }
    if (wallpaper.type == WallpaperType.live) {
      return _applyVideo(
        wallpaper,
        clockConfig: clockConfig,
        widgets: widgets,
        dateWidget: dateWidget,
      );
    }

    try {
      final isLive = wallpaper.isLiveApply(
        clockConfig: clockConfig,
        depthConfig: depthConfig,
      );
      // A live wallpaper's assets must survive indefinitely (see
      // `_liveAssetsDir`'s doc) - a plain static image only needs its file for
      // the duration of this call, since `WallpaperManager.setBitmap` copies
      // the bitmap internally and never reads the path again afterwards.
      final Directory dir;
      if (isLive) {
        dir = await _liveAssetsDir();
        await _clearLiveAssetsDir(dir);
      } else {
        dir = await getTemporaryDirectory();
      }
      final depthEnabled =
          (depthConfig?.enabled ?? false) && wallpaper.supportsDepth;

      // For depth, the base layer is the raw background plate - a scene
      // grade cannot be applied here without a flattened composite (see
      // `applyBackgroundUrl`'s own doc). Every other type prefers the
      // backend's own graded `STYLED_PREVIEW` when one was baked, so the
      // applied wallpaper's background matches what Details already showed
      // rather than reverting to the flat, ungraded original.
      final backgroundUrl = depthEnabled
          ? wallpaper.compositeBackgroundUrl
          : wallpaper.applyBackgroundUrl;
      if (backgroundUrl.isEmpty) {
        return const Left(WallpaperApplyFailure(
          'This wallpaper has no image to apply.',
        ));
      }

      final imagePath = '${dir.path}/apply_bg_${wallpaper.id}.jpg';
      await _dio.download(backgroundUrl, imagePath);

      String? maskPath;
      if (depthEnabled) {
        // The user explicitly turned the depth effect on, so its cut-out
        // foreground is no longer optional here - silently applying a flat
        // background+clock wallpaper instead would leave them thinking depth
        // is on when it never actually rendered. A capability check
        // (`wallpaper.supportsDepth`, already required for `depthEnabled` to
        // be true above) is not the same guarantee as "the file is still
        // reachable right now"; either gap must fail loudly here.
        final foreground = wallpaper.foregroundMaskUrl;
        if (foreground == null || foreground.isEmpty) {
          return const Left(DepthForegroundMissingFailure());
        }
        maskPath = '${dir.path}/apply_mask_${wallpaper.id}.png';
        try {
          await _dio.download(foreground, maskPath);
        } on DioException {
          return const Left(DepthForegroundMissingFailure());
        }
      }

      final clockJson = clockConfig == null
          ? null
          : jsonEncode(ClockConfigModel.fromEntity(clockConfig).toJson());

      final depthJson = _depthRenderJson(wallpaper);

      final success = await _channel.applyWallpaper(
        imagePath: imagePath,
        destination: destination,
        clockConfigJson: clockJson,
        depthEnabled: maskPath != null,
        maskPath: maskPath,
        depthConfigJson: depthJson,
        widgetsJson: StudioWidgetSerializer.toJson(widgets),
        dateWidgetJson: StudioWidgetSerializer.dateToJson(dateWidget),
      );
      return success ? const Right(true) : const Left(WallpaperApplyFailure());
    } on DioException {
      return const Left(NoInternetFailure());
    } catch (_) {
      return const Left(WallpaperApplyFailure());
    }
  }

  /// Applies a looping video wallpaper.
  ///
  /// The clip is downloaded here and handed to native as a file path; the
  /// poster goes with it so the engine has something to paint if playback ever
  /// fails. Flutter never touches a video frame - the whole pipeline is native.
  ///
  /// [clockConfig], when the user customized one, is serialized the same way
  /// as the static/depth path and handed to native too - a video wallpaper's
  /// engine composites it over the decoded frames itself (see
  /// `VideoWallpaperService.kt`); Flutter's job ends at handing over the JSON.
  Future<Either<Failure, bool>> _applyVideo(
    WallpaperEntity wallpaper, {
    ClockConfigEntity? clockConfig,
    List<StudioWidget> widgets = const [],
    StudioDateWidget? dateWidget,
  }) async {
    final video = wallpaper.video;
    if (video == null || video.url.isEmpty) {
      return const Left(WallpaperApplyFailure(
        'This video wallpaper is missing its clip.',
      ));
    }
    try {
      // Always the live path - see `_liveAssetsDir`'s doc.
      final dir = await _liveAssetsDir();
      await _clearLiveAssetsDir(dir);
      final videoPath = '${dir.path}/apply_video_${wallpaper.id}.mp4';
      await _dio.download(video.url, videoPath);

      // Best-effort poster: a failure here must not block the wallpaper.
      String? posterPath;
      final posterUrl = wallpaper.thumbnailUrl;
      if (posterUrl.isNotEmpty) {
        posterPath = '${dir.path}/apply_poster_${wallpaper.id}.jpg';
        try {
          await _dio.download(posterUrl, posterPath);
        } on DioException {
          posterPath = null;
        }
      }

      final clockJson = clockConfig == null
          ? null
          : jsonEncode(ClockConfigModel.fromEntity(clockConfig).toJson());

      final ok = await _channel.applyVideoWallpaper(
        videoPath: videoPath,
        posterPath: posterPath,
        clockConfigJson: clockJson,
        widgetsJson: StudioWidgetSerializer.toJson(widgets),
        dateWidgetJson: StudioWidgetSerializer.dateToJson(dateWidget),
      );
      return ok
          ? const Right(true)
          : const Left(UnsupportedWallpaperFailure(
              'This device has no live wallpaper picker, so video wallpapers '
              'cannot be applied here.',
            ));
    } on DioException {
      return const Left(NoInternetFailure());
    } catch (_) {
      return const Left(WallpaperApplyFailure());
    }
  }

  /// Serializes the backend-authored foreground transform for the native
  /// compositor. Null when the wallpaper carried no depth configuration, in
  /// which case native falls back to the identity transform.
  String? _depthRenderJson(WallpaperEntity wallpaper) {
    final config = wallpaper.depthRenderConfig;
    if (config == null) return null;
    return jsonEncode({
      'foregroundScale': config.foregroundScale,
      'foregroundOffsetX': config.foregroundOffsetX,
      'foregroundOffsetY': config.foregroundOffsetY,
      'blurRadius': config.blurRadius,
      'shadowStrength': config.shadowStrength,
    });
  }
}
