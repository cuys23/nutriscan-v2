import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nutriscan/config/ads_config.dart';

void main() {
  test('every production ad unit ID is filled in', () {
    // Fails the moment someone leaves a placeholder behind — an unconfigured ID
    // silently disables ads in the release build.
    expect(AdsConfig.hasProductionAdUnitIds, isTrue);
  });

  test('ads stay off outside iOS', () {
    // The host running this test is not iOS, so this pins the iOS-only guard.
    expect(Platform.isIOS, isFalse, reason: 'test host should not be iOS');
    expect(AdsConfig.adsEnabled, isFalse);
    expect(AdsConfig.configurationReport(), contains('DISABLED'));
  });

  test('ad unit getters return real AdMob IDs', () {
    for (final id in [
      AdsConfig.interstitialAdUnitId,
      AdsConfig.openAdUnitId,
      AdsConfig.rewardedAdUnitId,
      AdsConfig.bannerAdUnitId,
    ]) {
      expect(id, startsWith('ca-app-pub-'));
    }
  });
}
