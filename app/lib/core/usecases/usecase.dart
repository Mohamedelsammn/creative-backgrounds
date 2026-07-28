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
class PageParams extends Equatable {
  const PageParams({this.page = 1});
  final int page;

  @override
  List<Object?> get props => [page];
}
