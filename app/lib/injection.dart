import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

import 'channels/transparent_wallpaper_channel.dart';
import 'channels/wallpaper_channel.dart';
import 'core/categories/category_directory.dart';
import 'core/config/app_config.dart';
import 'features/adblock/data/services/ad_block_detection_service.dart';
import 'features/adblock/data/services/ad_integrity_service.dart';
import 'features/review/data/services/review_service.dart';
import 'features/update/data/datasources/update_policy_remote_datasource.dart';
import 'features/update/data/services/app_update_service.dart';
import 'core/localization/locale_cubit.dart';
import 'core/network/dio_client.dart';
import 'core/network/network_info.dart';
import 'core/storage/hive_storage.dart';
import 'core/storage/timed_cache.dart';
import 'features/apply_wallpaper/data/repositories/apply_wallpaper_repository_impl.dart';
import 'features/apply_wallpaper/domain/repositories/apply_wallpaper_repository.dart';
import 'features/apply_wallpaper/domain/usecases/apply_wallpaper_usecase.dart';
import 'features/apply_wallpaper/presentation/bloc/apply_wallpaper_bloc.dart';
import 'features/connectivity/bloc/connectivity_bloc.dart';
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
import 'features/explore/data/datasources/wallpaper_feed_api.dart';
import 'features/explore/data/repositories/explore_repository_impl.dart';
import 'features/explore/domain/repositories/explore_repository.dart';
import 'features/explore/domain/usecases/get_categories_usecase.dart';
import 'features/explore/domain/usecases/get_category_wallpapers_usecase.dart';
import 'features/explore/domain/usecases/get_depth_wallpapers_usecase.dart';
import 'features/explore/domain/usecases/get_live_wallpapers_usecase.dart';
import 'features/explore/domain/usecases/get_new_wallpapers_usecase.dart';
import 'features/categories/presentation/bloc/categories_bloc.dart';
import 'features/categories/presentation/bloc/category_details_bloc.dart';
import 'features/explore/domain/usecases/resolve_video_url_usecase.dart';
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
///
/// Idempotent: GetIt throws if a type is registered twice, and `main()` can
/// be re-entered within the SAME running Dart VM in scenarios where Android
/// recreates `MainActivity` without tearing down the Flutter engine/VM (e.g.
/// certain Activity-recreation paths, or "Don't keep activities"). Without
/// this guard, that second `setupDI()` call throws on its very first
/// registration, before `runApp`/`SplashBloc` can ever be (re)built - the
/// last frame Flutter had drawn stays on screen forever, which is
/// indistinguishable from "stuck on the splash screen".
Future<void> setupDI() async {
  // TransparentWallpaperBloc is the last thing _registerTransparentWallpaper
  // (the last of the _register* calls below) registers - checking it, rather
  // than something registered early, avoids treating a call that was
  // interrupted partway through as already complete.
  if (sl.isRegistered<TransparentWallpaperBloc>()) return;
  _registerCore();
  _registerExplore();
  _registerCategories();
  _registerFavorites();
  _registerWallpaperDetails();
  _registerSearch();
  _registerSettings();
  _registerApplyWallpaper();
  _registerTransparentWallpaper();
}

