part of 'connectivity_bloc.dart';

sealed class ConnectivityEvent extends Equatable {
  const ConnectivityEvent();

  @override
  List<Object?> get props => [];
}

/// Dispatched once at app start to begin listening to the connectivity stream.
class ConnectivityStarted extends ConnectivityEvent {
  const ConnectivityStarted();
}

/// Internal: emitted whenever the connectivity stream reports a change.
class ConnectivityChanged extends ConnectivityEvent {
  const ConnectivityChanged(this.isOnline);

  final bool isOnline;

  @override
  List<Object?> get props => [isOnline];
}
