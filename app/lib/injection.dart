import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get_it/get_it.dart';

import 'channels/clock_channel.dart';
import 'channels/transparent_wallpaper_channel.dart';
import 'channels/wallpaper_channel.dart';
import 'core/config/app_config.dart';
import 'core/localization/locale_cubit.dart';
import 'core/network/dio_client.dart';
import 'core/network/network_info.dart';
import 'core/storage/hive_storage.dart';
import 'core/storage/timed_cache.dart';
import 'features/apply_wallpaper/data/repositories/apply_wallpaper_repository_impl.dart';
import 'features/apply_wallpaper/domain/repositories/apply_wallpaper_repository.dart';
import 'features/apply_wallpaper/domain/usecases/apply_wallpaper_usecase.dart';
import 'features/apply_wallpaper/presentation/bloc/apply_wallpaper_bloc.dart';
import 'features/clock/data/repositories/clock_repository_impl.dart';
import 'features/clock/domain/repositories/clock_repository.dart';
import 'features/clock/domain/usecases/load_clock_config_usecase.dart';
import 'features/clock/domain/usecases/save_clock_config_usecase.dart';
import 'features/clock/presentation/bloc/clock_bloc.dart';
import 'features/connectivity/bloc/connectivity_bloc.dart';
import 'features/depth/data/repositories/depth_repository_impl.dart';
import 'features/depth/domain/repositories/depth_repository.dart';
import 'features/depth/domain/usecases/save_depth_config_usecase.dart';
import 'features/depth/presentation/bloc/depth_bloc.dart';
import 'features/splash/domain/usecases/initialize_app_usecase.dart';
import 'features/splash/presentation/bloc/splash_bloc.dart';
import 'features/transparent_wallpaper/data/repositories/transparent_wallpaper_repository_impl.dart';
import 'features/transparent_wallpaper/domain/repositories/transparent_wallpaper_repository.dart';
import 'features/transparent_wallpaper/domain/usecases/check_compatibility_usecase.dart';
import 'features/transparent_wallpaper/domain/usecases/request_permissions_usecase.dart';
import 'features/transparent_wallpaper/domain/usecases/start_transparent_wallpaper_usecase.dart';
import 'features/transparent_wallpaper/domain/usecases/stop_transparent_wallpaper_usecase.dart';
import 'features/transparent_wallpaper/presentation/bloc/transparent_wallpaper_bloc.dart';
import 'features/explore/data/datasources/explore_mock_datasource.dart';
import 'features/explore/data/datasources/explore_remote_datasource.dart';
import 'features/explore/data/repositories/explore_repository_impl.dart';
import 'features/explore/domain/repositories/explore_repository.dart';
import 'features/explore/domain/usecases/get_categories_usecase.dart';
import 'features/explore/domain/usecases/get_latest_wallpapers_usecase.dart';
import 'features/explore/domain/usecases/get_trending_wallpapers_usecase.dart';
import 'features/explore/presentation/bloc/explore_bloc.dart';
import 'features/favorites/data/datasources/favorites_local_datasource.dart';
import 'features/favorites/data/repositories/favorites_repository_impl.dart';
import 'features/favorites/domain/repositories/favorites_repository.dart';
import 'features/favorites/domain/usecases/add_favorite_usecase.dart';
import 'features/favorites/domain/usecases/get_favorites_usecase.dart';
import 'features/favorites/domain/usecases/remove_favorite_usecase.dart';
import 'features/favorites/presentation/bloc/favorites_bloc.dart';
import 'features/search/data/datasources/search_remote_datasource.dart';
import 'features/search/data/repositories/search_repository_impl.dart';
import 'features/search/domain/repositories/search_repository.dart';
import 'features/search/domain/usecases/search_wallpapers_usecase.dart';
import 'features/search/presentation/bloc/search_bloc.dart';
import 'features/settings/data/datasources/settings_local_datasource.dart';
import 'features/settings/data/repositories/settings_repository_impl.dart';
import 'features/settings/domain/repositories/settings_repository.dart';
import 'features/settings/domain/usecases/get_settings_usecase.dart';
import 'features/settings/domain/usecases/update_settings_usecase.dart';
import 'features/settings/presentation/bloc/settings_bloc.dart';
import 'features/view_all/data/datasources/view_all_remote_datasource.dart';
import 'features/view_all/data/repositories/view_all_repository_impl.dart';
import 'features/view_all/domain/repositories/view_all_repository.dart';
import 'features/view_all/domain/usecases/get_section_wallpapers_usecase.dart';
import 'features/view_all/presentation/bloc/view_all_bloc.dart';
import 'features/wallpaper_details/data/datasources/wallpaper_details_remote_datasource.dart';
import 'features/wallpaper_details/data/repositories/wallpaper_details_repository_impl.dart';
import 'features/wallpaper_details/domain/repositories/wallpaper_details_repository.dart';
import 'features/wallpaper_details/domain/usecases/get_wallpaper_details_usecase.dart';
import 'features/wallpaper_details/presentation/bloc/wallpaper_details_bloc.dart';

