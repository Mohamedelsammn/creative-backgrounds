part of 'customize_bloc.dart';

enum CustomizeTab { clock, styles, depth }

sealed class CustomizeEvent extends Equatable {
  const CustomizeEvent();

  @override
  List<Object?> get props => [];
}

class CustomizeTabChanged extends CustomizeEvent {
  const CustomizeTabChanged(this.tab);

  final CustomizeTab tab;

  @override
  List<Object?> get props => [tab];
}
