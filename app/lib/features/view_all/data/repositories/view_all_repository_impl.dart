import 'package:dartz/dartz.dart';

import '../../../../core/error/error_handler.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/pagination/paginated.dart';
import '../../../explore/domain/entities/wallpaper_entity.dart';
import '../../domain/entities/view_all_options.dart';
import '../../domain/repositories/view_all_repository.dart';
import '../datasources/view_all_remote_datasource.dart';

class ViewAllRepositoryImpl implements ViewAllRepository {
  ViewAllRepositoryImpl(this._remote);

  final ViewAllRemoteDatasource _remote;

  @override
  Future<Either<Failure, Paginated<WallpaperEntity>>> getSectionWallpapers({
    required String section,
    int page = 1,
    FilterOptions? filter,
    SortOption? sort,
  }) async {
    try {
      final result = await _remote.getSectionWallpapers(
        section: section,
        page: page,
        filter: filter,
        sort: sort,
      );
      return Right(Paginated<WallpaperEntity>(
        items: result.items.map((m) => m.toEntity()).toList(),
        page: result.page,
        hasMore: result.hasMore,
        total: result.total,
      ));
    } catch (e) {
      return Left(ErrorHandler.mapExceptionToFailure(e));
    }
  }
}
