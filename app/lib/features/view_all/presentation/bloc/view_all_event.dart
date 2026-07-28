part of 'view_all_bloc.dart';

sealed class ViewAllEvent extends Equatable {
  const ViewAllEvent();

  @override
  List<Object?> get props => [];
}

class ViewAllFetchRequested extends ViewAllEvent {
  const ViewAllFetchRequested(this.section);

  final String section;

  @override
  List<Object?> get props => [section];
}

class ViewAllLoadMoreRequested extends ViewAllEvent {
  const ViewAllLoadMoreRequested();
}

class ViewAllFilterApplied extends ViewAllEvent {
  const ViewAllFilterApplied(this.filter);

  final FilterOptions filter;

  @override
  List<Object?> get props => [filter];
}

class ViewAllSortApplied extends ViewAllEvent {
  const ViewAllSortApplied(this.sort);

  final SortOption sort;

  @override
  List<Object?> get props => [sort];
}
