import 'dart:async';

import 'package:creativebackground/core/ads/ad_manager.dart';
import 'package:creativebackground/features/adblock/presentation/ad_integrity_gate.dart';

/// Applied automatically by `flutter test` to every test file in this folder.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  AdManager.instance.debugSkipConsentForTests();
  // No real ad probe (and its 10 s timeout) from MainShell in widget tests.
  AdIntegrityGate.instance.markVerified();
  await testMain();
}
