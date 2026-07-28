import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/pagination/paginated.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../explore/domain/entities/wallpaper_entity.dart';
import '../repositories/search_repository.dart';

class SearchWallpapersUseCase
    implements UseCase<Paginated<WallpaperEntity>, SearchParams> {
  SearchWallpapersUseCase(this._repository);

  final SearchRepository _repository;

  @override
  Future<Either<Failure, Paginated<WallpaperEntity>>> call(SearchParams params) {
    return _repository.search(params.query, page: params.page);
  }
}

class SearchParams extends Equatable {
  const SearchParams({required this.query, this.page = 1});

  final String query;
  final int page;

  @override
  List<Object?> get props => [query, page];
}
