import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/error_handler.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../explore/domain/entities/category_entity.dart';
import '../../../explore/domain/usecases/get_categories_usecase.dart';

part 'categories_event.dart';
part 'categories_state.dart';

/// Drives the Categories tab: the full category list, each with its own
/// wallpaper count - reuses [GetCategoriesUseCase], the same usecase Explore
/// used to fetch categories for its (now removed) per-category carousels.
class CategoriesBloc extends Bloc<CategoriesEvent, CategoriesState> {
  CategoriesBloc({required GetCategoriesUseCase getCategories})
      : _getCategories = getCategories,
        super(const CategoriesInitial()) {
    on<CategoriesStarted>(_onStarted);
  }

  final GetCategoriesUseCase _getCategories;

  Future<void> _onStarted(
    CategoriesStarted event,
    Emitter<CategoriesState> emit,
  ) async {
    emit(const CategoriesLoading());
    final result = await _getCategories(const NoParams());
    result.fold(
      (failure) =>
          emit(CategoriesError(ErrorHandler.mapFailureToMessage(failure))),
      (categories) => emit(CategoriesLoaded(categories)),
    );
  }
}
