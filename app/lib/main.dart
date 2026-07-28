import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
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
}
