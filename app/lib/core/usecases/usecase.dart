import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../error/failures.dart';

/// Base contract for a single-responsibility use case.
abstract class UseCase<T, Params> {
  Future<Either<Failure, T>> call(Params params);
}

/// For use cases that take no parameters.
class NoParams extends Equatable {
  const NoParams();

  @override
  List<Object?> get props => [];
}

/// Common params for paginated fetches.
///
/// The public feed is keyset paginated, so [cursor] is the field that actually
/// advances a listing; [page] is retained for the fixture-backed datasources,
/// which paginate by offset.
class PageParams extends Equatable {
  const PageParams({this.page = 1, this.cursor, this.forceRefresh = false});

  final int page;

  /// The previous page's `nextCursor`, or null for the first page.
  final String? cursor;

  /// Bypasses (and then rewrites) a cached first page - set for
  /// pull-to-refresh so newly published or unpublished content shows up
  /// without waiting out the cache TTL. Meaningless for a non-first page.
  final bool forceRefresh;

  @override
  List<Object?> get props => [page, cursor, forceRefresh];
}
