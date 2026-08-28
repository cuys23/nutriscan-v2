import 'dart:io';
import 'package:flutter/foundation.dart';

/// ═══════════════════════════════════════════════════════════════════
/// ADS & COIN CONFIGURATION
/// ═══════════════════════════════════════════════════════════════════
///
/// This file contains all configurable settings for:
/// • AdMob ads (Banner, Interstitial, Rewarded, App Open)
/// • Coin system (Rewards, Costs, Initial balance)
/// • Ad timing and frequency controls
///
/// QUICK CONFIGURATION GUIDE:
/// ──────────────────────────────────────────────────────────────────
///
/// 💰 COIN SYSTEM (Lines 135-143):
///    • initialCoins        → Starting coins for new users (default: 5)
///    • coinsPerRewardedAd  → Coins earned per ad watch (default: 1)
///    • coinsPerScan        → Cost per food scan (default: 5)
///
/// 🎯 INTERSTITIAL ADS (Lines 107-119):
///    • interstitialMinCooldown    → Minutes between ads (default: 5)
///    • scansBeforeInterstitial    → Scans before showing ad (default: 2)
///
/// 🎁 REWARDED ADS (Lines 145-150):
///    • rewardedAdCooldown    → Minutes between ads (default: 3)
///    • maxRewardedAdsPerDay  → Daily limit (default: 5)
///
/// 📱 BANNER ADS:
///    • Size: 320x50 (standard, non-configurable)
///    • Location: Footer of main screens
///
/// ═══════════════════════════════════════════════════════════════════

class AdsConfig {
  // Current environment (automatic based on build mode)
  static const bool _isTestMode = kDebugMode;

  // Master switch set by the developer. The effective value is [adsEnabled],
  // which additionally refuses to serve ads in release builds that still carry
  // placeholder AdMob IDs.
  static const bool _adsEnabledByConfig = true;

  /// Whether ads should actually be served.
  ///
  /// iOS-only: this product ships on the App Store only and has no Android
  /// AdMob app, so ads are never requested on other platforms.
  ///
  /// FAIL-SAFE: shipping Google's sample/test ad unit IDs to the App Store is an
  /// AdMob policy violation and invalid production IDs only produce broken ad
  /// slots. So in a release build with unconfigured IDs we silently disable ads
  /// instead of requesting them. Fill in the `_production*` constants below to
  /// turn ads back on.
  static bool get adsEnabled {
    if (!_adsEnabledByConfig) return false;
    if (!Platform.isIOS) return false;
    if (_isTestMode) return true;
    return hasProductionAdUnitIds;
  }

  // Google's sample ad units, used in debug builds only.
  static const String _testInterstitialAdUnitId =
      'ca-app-pub-3940256099942544/4411468910';
  static const String _testOpenAdUnitId =
      'ca-app-pub-3940256099942544/5575463023';
  static const String _testRewardedAdUnitId =
      'ca-app-pub-3940256099942544/1712485313';
  static const String _testBannerAdUnitId =
      'ca-app-pub-3940256099942544/2435281174';

  // ═══════════════════════════════════════════════════════════════════
  // PRODUCTION AD UNIT IDs — FILL THESE BEFORE SUBMITTING TO THE STORE
  // ═══════════════════════════════════════════════════════════════════
  //
  // 1. AdMob console → Apps → NutriSnap (iOS) → Ad units → copy each ID.
  // 2. Paste below. Format: 'ca-app-pub-<16 digits>/<10 digits>'.
  // 3. ALSO update `GADApplicationIdentifier` in ios/Runner/Info.plist — that
  //    is the App ID (with `~`), not an ad unit ID (with `/`).
  // 4. Verify with `AdsConfig.configurationReport()`.
  //
  // While any of these is empty, release builds run with ads disabled.
  static const String _productionInterstitialAdUnitId =
      'ca-app-pub-5770727176247801/5510536452';
  static const String _productionOpenAdUnitId =
      'ca-app-pub-5770727176247801/2884373116';
  static const String _productionRewardedAdUnitId =
      'ca-app-pub-5770727176247801/8369855276';
  static const String _productionBannerAdUnitId =
      'ca-app-pub-5770727176247801/6104332746';

  /// AdMob **App ID** (the `~` form). Kept here only so the release checklist
  /// has one place to look; the value that actually matters at runtime lives in
  /// Info.plist.
  static const String productionAdMobAppIdIos =
      'ca-app-pub-5770727176247801~9874508638';

  static const List<String> _productionIds = [
    _productionInterstitialAdUnitId,
    _productionOpenAdUnitId,
    _productionRewardedAdUnitId,
    _productionBannerAdUnitId,
  ];

  static bool _isConfigured(String id) =>
      id.isNotEmpty && !id.contains('X') && id.startsWith('ca-app-pub-');

  /// True when every production ad unit ID is filled in with a real value.
  static bool get hasProductionAdUnitIds => _productionIds.every(_isConfigured);

  /// Human-readable status for the pre-submit checklist and debug logs.
  static String configurationReport() {
    if (!Platform.isIOS) {
      return 'AdsConfig: non-iOS platform — ads are DISABLED (iOS-only app).';
    }
    if (_isTestMode) {
      return 'AdsConfig: TEST mode (debug build) — Google sample ad units in use.';
    }
    if (!_adsEnabledByConfig) {
      return 'AdsConfig: ads disabled by configuration.';
    }
    if (!hasProductionAdUnitIds) {
      return 'AdsConfig: RELEASE build with unconfigured production ad unit IDs '
          '— ads are DISABLED. Fill the _production*AdUnitId constants in '
          'lib/config/ads_config.dart before submitting.';
    }
    return 'AdsConfig: PRODUCTION ad units configured.';
  }

