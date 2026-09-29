part of 'category_details_bloc.dart';

sealed class CategoryDetailsState extends Equatable {
  const CategoryDetailsState();

  @override
  List<Object?> get props => [];
}

class CategoryDetailsInitial extends CategoryDetailsState {
  const CategoryDetailsInitial();
}

class CategoryDetailsLoading extends CategoryDetailsState {
  const CategoryDetailsLoading();
}

class CategoryDetailsLoaded extends CategoryDetailsState {
  const CategoryDetailsLoaded({
    required this.wallpapers,
    required this.hasMore,
    this.isLoadingMore = false,
  });

  final List<WallpaperEntity> wallpapers;
  final bool hasMore;
  final bool isLoadingMore;

  CategoryDetailsLoaded copyWith({
    List<WallpaperEntity>? wallpapers,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return CategoryDetailsLoaded(
      wallpapers: wallpapers ?? this.wallpapers,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  List<Object?> get props => [wallpapers, hasMore, isLoadingMore];
}

class CategoryDetailsError extends CategoryDetailsState {
  const CategoryDetailsError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
