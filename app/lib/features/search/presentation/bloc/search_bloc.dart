import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:rxdart/rxdart.dart';

import '../../../explore/domain/entities/wallpaper_entity.dart';
import '../../domain/repositories/search_repository.dart';
import '../../domain/usecases/search_wallpapers_usecase.dart';

part 'search_event.dart';
part 'search_state.dart';

/// Debounce + cancel-previous transformer for query input.
EventTransformer<E> _debounceRestartable<E>(Duration duration) {
  return (events, mapper) =>
      events.debounceTime(duration).switchMap(mapper);
}

class SearchBloc extends Bloc<SearchEvent, SearchState> {
  SearchBloc({
    required SearchWallpapersUseCase search,
    required SearchRepository repository,
  })  : _search = search,
        _repository = repository,
        super(SearchInitial(repository.getHistory())) {
    on<SearchQueryChanged>(
      _onQueryChanged,
      transformer: _debounceRestartable(const Duration(milliseconds: 300)),
    );
    on<SearchCleared>(_onCleared);
    on<SearchLoadMoreRequested>(_onLoadMore);
    on<SearchHistoryCleared>(_onHistoryCleared);
  }

  final SearchWallpapersUseCase _search;
  final SearchRepository _repository;

  Future<void> _onQueryChanged(
    SearchQueryChanged event,
    Emitter<SearchState> emit,
  ) async {
    final query = event.query.trim();
    if (query.isEmpty) {
      emit(SearchInitial(_repository.getHistory()));
      return;
    }
    emit(const SearchLoading());
    final result = await _search(SearchParams(query: query));
    await result.fold(
      (failure) async => emit(SearchError(failure.message)),
      (page) async {
        if (page.items.isEmpty) {
          emit(SearchEmpty(query));
        } else {
          await _repository.addToHistory(query);
          emit(SearchLoaded(
            results: page.items,
            query: query,
            hasMore: page.hasMore,
            page: page.page,
          ));
        }
      },
    );
  }

  void _onCleared(SearchCleared event, Emitter<SearchState> emit) {
    emit(SearchInitial(_repository.getHistory()));
  }

  Future<void> _onLoadMore(
    SearchLoadMoreRequested event,
    Emitter<SearchState> emit,
  ) async {
    final current = state;
    if (current is! SearchLoaded || !current.hasMore) return;
    final result =
        await _search(SearchParams(query: current.query, page: current.page + 1));
    result.fold(
      (_) {},
      (page) => emit(current.copyWith(
        results: [...current.results, ...page.items],
        hasMore: page.hasMore,
        page: page.page,
      )),
    );
  }

  Future<void> _onHistoryCleared(
    SearchHistoryCleared event,
    Emitter<SearchState> emit,
  ) async {
    await _repository.clearHistory();
    if (state is SearchInitial) emit(const SearchInitial([]));
  }
}
