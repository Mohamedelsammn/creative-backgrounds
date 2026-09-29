import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/error_handler.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/wallpaper_entity.dart';
import '../../domain/usecases/get_new_wallpapers_usecase.dart';

part 'explore_event.dart';
part 'explore_state.dart';

/// Drives Explore's single mixed feed (normal + depth + live, newest first).
///
/// Cursor-paginated, mirroring [ViewAllBloc]'s load-more shape: the first
/// page loads on [ExploreStarted], [ExploreLoadMoreRequested] appends the
/// next page, and [ExploreRefreshRequested] bypasses the cache to pick up
/// newly published/unpublished content.
class ExploreBloc extends Bloc<ExploreEvent, ExploreState> {
  ExploreBloc({required GetNewWallpapersUseCase getNewWallpapers})
    : _getNewWallpapers = getNewWallpapers,
      super(const ExploreInitial()) {
    on<ExploreStarted>(_onLoad);
    on<ExploreRefreshRequested>(_onLoad);
    on<ExploreLoadMoreRequested>(_onLoadMore);
  }

  final GetNewWallpapersUseCase _getNewWallpapers;

  String? _cursor;
  bool _isLoadingMore = false;

  Future<void> _onLoad(ExploreEvent event, Emitter<ExploreState> emit) async {
    // Keep existing content visible during pull-to-refresh.
    if (event is ExploreStarted || state is! ExploreLoaded) {
      emit(const ExploreLoading());
    }

    final forceRefresh = event is ExploreRefreshRequested;
    _cursor = null;

    final result = await _getNewWallpapers(
      PageParams(forceRefresh: forceRefresh),
    );
    result.fold(
      (failure) =>
          emit(ExploreError(ErrorHandler.mapFailureToMessage(failure))),
      (page) {
        _cursor = page.nextCursor;
        emit(ExploreLoaded(wallpapers: page.items, hasMore: page.hasMore));
      },
    );
  }

  Future<void> _onLoadMore(
    ExploreLoadMoreRequested event,
    Emitter<ExploreState> emit,
  ) async {
    final current = state;
    if (current is! ExploreLoaded || !current.hasMore || _isLoadingMore) {
      return;
    }
    _isLoadingMore = true;
    emit(current.copyWith(isLoadingMore: true));

    final result = await _getNewWallpapers(PageParams(cursor: _cursor));
    result.fold(
      (failure) {
        // A failed load-more keeps whatever already loaded on screen - only
        // the trailing indicator clears, matching ViewAllBloc's behaviour.
        emit(current.copyWith(isLoadingMore: false));
      },
      (page) {
        _cursor = page.nextCursor;
        emit(
          ExploreLoaded(
            wallpapers: [...current.wallpapers, ...page.items],
            hasMore: page.hasMore,
          ),
        );
      },
    );
    _isLoadingMore = false;
  }
}
