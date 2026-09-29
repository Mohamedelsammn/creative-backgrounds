import 'package:creativebackground/channels/wallpaper_channel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phase 8: `ACTION_CHANGE_LIVE_WALLPAPER` (the system live-wallpaper picker
/// used for any clock/depth/live apply) gives no result callback - the app
/// used to fire the intent, immediately report success to Flutter, and never
/// learn what actually happened when the user returned. That silence is what
/// read as the app "getting stuck" in the picker: nothing ever confirmed or
/// denied the outcome. `consumePendingApplyOutcome` is how Flutter now reads
/// what native reconciled on the next `Activity.onResume`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channelName = 'com.backgrounds.trend4k/wallpaper';

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel(channelName), null);
  });

  void mockOutcome(String? outcome) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel(channelName),
      (call) async =>
          call.method == 'consumePendingApplyOutcome' ? outcome : null,
    );
  }

  test('native reporting "applied" maps to LiveWallpaperApplyOutcome.applied',
      () async {
    mockOutcome('applied');
    final outcome = await WallpaperChannel().consumePendingApplyOutcome();
    expect(outcome, LiveWallpaperApplyOutcome.applied);
  });

  test(
      'native reporting "cancelled" maps to '
      'LiveWallpaperApplyOutcome.cancelled', () async {
    mockOutcome('cancelled');
    final outcome = await WallpaperChannel().consumePendingApplyOutcome();
    expect(outcome, LiveWallpaperApplyOutcome.cancelled);
  });

  test(
      'native reporting "none" (nothing was pending) maps to '
      'LiveWallpaperApplyOutcome.none - no toast should be shown for this',
      () async {
    mockOutcome('none');
    final outcome = await WallpaperChannel().consumePendingApplyOutcome();
    expect(outcome, LiveWallpaperApplyOutcome.none);
  });

  test('an unrecognised/null result degrades to none rather than throwing',
      () async {
    mockOutcome(null);
    final outcome = await WallpaperChannel().consumePendingApplyOutcome();
    expect(outcome, LiveWallpaperApplyOutcome.none);
  });
}
