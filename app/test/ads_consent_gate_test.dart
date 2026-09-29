import 'package:creativebackground/core/ads/ad_manager.dart';
import 'package:creativebackground/core/ads/adaptive_banner_manager.dart';
import 'package:flutter_test/flutter_test.dart';

/// UMP contract: no ad may be requested until consent permits it. Banners
/// used to call `BannerAd.load()` independently of the consent flow, so a
/// Home banner could be requested while an EEA user was still looking at
/// the consent form. `flutter_test_config.dart` marks consent as resolved
/// with ads NOT permitted, which is exactly the state this guards.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ensureAdsReady reports false when consent does not permit ads',
      () async {
    expect(await AdManager.instance.ensureAdsReady(), isFalse);
  });

  test('a banner slot never creates or requests a BannerAd without consent',
      () async {
    final manager = AdaptiveBannerManager('test-unit');
    await manager.load(360);
    expect(manager.ad, isNull,
        reason: 'no BannerAd may be constructed before consent permits it');
    expect(manager.loaded.value, isFalse);
    manager.dispose();
  });
}
