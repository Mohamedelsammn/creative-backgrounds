part of 'view_all_bloc.dart';

sealed class ViewAllState extends Equatable {
  const ViewAllState();

  @override
  List<Object?> get props => [];
}

class ViewAllInitial extends ViewAllState {
  const ViewAllInitial();
}

class ViewAllLoading extends ViewAllState {
  const ViewAllLoading();
}

class ViewAllLoaded extends ViewAllState {
  const ViewAllLoaded({
    required this.items,
    required this.hasMore,
    required this.activeFilter,
    required this.activeSort,
  });

  final List<WallpaperEntity> items;
  final bool hasMore;
  final FilterOptions activeFilter;
  final SortOption? activeSort;

  @override
  List<Object?> get props => [items, hasMore, activeFilter, activeSort];
}

class ViewAllError extends ViewAllState {
  const ViewAllError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
