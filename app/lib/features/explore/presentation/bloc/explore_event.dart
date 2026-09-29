part of 'explore_bloc.dart';

sealed class ExploreEvent extends Equatable {
  const ExploreEvent();

  @override
  List<Object?> get props => [];
}

/// Initial load of the first feed page.
class ExploreStarted extends ExploreEvent {
  const ExploreStarted();
}

/// Pull-to-refresh: re-fetch the first page, bypassing the cache.
class ExploreRefreshRequested extends ExploreEvent {
  const ExploreRefreshRequested();
}

/// Requests the next feed page. A no-op while a page is already in flight or
/// no further page exists.
class ExploreLoadMoreRequested extends ExploreEvent {
  const ExploreLoadMoreRequested();
}