/// Global service locator.
final GetIt sl = GetIt.instance;

/// Registers every dependency. Called from `main()` after Hive is ready.
///
/// Registration is split into `_registerCore` plus one function per feature so
/// the graph stays readable as features are added.
Future<void> setupDI() async {
  _registerCore();
  _registerExplore();
  _registerFavorites();
  _registerWallpaperDetails();
  _registerSearch();
  _registerViewAll();
  _registerSettings();
  _registerClock();
  _registerDepth();
  _registerApplyWallpaper();
  _registerTransparentWallpaper();
}

void _registerCore() {
  // External singletons
  sl.registerLazySingleton<Connectivity>(() => Connectivity());

  // Core services (single instance app-wide)
  sl.registerLazySingleton<DioClient>(() => DioClient());
  sl.registerLazySingleton<HiveStorage>(() => HiveStorage());
  sl.registerLazySingleton<TimedCache>(() => TimedCache(sl()));
  sl.registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl(sl()));

  // App-root blocs
  sl.registerLazySingleton<ConnectivityBloc>(
    () => ConnectivityBloc(sl())..add(const ConnectivityStarted()),
  );
  sl.registerLazySingleton<LocaleCubit>(() => LocaleCubit(sl()));

  // Splash
  sl.registerFactory(() => InitializeAppUseCase(sl()));
  sl.registerFactory(() => SplashBloc(sl()));
}

void _registerExplore() {
  // Datasource: fixture-backed under MOCK_API, otherwise real Dio.
  sl.registerLazySingleton<ExploreRemoteDatasource>(
    () => AppConfig.mockApi
        ? ExploreMockDatasource()
        : ExploreRemoteDatasourceImpl(sl()),
  );
  sl.registerLazySingleton<ExploreRepository>(
    () => ExploreRepositoryImpl(sl(), sl()),
  );
  sl.registerFactory(() => GetTrendingWallpapersUseCase(sl()));
  sl.registerFactory(() => GetLatestWallpapersUseCase(sl()));
  sl.registerFactory(() => GetCategoriesUseCase(sl()));
  sl.registerFactory(
    () => ExploreBloc(
      getTrending: sl(),
      getLatest: sl(),
      getCategories: sl(),
    ),
  );
}

void _registerFavorites() {
  sl.registerLazySingleton<FavoritesLocalDatasource>(
    () => FavoritesLocalDatasourceImpl(sl()),
  );
  sl.registerLazySingleton<FavoritesRepository>(
    () => FavoritesRepositoryImpl(sl()),
  );
  sl.registerFactory(() => GetFavoritesUseCase(sl()));
  sl.registerFactory(() => AddFavoriteUseCase(sl()));
  sl.registerFactory(() => RemoveFavoriteUseCase(sl()));
  sl.registerFactory(
    () => FavoritesBloc(
      getFavorites: sl(),
      removeFavorite: sl(),
      repository: sl(),
    ),
  );
}

