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
    required this.trending,
    required this.latest,
    required this.categories,
  });

  final List<WallpaperEntity> trending;
  final List<WallpaperEntity> latest;
  final List<CategoryEntity> categories;

  @override
  List<Object?> get props => [trending, latest, categories];
}

class ExploreError extends ExploreState {
  const ExploreError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
