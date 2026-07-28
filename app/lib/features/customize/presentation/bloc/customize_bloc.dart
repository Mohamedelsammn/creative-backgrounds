import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

part 'customize_event.dart';
part 'customize_state.dart';

/// Manages the active Customize tab (Clock · Styles · Depth). Clock and Depth
/// blocs handle their own domain state; this bloc only orchestrates the tabs.
class CustomizeBloc extends Bloc<CustomizeEvent, CustomizeState> {
  CustomizeBloc() : super(const CustomizeState(activeTab: CustomizeTab.clock)) {
    on<CustomizeTabChanged>(
      (event, emit) => emit(CustomizeState(activeTab: event.tab)),
    );
  }
}
