import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app.dart';
import 'core/ads/ad_manager.dart';
import 'core/config/app_config.dart';
import 'core/storage/hive_storage.dart';
import 'injection.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Init order: env → Hive → open boxes → DI → run.
  await dotenv.load(fileName: '.env');
  await Hive.initFlutter();
  await HiveStorage.init();
  await setupDI();

  runApp(const App());

  // First paint wins over cache housekeeping and ad-SDK startup. Both tasks
  // are best-effort and can safely happen after Splash has had a frame to
  // animate; neither is allowed to delay runApp or starve its first frames.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(
      sl<HiveStorage>().invalidateCacheIfSourceChanged(
        mockApi: AppConfig.mockApi,
      ),
    );
    unawaited(AdManager.instance.initialize());
  });
}