void _registerWallpaperDetails() {
  sl.registerLazySingleton<WallpaperDetailsRemoteDatasource>(
    () => AppConfig.mockApi
        ? WallpaperDetailsMockDatasource()
        : WallpaperDetailsRemoteDatasourceImpl(sl()),
  );
  sl.registerLazySingleton<WallpaperDetailsRepository>(
    () => WallpaperDetailsRepositoryImpl(sl()),
  );
  sl.registerFactory(() => GetWallpaperDetailsUseCase(sl()));
  sl.registerFactory(
    () => WallpaperDetailsBloc(
      getDetails: sl(),
      addFavorite: sl(),
      removeFavorite: sl(),
      favoritesRepository: sl(),
    ),
  );
}

void _registerSearch() {
  sl.registerLazySingleton<SearchRemoteDatasource>(
    () => AppConfig.mockApi
        ? SearchMockDatasource()
        : SearchRemoteDatasourceImpl(sl()),
  );
  sl.registerLazySingleton<SearchRepository>(
    () => SearchRepositoryImpl(sl(), sl()),
  );
  sl.registerFactory(() => SearchWallpapersUseCase(sl()));
  sl.registerFactory(() => SearchBloc(search: sl(), repository: sl()));
}

void _registerViewAll() {
  sl.registerLazySingleton<ViewAllRemoteDatasource>(
    () => AppConfig.mockApi
        ? ViewAllMockDatasource()
        : ViewAllRemoteDatasourceImpl(sl()),
  );
  sl.registerLazySingleton<ViewAllRepository>(
    () => ViewAllRepositoryImpl(sl()),
  );
  sl.registerFactory(() => GetSectionWallpapersUseCase(sl()));
  sl.registerFactory(() => ViewAllBloc(sl()));
}

void _registerSettings() {
  sl.registerLazySingleton<SettingsLocalDatasource>(
    () => SettingsLocalDatasourceImpl(sl()),
  );
  sl.registerLazySingleton<SettingsRepository>(
    () => SettingsRepositoryImpl(sl()),
  );
  sl.registerFactory(() => GetSettingsUseCase(sl()));
  sl.registerFactory(() => UpdateSettingsUseCase(sl()));
  sl.registerFactory(
    () => SettingsBloc(getSettings: sl(), updateSettings: sl()),
  );
}

void _registerClock() {
  sl.registerLazySingleton<ClockChannel>(() => ClockChannel());
  sl.registerLazySingleton<ClockRepository>(
    () => ClockRepositoryImpl(sl(), sl()),
  );
  sl.registerFactory(() => LoadClockConfigUseCase(sl()));
  sl.registerFactory(() => SaveClockConfigUseCase(sl()));
  sl.registerFactory(() => ClockBloc(load: sl(), save: sl()));
}

void _registerDepth() {
  sl.registerLazySingleton<DepthRepository>(() => DepthRepositoryImpl(sl()));
  sl.registerFactory(() => SaveDepthConfigUseCase(sl()));
  sl.registerFactory(() => DepthBloc(sl()));
}

void _registerApplyWallpaper() {
  sl.registerLazySingleton<WallpaperChannel>(() => WallpaperChannel());
  sl.registerLazySingleton<ApplyWallpaperRepository>(
    () => ApplyWallpaperRepositoryImpl(sl()),
  );
  sl.registerFactory(() => ApplyWallpaperUseCase(sl()));
  sl.registerFactory(() => ApplyWallpaperBloc(sl()));
}

void _registerTransparentWallpaper() {
  sl.registerLazySingleton<TransparentWallpaperChannel>(
    () => TransparentWallpaperChannel(),
  );
  sl.registerLazySingleton<TransparentWallpaperRepository>(
    () => TransparentWallpaperRepositoryImpl(sl(), sl()),
  );
  sl.registerFactory(() => CheckCompatibilityUseCase(sl()));
  sl.registerFactory(() => RequestPermissionsUseCase(sl()));
  sl.registerFactory(() => StartTransparentWallpaperUseCase(sl()));
  sl.registerFactory(() => StopTransparentWallpaperUseCase(sl()));
  sl.registerFactory(
    () => TransparentWallpaperBloc(
      checkCompatibility: sl(),
      requestPermissions: sl(),
      start: sl(),
      stop: sl(),
      repository: sl(),
    ),
  );
}
