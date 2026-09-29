import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/compatibility_report.dart';
import '../entities/tw_permissions.dart';
import '../entities/tw_settings.dart';
import '../entities/tw_status.dart';

/// Boundary over the native transparent-wallpaper channel. All device/camera
/// authority lives natively; this repository only forwards commands and maps
/// channel/platform errors into [Failure]s.
abstract class TransparentWallpaperRepository {
  Future<Either<Failure, CompatibilityReport>> checkCompatibility();

  Future<Either<Failure, TwPermissions>> getPermissionStatus();
  Future<Either<Failure, TwPermissions>> requestPermissions();
  Future<Either<Failure, bool>> openAppSettings();
  Future<Either<Failure, bool>> openBatterySettings();

  Future<Either<Failure, Unit>> start();
  Future<Either<Failure, Unit>> stop();
  Future<Either<Failure, Unit>> pause();
  Future<Either<Failure, Unit>> resume();
  Future<Either<Failure, Unit>> restorePreviousWallpaper();

  Future<Either<Failure, TwRuntimeState>> status();

  /// Reconciles native state with the actual system wallpaper and returns the
  /// reconciled snapshot. Called whenever the app returns to the foreground -
  /// the only moment the outcome of the system picker becomes knowable.
  Future<Either<Failure, TwRuntimeState>> syncWithSystem();

  /// Emits every native state change (emits the current state on listen).
  Stream<TwRuntimeState> watchStatus();

  /// Whether the user has accepted the camera prominent disclosure (Play
  /// requirement — must be shown before any camera access).
  bool isDisclosureAccepted();
  Future<void> setDisclosureAccepted();

  Future<Either<Failure, TwSettings>> getSettings();
  Future<Either<Failure, Unit>> updateSettings(TwSettings settings);
}
