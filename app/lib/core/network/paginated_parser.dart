import '../pagination/paginated.dart';

/// Parses any of the envelopes the API returns into a [Paginated].
///
/// Three shapes are accepted, because the backend uses different ones per
/// endpoint and we must never crash on the wrong guess:
///
///  * keyset  — `{ data: [...], meta: { nextCursor, hasMore } }`  (public feed)
///  * offset  — `{ data: [...], meta: { page, pageSize, total, totalPages } }`
///  * unwrapped — `{ data: [...] }` with no meta at all (public search/related)
///
/// A malformed or absent `data` yields an empty page rather than throwing:
/// a single bad row must not take down a whole screen, so rows that fail to
/// parse are skipped and the rest are kept.
Paginated<T> parsePaginatedResponse<T>(
  Map<String, dynamic> body,
  T Function(Map<String, dynamic>) fromJson, {
  int requestedPage = 1,
}) {
  final items = parseDataList(body, fromJson);
  final meta = body['meta'] as Map<String, dynamic>? ?? const {};

  final nextCursor = meta['nextCursor'] as String?;
  final page = (meta['page'] as num?)?.toInt() ?? requestedPage;
  final total = (meta['total'] as num?)?.toInt() ?? items.length;

  // `hasMore` is authoritative when present. Otherwise infer it: a cursor
  // implies more, and an offset envelope implies more while we are short of
  // `totalPages`. With no meta at all (search) there is nothing more to fetch.
  final bool hasMore;
  if (meta['hasMore'] is bool) {
    hasMore = meta['hasMore'] as bool;
  } else if (nextCursor != null && nextCursor.isNotEmpty) {
    hasMore = true;
  } else {
    final totalPages = (meta['totalPages'] as num?)?.toInt();
    hasMore = totalPages != null && page < totalPages;
  }

  return Paginated<T>(
    items: items,
    page: page,
    hasMore: hasMore,
    total: total,
    nextCursor: (nextCursor?.isEmpty ?? true) ? null : nextCursor,
  );
}

/// Reads the `data` array out of an envelope (or accepts a bare array) and maps
/// each row, skipping any row that fails to parse.
List<T> parseDataList<T>(
  Object? body,
  T Function(Map<String, dynamic>) fromJson,
) {
  final raw = switch (body) {
    List<dynamic> list => list,
    Map<String, dynamic> map => map['data'] as List<dynamic>? ?? const [],
    _ => const <dynamic>[],
  };

  final out = <T>[];
  for (final row in raw) {
    if (row is! Map) continue;
    try {
      out.add(fromJson(Map<String, dynamic>.from(row)));
    } catch (_) {
      // Skip the malformed row; the rest of the page is still useful.
    }
  }
  return out;
}
