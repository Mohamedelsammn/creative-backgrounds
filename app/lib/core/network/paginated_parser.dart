import '../pagination/paginated.dart';

/// Parses the API's `{ data: [...], meta: { page, hasMore, total } }` envelope.
Paginated<T> parsePaginatedResponse<T>(
  Map<String, dynamic> body,
  T Function(Map<String, dynamic>) fromJson,
) {
  final data = (body['data'] as List? ?? const [])
      .map((e) => fromJson(e as Map<String, dynamic>))
      .toList();
  final meta = body['meta'] as Map<String, dynamic>? ?? const {};
  return Paginated<T>(
    items: data,
    page: (meta['page'] as num?)?.toInt() ?? 1,
    hasMore: meta['hasMore'] as bool? ?? false,
    total: (meta['total'] as num?)?.toInt() ?? data.length,
  );
}
