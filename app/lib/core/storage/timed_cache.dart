import 'dart:convert';

import 'hive_storage.dart';

/// A decoded cache payload plus whether it is still within its TTL.
typedef CacheRead = ({Object? data, bool fresh});

/// Small helper for timestamped JSON cache entries stored in Hive.
/// Wraps the cached value as `{ "ts": epochMs, "data": <json> }`.
class TimedCache {
  TimedCache(this._storage);

  final HiveStorage _storage;

  void write(String box, String key, Object? jsonData) {
    _storage.write(
      box,
      key,
      jsonEncode({'ts': DateTime.now().millisecondsSinceEpoch, 'data': jsonData}),
    );
  }

  /// Returns the decoded payload and freshness, or null if nothing is cached.
  CacheRead? read(String box, String key, Duration ttl) {
    final raw = _storage.read<String>(box, key);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final ts = (map['ts'] as num?)?.toInt() ?? 0;
      final age = DateTime.now().millisecondsSinceEpoch - ts;
      return (data: map['data'], fresh: age < ttl.inMilliseconds);
    } catch (_) {
      return null;
    }
  }
}
