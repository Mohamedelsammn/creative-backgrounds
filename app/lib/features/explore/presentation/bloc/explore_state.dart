part of 'explore_bloc.dart';

sealed class ExploreState extends Equatable {
  const ExploreState();

  @override
  List<Object?> get props => [];
}

class ExploreInitial extends ExploreState {
  const ExploreInitial();
}

class ExploreLoading extends ExploreState {
  const ExploreLoading();
}

class ExploreLoaded extends ExploreState {
  const ExploreLoaded({
    required this.wallpapers,
    required this.hasMore,
    this.isLoadingMore = false,
  });

  /// The single mixed feed (normal + depth + live), newest first.
  final List<WallpaperEntity> wallpapers;
  final bool hasMore;

  /// True while a next-page request is in flight - lets the feed sliver show
  /// a trailing loading indicator without re-entering [ExploreLoading] and
  /// discarding what has already loaded.
  final bool isLoadingMore;

  ExploreLoaded copyWith({
    List<WallpaperEntity>? wallpapers,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return ExploreLoaded(
      wallpapers: wallpapers ?? this.wallpapers,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  List<Object?> get props => [wallpapers, hasMore, isLoadingMore];
}

class ExploreError extends ExploreState {
  const ExploreError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