  static String get interstitialAdUnitId => _isTestMode
      ? _testInterstitialAdUnitId
      : _productionInterstitialAdUnitId;

  static String get openAdUnitId =>
      _isTestMode ? _testOpenAdUnitId : _productionOpenAdUnitId;

  static String get rewardedAdUnitId =>
      _isTestMode ? _testRewardedAdUnitId : _productionRewardedAdUnitId;

  static String get bannerAdUnitId =>
      _isTestMode ? _testBannerAdUnitId : _productionBannerAdUnitId;

  // ===== AD LOADING CONFIGURATION =====
  static const int maxRetryAttempts = 3;
  static const Duration retryDelay = Duration(seconds: 5);

  // After the fast retries are exhausted (typically: the device was offline at
  // launch) keep trying on a slow timer. Giving up entirely would leave the user
  // with no way to earn coins for the rest of the session.
  static const Duration retryBackoffDelay = Duration(minutes: 5);
  static const Duration adLoadTimeout = Duration(seconds: 10);
  static const Duration preloadDelay = Duration(milliseconds: 500);

  // ===== INTERSTITIAL AD TIMING CONTROL =====
  // Minimum time between interstitial ads (configurable: 1-60 minutes recommended)
  static const Duration interstitialMinCooldown = Duration(
    minutes: 5,
  ); // Change this value to control ad frequency (e.g., Duration(minutes: 10))

  // Number of scans before showing interstitial ad
  static const int scansBeforeInterstitial =
      2; // Shows ad after 2 scans in same day

  static const Duration interstitialCooldown = Duration(minutes: 2);
  static const int minActionsBeforeInterstitial = 3;
  static const Duration interstitialShowDelay = Duration(milliseconds: 300);
  static const Duration interstitialDismissCooldown = Duration(seconds: 5);

  // Interstitial ad frequency control
  static const int maxInterstitialsPerSession = 5;
  static const Duration interstitialSessionReset = Duration(hours: 24);

  // ===== APP OPEN AD TIMING CONTROL =====
  static const Duration openAdCooldown = Duration(
    minutes: 4,
  ); // Standard cooldown
  static const Duration openAdMinCooldown = Duration(
    seconds: 30,
  ); // Minimum between open ads
  static const Duration openAdLoadTimeout = Duration(seconds: 5);
  static const Duration openAdShowDelay = Duration(milliseconds: 500);
  static const Duration openAdDismissCooldown = Duration(seconds: 10);

  // Google expires a cached app open ad after 4 hours; showing a stale one
  // silently fails, so we drop and reload it past this age.
  static const Duration openAdMaxCacheAge = Duration(hours: 4);

  // App open ad frequency control
  static const int maxOpenAdsPerSession = 3;
  static const Duration openAdSessionReset = Duration(hours: 12);

  // ===== COIN SYSTEM CONFIGURATION =====
  // Initial coins given to new users
  static const int initialCoins = 5; // Just 1 free scan initially

  // Coins earned per rewarded ad
  static const int coinsPerRewardedAd = 1; // Requires 5 ads for one scan

  // Coins cost per food scan
  static const int coinsPerScan = 5;

  // ===== REWARDED AD TIMING CONTROL =====
  static const Duration rewardedAdCooldown = Duration(minutes: 3);
  static const Duration rewardedAdLoadTimeout = Duration(seconds: 10);
  static const Duration rewardedAdShowDelay = Duration(milliseconds: 300);
  static const int maxRewardedAdsPerDay = 5; // Only enough for 1 free scan per day
  static const Duration rewardedAdDailyReset = Duration(hours: 24);

  // ===== SESSION TIMING CONTROL =====
  static const Duration sessionTimeout = Duration(
    minutes: 30,
  ); // App session timeout
  static const Duration backgroundTimeThreshold = Duration(
    seconds: 30,
  ); // Time in background before showing open ad
  static const Duration foregroundTimeRequired = Duration(
    seconds: 5,
  ); // Time in foreground before allowing ads

  // ===== AD SHOWING CONDITIONS =====
  static const Duration minimumAppUsageTime = Duration(
    minutes: 1,
  ); // Minimum app usage before showing ads
  static const Duration maximumAdFrequency = Duration(
    minutes: 15,
  ); // Maximum frequency of any ad type
  static const int maxTotalAdsPerHour = 8;
  static const Duration hourlyAdReset = Duration(hours: 1);

  // ===== HELPER METHODS =====

  /// Get the appropriate cooldown duration
  static Duration getInterstitialCooldown() {
    return interstitialCooldown;
  }

  /// Get the appropriate open ad cooldown
  static Duration getOpenAdCooldown() {
    return openAdCooldown;
  }

  /// Check if we're in test mode
  static bool get isTestMode => _isTestMode;

  /// Get current environment name
  static String get environment => _isTestMode ? 'TEST' : 'PRODUCTION';

  /// Get total ads per hour limit
  static int getMaxAdsPerHour() {
    return maxTotalAdsPerHour;
  }

  /// Get minimum app usage time before showing ads
  static Duration getMinimumUsageTime() {
    return minimumAppUsageTime;
  }
}

