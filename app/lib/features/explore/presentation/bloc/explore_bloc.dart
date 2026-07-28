import 'package:bloc/bloc.dart';
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/error_handler.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/pagination/paginated.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/category_entity.dart';
import '../../domain/entities/wallpaper_entity.dart';
import '../../domain/usecases/get_categories_usecase.dart';
import '../../domain/usecases/get_latest_wallpapers_usecase.dart';
import '../../domain/usecases/get_trending_wallpapers_usecase.dart';

part 'explore_event.dart';
part 'explore_state.dart';

class ExploreBloc extends Bloc<ExploreEvent, ExploreState> {
  ExploreBloc({
    required GetTrendingWallpapersUseCase getTrending,
    required GetLatestWallpapersUseCase getLatest,
    required GetCategoriesUseCase getCategories,
  })  : _getTrending = getTrending,
        _getLatest = getLatest,
        _getCategories = getCategories,
        super(const ExploreInitial()) {
    on<ExploreStarted>(_onLoad);
    on<ExploreRefreshRequested>(_onLoad);
  }

  final GetTrendingWallpapersUseCase _getTrending;
  final GetLatestWallpapersUseCase _getLatest;
  final GetCategoriesUseCase _getCategories;

  Future<void> _onLoad(ExploreEvent event, Emitter<ExploreState> emit) async {
    // Keep existing content visible during pull-to-refresh.
    if (event is ExploreStarted || state is! ExploreLoaded) {
      emit(const ExploreLoading());
    }

    final results = await Future.wait([
      _getTrending(const PageParams()),
      _getLatest(const PageParams()),
      _getCategories(const NoParams()),
    ]);

    final trending = results[0] as Either<Failure, Paginated<WallpaperEntity>>;
    final latest = results[1] as Either<Failure, Paginated<WallpaperEntity>>;
    final categories = results[2] as Either<Failure, List<CategoryEntity>>;

    // Surface the first failure encountered.
    final failure = _firstFailure([trending, latest, categories]);
    if (failure != null) {
      emit(ExploreError(ErrorHandler.mapFailureToMessage(failure)));
      return;
    }

    emit(ExploreLoaded(
      trending: trending.getOrElse(() => const Paginated.empty()).items,
      latest: latest.getOrElse(() => const Paginated.empty()).items,
      categories: categories.getOrElse(() => const []),
    ));
  }

  Failure? _firstFailure(List<Either<Failure, dynamic>> results) {
    for (final r in results) {
      final f = r.fold<Failure?>((l) => l, (_) => null);
      if (f != null) return f;
    }
    return null;
  }
}