void _registerCore() {
  // External singletons
  sl.registerLazySingleton<Connectivity>(() => Connectivity());

  // Core services (single instance app-wide)
  sl.registerLazySingleton<DioClient>(() => DioClient());
  // Slug -> category lookup shared by every wallpaper mapping path.
  sl.registerLazySingleton<CategoryDirectory>(() => CategoryDirectory());
  // Single client for the public wallpaper API, shared by explore, view-all,
  // search and details so endpoint shapes live in exactly one place.
  sl.registerLazySingleton<WallpaperFeedApi>(
    () => WallpaperFeedApi(sl(), sl()),
  );
  sl.registerLazySingleton<HiveStorage>(() => HiveStorage());
  sl.registerLazySingleton<TimedCache>(() => TimedCache(sl()));
  sl.registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl(sl()));
  // Best-effort ad-block / network-interference detection. Stateless and
  // cheap to hold; callers decide when to run a pass.
  sl.registerLazySingleton<AdBlockDetectionService>(
    () => AdBlockDetectionService(),
  );
  // Startup ad-blocking gate: VPN/DNS signals (via AdBlockDetectionService)
  // plus a real ad-load probe and cross-session streak. Run once from
  // SplashBloc; a fresh instance each time keeps it stateless in memory
  // (its streak/first-run state lives in HiveStorage, not here).
  sl.registerFactory<AdIntegrityService>(() => AdIntegrityService());
  // Startup mandatory-update gate: compares the installed Android
  // versionCode against a REMOTELY configured minimum supported build.
  // A PLAIN Dio, deliberately not the shared `DioClient` - the policy
  // document lives at its own absolute URL and must not inherit the content
  // API's baseUrl, auth headers, or interceptor. Keeping it separate also
  // means the gate still works if the content API is moved or versioned.
  sl.registerLazySingleton<UpdatePolicyRemoteDatasource>(
    () => UpdatePolicyRemoteDatasourceImpl(Dio()),
  );
  // Singleton, not a factory: it caches the fetched policy for the process
  // lifetime, so the blocking screen's resume re-check and any repeat call
  // reuse one fetch instead of hitting the network again.
  sl.registerLazySingleton<AppUpdateService>(() => AppUpdateService(sl()));
  // In-app review (Feature 2). Singleton so the apply counter and the
  // once-per-version guard are read/written through one instance.
  sl.registerLazySingleton<ReviewService>(() => ReviewService(storage: sl()));

  // App-root blocs
  sl.registerLazySingleton<ConnectivityBloc>(
    () => ConnectivityBloc(sl())..add(const ConnectivityStarted()),
  );
  sl.registerLazySingleton<LocaleCubit>(() => LocaleCubit(sl()));

  // Splash
  sl.registerFactory(() => InitializeAppUseCase(sl()));
  sl.registerFactory(() => SplashBloc(sl(), sl(), sl()));
}

void _registerExplore() {
  // Datasource: fixture-backed under MOCK_API, otherwise real Dio.
  sl.registerLazySingleton<ExploreRemoteDatasource>(
    () => AppConfig.mockApi
        ? ExploreMockDatasource()
        : ExploreRemoteDatasourceImpl(sl()),
  );
  sl.registerLazySingleton<ExploreRepository>(
    () => ExploreRepositoryImpl(sl(), sl(), sl()),
  );
  sl.registerFactory(() => GetTrendingWallpapersUseCase(sl()));
  sl.registerFactory(() => GetLiveWallpapersUseCase(sl()));
  sl.registerFactory(() => GetDepthWallpapersUseCase(sl()));
  sl.registerFactory(() => GetNewWallpapersUseCase(sl()));
  sl.registerFactory(() => GetCategoriesUseCase(sl()));
  sl.registerFactory(() => GetCategoryWallpapersUseCase(sl()));
  // Singleton: it memoises resolved clip URLs for the session, so scrolling
  // back to a card never refetches its detail.
  sl.registerLazySingleton(() => ResolveVideoUrlUseCase(sl()));
  sl.registerFactory(
    () => ExploreBloc(getNewWallpapers: sl()),
  );
}

void _registerCategories() {
  // Reuses ExploreRepository/GetCategoriesUseCase/GetCategoryWallpapersUseCase
  // (registered in `_registerExplore`) rather than a second copy of the same
  // category data access.
  sl.registerFactory(
    () => CategoriesBloc(getCategories: sl()),
  );
  sl.registerFactory(
    () => CategoryDetailsBloc(
      getWallpapers: sl(),
      // Serves the "Live Wallpapers" pseudo-category from the existing
      // server-side type=video feed - see LiveCategory.
      getLiveWallpapers: sl(),
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
      repository: sl(),
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
  // Registered as a SINGLETON, not a factory: the transparent wallpaper is one
  // device-wide feature with one state. Separate per-screen instances meant the
  // preview page, the Explore card and the settings page each held their own
  // copy, so a transition that arrived while one was disposed was simply lost.
  sl.registerLazySingleton(
    () => TransparentWallpaperBloc(
      checkCompatibility: sl(),
      requestPermissions: sl(),
      start: sl(),
      stop: sl(),
      repository: sl(),
    ),
  );
}
