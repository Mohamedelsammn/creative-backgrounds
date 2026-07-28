import 'package:equatable/equatable.dart';

/// Generic page of results plus pagination metadata, mirroring the API's
/// `{ data, meta: { page, limit, total, hasMore } }` envelope.
class Paginated<T> extends Equatable {
  const Paginated({
    required this.items,
    required this.page,
    required this.hasMore,
    this.total = 0,
  });

  final List<T> items;
  final int page;
  final bool hasMore;
  final int total;

  const Paginated.empty()
      : items = const [],
        page = 1,
        hasMore = false,
        total = 0;

  Paginated<T> copyWithAppended(List<T> more, {required int page, required bool hasMore}) {
    return Paginated<T>(
      items: [...items, ...more],
      page: page,
      hasMore: hasMore,
      total: total,
    );
  }

  @override
  List<Object?> get props => [items, page, hasMore, total];
}
