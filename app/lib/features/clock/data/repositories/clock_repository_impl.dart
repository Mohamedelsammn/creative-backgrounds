import 'dart:convert';

import '../../../../channels/clock_channel.dart';
import '../../../../core/storage/hive_storage.dart';
import '../../../../core/storage/storage_keys.dart';
import '../../domain/entities/clock_config_entity.dart';
import '../../domain/repositories/clock_repository.dart';
import '../models/clock_config_model.dart';

class ClockRepositoryImpl implements ClockRepository {
  ClockRepositoryImpl(this._storage, this._channel);

  final HiveStorage _storage;
  final ClockChannel _channel;

  @override
  Future<ClockConfigEntity> loadClockConfig() async {
    final raw =
        _storage.read<String>(HiveBoxes.clockConfig, StorageKeys.clockConfig);
    if (raw == null) return const ClockConfigEntity();
    try {
      return ClockConfigModel.fromJson(jsonDecode(raw) as Map<String, dynamic>)
          .toEntity();
    } catch (_) {
      return const ClockConfigEntity();
    }
  }

  @override
  Future<void> saveClockConfig(ClockConfigEntity config) async {
    final model = ClockConfigModel.fromEntity(config);
    final json = model.toJson();
    await _storage.write(
      HiveBoxes.clockConfig,
      StorageKeys.clockConfig,
      jsonEncode(json),
    );
    // Sync to native (fails soft if not registered).
    await _channel.saveClockConfig(json);
  }
}
