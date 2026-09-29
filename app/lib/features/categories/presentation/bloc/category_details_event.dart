part of 'category_details_bloc.dart';

sealed class CategoryDetailsEvent extends Equatable {
  const CategoryDetailsEvent();

  @override
  List<Object?> get props => [];
}

class CategoryDetailsFetchRequested extends CategoryDetailsEvent {
  const CategoryDetailsFetchRequested(this.categorySlug);

  final String categorySlug;

  @override
  List<Object?> get props => [categorySlug];
}

class CategoryDetailsLoadMoreRequested extends CategoryDetailsEvent {
  const CategoryDetailsLoadMoreRequested();
}
