import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../explore/domain/entities/wallpaper_entity.dart';
import '../../domain/entities/view_all_options.dart';
import '../../domain/usecases/get_section_wallpapers_usecase.dart';

part 'view_all_event.dart';
part 'view_all_state.dart';

class ViewAllBloc extends Bloc<ViewAllEvent, ViewAllState> {
  ViewAllBloc(this._getSection) : super(const ViewAllInitial()) {
    on<ViewAllFetchRequested>(_onFetch);
    on<ViewAllLoadMoreRequested>(_onLoadMore);
    on<ViewAllFilterApplied>(_onFilter);
    on<ViewAllSortApplied>(_onSort);
  }

  final GetSectionWallpapersUseCase _getSection;

  late String _section;
  FilterOptions _filter = const FilterOptions();
  SortOption? _sort;
  int _page = 1;
  bool _isLoadingMore = false;

  Future<void> _onFetch(
    ViewAllFetchRequested event,
    Emitter<ViewAllState> emit,
  ) async {
    _section = event.section;
    _page = 1;
    emit(const ViewAllLoading());
    await _load(emit, reset: true);
  }

  Future<void> _onFilter(
    ViewAllFilterApplied event,
    Emitter<ViewAllState> emit,
  ) async {
    _filter = event.filter;
    _page = 1;
    emit(const ViewAllLoading());
    await _load(emit, reset: true);
  }

  Future<void> _onSort(
    ViewAllSortApplied event,
    Emitter<ViewAllState> emit,
  ) async {
    _sort = event.sort;
    _page = 1;
    emit(const ViewAllLoading());
    await _load(emit, reset: true);
  }

  Future<void> _onLoadMore(
    ViewAllLoadMoreRequested event,
    Emitter<ViewAllState> emit,
  ) async {
    final current = state;
    if (current is! ViewAllLoaded || !current.hasMore || _isLoadingMore) return;
    _isLoadingMore = true;
    _page += 1;
    await _load(emit, reset: false, existing: current.items);
    _isLoadingMore = false;
  }

  Future<void> _load(
    Emitter<ViewAllState> emit, {
    required bool reset,
    List<WallpaperEntity> existing = const [],
  }) async {
    final result = await _getSection(SectionParams(
      section: _section,
      page: _page,
      filter: _filter,
      sort: _sort,
    ));
    result.fold(
      (failure) {
        if (reset) emit(ViewAllError(failure.message));
      },
      (paged) {
        final items = reset ? paged.items : [...existing, ...paged.items];
        emit(ViewAllLoaded(
          items: items,
          hasMore: paged.hasMore,
          activeFilter: _filter,
          activeSort: _sort,
        ));
      },
    );
  }
}
