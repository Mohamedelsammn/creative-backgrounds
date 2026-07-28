import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/app_settings.dart';

abstract class SettingsRepository {
  Future<Either<Failure, AppSettings>> getSettings();
  Future<Either<Failure, AppSettings>> setLanguage(String language);

  /// Clears cache and returns settings with the recomputed size.
  Future<Either<Failure, AppSettings>> clearCache();
}
