import 'package:bloc/bloc.dart';
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/error_handler.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/pagination/paginated.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../explore/domain/entities/wallpaper_entity.dart';
import '../../../explore/domain/usecases/get_category_wallpapers_usecase.dart';
import '../../../explore/domain/usecases/get_live_wallpapers_usecase.dart';
import '../../domain/live_category.dart';

part 'category_details_event.dart';
part 'category_details_state.dart';

/// Paginated wallpapers for one category - the same server-filtered,
/// cursor-paginated `sort: newest` ordering the (now removed) Explore
/// per-category carousel used, reused here via [GetCategoryWallpapersUseCase].
///
/// [LiveCategory.slug] is the one exception: it is a client-side
/// pseudo-category (see [LiveCategory]), so it is served from the existing
/// server-side `type=video` feed via [GetLiveWallpapersUseCase] instead.
/// That keeps pagination correct and live-only - the alternative, fetching
/// mixed pages and dropping non-live items here, would produce short pages,
/// wasted bandwidth and a premature "no more wallpapers".
class CategoryDetailsBloc
    extends Bloc<CategoryDetailsEvent, CategoryDetailsState> {
  CategoryDetailsBloc({
    required GetCategoryWallpapersUseCase getWallpapers,
    required GetLiveWallpapersUseCase getLiveWallpapers,
  })  : _getWallpapers = getWallpapers,
        _getLiveWallpapers = getLiveWallpapers,
        super(const CategoryDetailsInitial()) {
    on<CategoryDetailsFetchRequested>(_onFetch);
    on<CategoryDetailsLoadMoreRequested>(_onLoadMore);
  }

  final GetCategoryWallpapersUseCase _getWallpapers;
  final GetLiveWallpapersUseCase _getLiveWallpapers;

  late String _categorySlug;
  String? _cursor;
  bool _isLoadingMore = false;

  /// Whether [slug] addresses the live pseudo-category.
  static bool isLiveSlug(String slug) => slug == LiveCategory.slug;

  /// One page for the current category, from whichever server-filtered feed
  /// applies. Both branches are cursor-paginated the same way, so the
  /// load-more logic below is identical for either.
  Future<Either<Failure, Paginated<WallpaperEntity>>> _fetchPage(
    String? cursor,
  ) {
    if (isLiveSlug(_categorySlug)) {
      return _getLiveWallpapers(PageParams(cursor: cursor));
    }
    return _getWallpapers(
      CategoryWallpapersParams(categorySlug: _categorySlug, cursor: cursor),
    );
  }

  Future<void> _onFetch(
    CategoryDetailsFetchRequested event,
    Emitter<CategoryDetailsState> emit,
  ) async {
    _categorySlug = event.categorySlug;
    _cursor = null;
    emit(const CategoryDetailsLoading());

    final result = await _fetchPage(null);
    result.fold(
      (failure) => emit(
        CategoryDetailsError(ErrorHandler.mapFailureToMessage(failure)),
      ),
      (page) {
        _cursor = page.nextCursor;
        emit(CategoryDetailsLoaded(
          wallpapers: page.items,
          hasMore: page.hasMore,
        ));
      },
    );
  }

  Future<void> _onLoadMore(
    CategoryDetailsLoadMoreRequested event,
    Emitter<CategoryDetailsState> emit,
  ) async {
    final current = state;
    if (current is! CategoryDetailsLoaded ||
        !current.hasMore ||
        _isLoadingMore) {
      return;
    }
    _isLoadingMore = true;
    emit(current.copyWith(isLoadingMore: true));

    final result = await _fetchPage(_cursor);
    result.fold(
      (failure) => emit(current.copyWith(isLoadingMore: false)),
      (page) {
        _cursor = page.nextCursor;
        emit(CategoryDetailsLoaded(
          wallpapers: [...current.wallpapers, ...page.items],
          hasMore: page.hasMore,
        ));
      },
    );
    _isLoadingMore = false;
  }
}
