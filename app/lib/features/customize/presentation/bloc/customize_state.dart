part of 'customize_bloc.dart';

class CustomizeState extends Equatable {
  const CustomizeState({required this.activeTab});

  final CustomizeTab activeTab;

  @override
  List<Object?> get props => [activeTab];
}
