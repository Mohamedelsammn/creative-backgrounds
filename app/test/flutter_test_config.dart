import 'dart:async';

import 'package:creativebackground/core/ads/ad_manager.dart';

/// Applied automatically by `flutter test` to every test file in this folder.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  AdManager.instance.debugSkipConsentForTests();
  await testMain();
}
