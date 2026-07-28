import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:equatable/equatable.dart';

part 'connectivity_event.dart';
part 'connectivity_state.dart';

/// App-root bloc that mirrors device connectivity. Provided above the router so
/// any screen (and the offline banner) can listen.
class ConnectivityBloc extends Bloc<ConnectivityEvent, ConnectivityState> {
  ConnectivityBloc(this._connectivity) : super(ConnectivityInitial()) {
    on<ConnectivityStarted>(_onStarted);
    on<ConnectivityChanged>(_onChanged);
  }

  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  Future<void> _onStarted(
    ConnectivityStarted event,
    Emitter<ConnectivityState> emit,
  ) async {
    final initial = await _connectivity.checkConnectivity();
    add(ConnectivityChanged(_isOnline(initial)));
    _subscription?.cancel();
    _subscription = _connectivity.onConnectivityChanged.listen(
      (results) => add(ConnectivityChanged(_isOnline(results))),
    );
  }

  void _onChanged(ConnectivityChanged event, Emitter<ConnectivityState> emit) {
    emit(event.isOnline ? ConnectivityOnline() : ConnectivityOffline());
  }

  bool _isOnline(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
