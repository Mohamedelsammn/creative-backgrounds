import 'dart:io';

import 'package:flutter/painting.dart' show PaintingBinding;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/storage/hive_storage.dart';
import '../../../../core/storage/storage_keys.dart';
import '../../domain/entities/app_settings.dart';

/// Persists settings in the Hive `settings` box and computes/clears the app's
/// image + metadata cache.
abstract class SettingsLocalDatasource {
  Future<AppSettings> getSettings();
  Future<void> setLanguage(String language);

  /// Clears the image disk cache + Hive cache metadata; returns freed bytes.
  Future<int> clearCache();
}

class SettingsLocalDatasourceImpl implements SettingsLocalDatasource {
  SettingsLocalDatasourceImpl(this._storage);

  final HiveStorage _storage;

  @override
  Future<AppSettings> getSettings() async {
    final language =
        _storage.read<String>(HiveBoxes.settings, StorageKeys.language) ?? 'en';
    final version = await _appVersion();
    final size = await _computeCacheSize();

    return AppSettings(
      language: language,
      cachedSizeBytes: size,
      appVersion: version,
    );
  }

  @override
  Future<void> setLanguage(String language) =>
      _storage.write(HiveBoxes.settings, StorageKeys.language, language);

  @override
  Future<int> clearCache() async {
    final before = await _computeCacheSize();
    // In-memory image cache.
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    // On-disk cached_network_image store.
    final dir = await _imageCacheDir();
    if (dir != null && dir.existsSync()) {
      await dir.delete(recursive: true);
    }
    // Hive cache metadata.
    await _storage.clearBox(HiveBoxes.cacheMetadata);
    return before;
  }

  Future<String> _appVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version;
    } catch (_) {
      return '1.0.0';
    }
  }

  Future<Directory?> _imageCacheDir() async {
    try {
      final tmp = await getTemporaryDirectory();
      return Directory('${tmp.path}/libCachedImageData');
    } catch (_) {
      return null;
    }
  }

  Future<int> _computeCacheSize() async {
    try {
      final tmp = await getTemporaryDirectory();
      return _dirSize(tmp);
    } catch (_) {
      return 0;
    }
  }

  int _dirSize(Directory dir) {
    var total = 0;
    if (!dir.existsSync()) return 0;
    for (final entity in dir.listSync(recursive: true, followLinks: false)) {
      if (entity is File) {
        // A file can vanish (or become unreadable) between listSync()
        // enumerating it and lengthSync() reading it - this is only a
        // best-effort cache-size estimate for a settings screen, so skip
        // that one file rather than failing the whole size calculation.
        try {
          total += entity.lengthSync();
        } catch (_) {}
      }
    }
    return total;
  }
}
