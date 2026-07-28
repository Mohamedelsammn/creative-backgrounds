part of 'search_bloc.dart';

sealed class SearchState extends Equatable {
  const SearchState();

  @override
  List<Object?> get props => [];
}

/// Shown before a query is entered; carries recent search history.
class SearchInitial extends SearchState {
  const SearchInitial(this.history);

  final List<String> history;

  @override
  List<Object?> get props => [history];
}

class SearchLoading extends SearchState {
  const SearchLoading();
}

class SearchLoaded extends SearchState {
  const SearchLoaded({
    required this.results,
    required this.query,
    required this.hasMore,
    required this.page,
  });

  final List<WallpaperEntity> results;
  final String query;
  final bool hasMore;
  final int page;

  SearchLoaded copyWith({
    List<WallpaperEntity>? results,
    bool? hasMore,
    int? page,
  }) {
    return SearchLoaded(
      results: results ?? this.results,
      query: query,
      hasMore: hasMore ?? this.hasMore,
      page: page ?? this.page,
    );
  }

  @override
  List<Object?> get props => [results, query, hasMore, page];
}

class SearchEmpty extends SearchState {
  const SearchEmpty(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

class SearchError extends SearchState {
  const SearchError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
