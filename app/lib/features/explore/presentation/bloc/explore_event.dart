part of 'explore_bloc.dart';

sealed class ExploreEvent extends Equatable {
  const ExploreEvent();

  @override
  List<Object?> get props => [];
}

/// Initial load of all sections.
class ExploreStarted extends ExploreEvent {
  const ExploreStarted();
}

/// Pull-to-refresh: re-fetch all sections.
class ExploreRefreshRequested extends ExploreEvent {
  const ExploreRefreshRequested();
}
