import 'package:equatable/equatable.dart';

/// Generic page of results plus pagination metadata.
///
/// The public API paginates the feed by **keyset cursor**
/// (`meta: { nextCursor, hasMore }`), while cached/fixture data and the
/// admin-style envelope use **offset** pages (`meta: { page, pageSize, total }`).
/// Both are represented here so callers can stay agnostic: continue a listing
/// with [nextCursor] when it is non-null, otherwise fall back to [page] + 1.
class Paginated<T> extends Equatable {
  const Paginated({
    required this.items,
    required this.page,
    required this.hasMore,
    this.total = 0,
    this.nextCursor,
  });

  final List<T> items;

  /// 1-based offset page. Always populated; synthesized as `1` for cursor
  /// responses, which carry no page number of their own.
  final int page;

  final bool hasMore;

  /// Total matching rows when the server reports one. Cursor responses do not,
  /// in which case this is the number of items seen so far — never trust it as
  /// a grand total unless the envelope actually supplied it.
  final int total;

  /// Opaque keyset cursor for the next page, or null when the server paginates
  /// by offset (or there is nothing more to fetch).
  final String? nextCursor;

  const Paginated.empty()
      : items = const [],
        page = 1,
        hasMore = false,
        total = 0,
        nextCursor = null;

  Paginated<T> copyWithAppended(
    List<T> more, {
    required int page,
    required bool hasMore,
    String? nextCursor,
  }) {
    return Paginated<T>(
      items: [...items, ...more],
      page: page,
      hasMore: hasMore,
      total: total,
      nextCursor: nextCursor,
    );
  }

  Paginated<R> map<R>(R Function(T) f) => Paginated<R>(
        items: items.map(f).toList(),
        page: page,
        hasMore: hasMore,
        total: total,
        nextCursor: nextCursor,
      );

  @override
  List<Object?> get props => [items, page, hasMore, total, nextCursor];
}
