import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/pagination/paginated.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../explore/domain/entities/wallpaper_entity.dart';
import '../entities/view_all_options.dart';
import '../repositories/view_all_repository.dart';

class GetSectionWallpapersUseCase
    implements UseCase<Paginated<WallpaperEntity>, SectionParams> {
  GetSectionWallpapersUseCase(this._repository);

  final ViewAllRepository _repository;

  @override
  Future<Either<Failure, Paginated<WallpaperEntity>>> call(
      SectionParams params) {
    return _repository.getSectionWallpapers(
      section: params.section,
      page: params.page,
      filter: params.filter,
      sort: params.sort,
    );
  }
}

class SectionParams extends Equatable {
  const SectionParams({
    required this.section,
    this.page = 1,
    this.filter,
    this.sort,
  });

  final String section;
  final int page;
  final FilterOptions? filter;
  final SortOption? sort;

  @override
  List<Object?> get props => [section, page, filter, sort];
}
