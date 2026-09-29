import 'package:dartz/dartz.dart';

import '../../../../channels/transparent_wallpaper_channel.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/storage/hive_storage.dart';
import '../../../../core/storage/storage_keys.dart';
import '../../domain/entities/compatibility_report.dart';
import '../../domain/entities/tw_permissions.dart';
import '../../domain/entities/tw_settings.dart';
import '../../domain/entities/tw_status.dart';
import '../../domain/repositories/transparent_wallpaper_repository.dart';

/// Forwards to [TransparentWallpaperChannel]; any platform exception becomes a
/// [WallpaperApplyFailure] so the UI can show a safe, recoverable message.
class TransparentWallpaperRepositoryImpl
    implements TransparentWallpaperRepository {
  TransparentWallpaperRepositoryImpl(this._channel, this._storage);

  final TransparentWallpaperChannel _channel;
  final HiveStorage _storage;

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Right(await action());
    } catch (e) {
      return Left(WallpaperApplyFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, CompatibilityReport>> checkCompatibility() =>
      _guard(_channel.checkCompatibility);

  @override
  Future<Either<Failure, TwPermissions>> getPermissionStatus() =>
      _guard(_channel.getPermissionStatus);

  @override
  Future<Either<Failure, TwPermissions>> requestPermissions() =>
      _guard(_channel.requestPermissions);

  @override
  Future<Either<Failure, bool>> openAppSettings() =>
      _guard(_channel.openAppSettings);

  @override
  Future<Either<Failure, bool>> openBatterySettings() =>
      _guard(_channel.openBatterySettings);

  @override
  Future<Either<Failure, Unit>> start() =>
      _guard(() async { await _channel.start(); return unit; });

  @override
  Future<Either<Failure, Unit>> stop() =>
      _guard(() async { await _channel.stop(); return unit; });

  @override
  Future<Either<Failure, Unit>> pause() =>
      _guard(() async { await _channel.pause(); return unit; });

  @override
  Future<Either<Failure, Unit>> resume() =>
      _guard(() async { await _channel.resume(); return unit; });

  @override
  Future<Either<Failure, Unit>> restorePreviousWallpaper() =>
      _guard(() async { await _channel.restorePreviousWallpaper(); return unit; });

  @override
  Future<Either<Failure, TwRuntimeState>> syncWithSystem() =>
      _guard(_channel.syncWithSystem);

  @override
  Future<Either<Failure, TwRuntimeState>> status() => _guard(_channel.status);

  @override
  Stream<TwRuntimeState> watchStatus() => _channel.statusStream();

  @override
  bool isDisclosureAccepted() => _storage.read<bool>(
        HiveBoxes.settings,
        StorageKeys.transparentDisclosureAccepted,
        defaultValue: false,
      ) ??
      false;

  @override
  Future<void> setDisclosureAccepted() => _storage.write(
        HiveBoxes.settings,
        StorageKeys.transparentDisclosureAccepted,
        true,
      );

  @override
  Future<Either<Failure, TwSettings>> getSettings() =>
      _guard(() async => TwSettings(fps: await _channel.getFps()));

  @override
  Future<Either<Failure, Unit>> updateSettings(TwSettings settings) =>
      _guard(() async {
        await _channel.updateFps(settings.fps);
        return unit;
      });
}
