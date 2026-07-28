import '../entities/clock_config_entity.dart';

abstract class ClockRepository {
  /// Returns the saved config, or the default if none is persisted.
  Future<ClockConfigEntity> loadClockConfig();

  /// Persists to Hive and syncs to the native side via the clock channel.
  Future<void> saveClockConfig(ClockConfigEntity config);
}
