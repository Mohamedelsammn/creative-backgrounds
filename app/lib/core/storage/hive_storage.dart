import 'package:hive_flutter/hive_flutter.dart';

import 'storage_keys.dart';

/// Typed façade over Hive. All boxes are opened once at startup so callers can
/// read/write synchronously without awaiting `openBox` on every access.
class HiveStorage {
  /// Opens every box declared in [HiveBoxes.all]. Call after
  /// `Hive.initFlutter()` and before `setupDI()`.
  static Future<void> init() async {
    for (final name in HiveBoxes.all) {
      if (!Hive.isBoxOpen(name)) {
        await Hive.openBox(name);
      }
    }
  }

  Box _box(String name) => Hive.box(name);

  /// Drops cached API pages when the data source changed since last launch
  /// (fixtures <-> live backend).
  ///
  /// Without this, switching `MOCK_API` shows stale content from the previous
  /// source until each TTL expires, which looks exactly like the new source
  /// being broken.
  Future<void> invalidateCacheIfSourceChanged({required bool mockApi}) async {
    final current = mockApi ? 'mock' : 'live';
    final previous =
        read<String>(HiveBoxes.cacheMetadata, StorageKeys.cacheSourceStamp);
    if (previous == current) return;
    await clearBox(HiveBoxes.cacheMetadata);
    await write(
      HiveBoxes.cacheMetadata,
      StorageKeys.cacheSourceStamp,
      current,
    );
  }

  T? read<T>(String box, String key, {T? defaultValue}) {
    return _box(box).get(key, defaultValue: defaultValue) as T?;
  }

  Future<void> write(String box, String key, Object? value) {
    return _box(box).put(key, value);
  }

  Future<void> delete(String box, String key) {
    return _box(box).delete(key);
  }

  Future<int> clearBox(String box) {
    return _box(box).clear();
  }

  Iterable<dynamic> values(String box) => _box(box).values;

  Iterable<dynamic> keys(String box) => _box(box).keys;

  bool containsKey(String box, String key) => _box(box).containsKey(key);

  /// Emits on every change to [box] (put/delete/clear). Used for live UI sync,
  /// e.g. keeping the Favorites grid in step with toggles elsewhere.
  Stream<BoxEvent> watch(String box) => _box(box).watch();
}
