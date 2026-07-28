import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/repositories/settings_repository.dart';
import '../datasources/settings_local_datasource.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl(this._local);

  final SettingsLocalDatasource _local;

  @override
  Future<Either<Failure, AppSettings>> getSettings() =>
      _guard(() => _local.getSettings());

  @override
  Future<Either<Failure, AppSettings>> setLanguage(String language) =>
      _guard(() async {
        await _local.setLanguage(language);
        return _local.getSettings();
      });

  @override
  Future<Either<Failure, AppSettings>> clearCache() => _guard(() async {
        await _local.clearCache();
        return _local.getSettings();
      });

  Future<Either<Failure, AppSettings>> _guard(
    Future<AppSettings> Function() action,
  ) async {
    try {
      return Right(await action());
    } catch (_) {
      return const Left(CacheFailure());
    }
  }
}
