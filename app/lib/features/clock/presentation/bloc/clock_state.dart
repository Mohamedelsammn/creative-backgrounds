part of 'clock_bloc.dart';

sealed class ClockState extends Equatable {
  const ClockState();

  @override
  List<Object?> get props => [];
}

class ClockInitial extends ClockState {
  const ClockInitial();
}

class ClockReady extends ClockState {
  const ClockReady(this.config);

  final ClockConfigEntity config;

  @override
  List<Object?> get props => [config];
}

class ClockSaving extends ClockState {
  const ClockSaving();
}
