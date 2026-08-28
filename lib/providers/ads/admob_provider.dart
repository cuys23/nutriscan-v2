import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:nutriscan/config/ads_config.dart';
import 'package:nutriscan/providers/payment/subscription_provider.dart';

class AdMobProvider extends ChangeNotifier {
  InterstitialAd? _interstitialAd;
  AppOpenAd? _appOpenAd;
  RewardedAd? _rewardedAd;
  bool _isInterstitialAdLoaded = false;
  bool _isAppOpenAdLoaded = false;
  bool _isRewardedAdLoaded = false;
  bool _isLoadingAd = false;
  bool _isLoadingOpenAd = false;
  bool _isLoadingRewardedAd = false;
  int _retryCount = 0;
  int _openAdRetryCount = 0;
  int _rewardedAdRetryCount = 0;

  DateTime? _lastInterstitialShown;
  DateTime? _lastOpenAdShown;
  DateTime? _lastRewardedAdShown;
  bool _isAdShowing = false;
  bool _isOpenAdShowing = false;
  bool _isRewardedAdShowing = false;
  SubscriptionProvider? _subscriptionProvider;

  int _rewardedAdsShownToday = 0;
  DateTime? _lastRewardedAdResetDate;

  int _scansToday = 0;
  DateTime? _lastScanResetDate;
  bool _hasShownInterstitialAfterScans = false;

  bool _hasVisitedAnalysisToday = false;
  DateTime? _lastAnalysisVisitResetDate;
  bool _hasShownInterstitialOnAnalysisEntry = false;

  bool get isInterstitialAdLoaded => _isInterstitialAdLoaded;

  bool get isAppOpenAdLoaded => _isAppOpenAdLoaded;

  bool get isRewardedAdLoaded => _isRewardedAdLoaded;

  bool get isLoadingAd => _isLoadingAd;

  bool get isLoadingOpenAd => _isLoadingOpenAd;

  bool get isLoadingRewardedAd => _isLoadingRewardedAd;

  AdMobProvider() {
    if (AdsConfig.adsEnabled) {
      _loadInterstitialAd();
      _loadAppOpenAd();
      _loadRewardedAd();
    }
  }

  void setSubscriptionProvider(SubscriptionProvider subscriptionProvider) {
    _subscriptionProvider = subscriptionProvider;
  }

  bool get _shouldShowAds {
    if (!AdsConfig.adsEnabled) return false;
    return _subscriptionProvider?.hasPremiumFeatures != true;
  }

  bool shouldShowRewardedAds(bool isLoggedIn) {
    if (!AdsConfig.adsEnabled) return false;
    return !(_subscriptionProvider?.hasPremiumFeatures ?? false);
  }

  Future<void> _loadInterstitialAd() async {
    if (_isLoadingAd || _isInterstitialAdLoaded) return;

    _isLoadingAd = true;
    notifyListeners();

    try {
      await InterstitialAd.load(
        adUnitId: AdsConfig.interstitialAdUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _interstitialAd = ad;
            _isInterstitialAdLoaded = true;
            _isLoadingAd = false;
            _retryCount = 0;
            notifyListeners();

            // Set up ad event listeners
            _interstitialAd!.fullScreenContentCallback =
                FullScreenContentCallback(
                  onAdShowedFullScreenContent: (ad) {
                    // Ad is being shown
                    _isAdShowing = true;
                  },
                  onAdDismissedFullScreenContent: (ad) {
                    // Ad was dismissed, dispose and load new ad
                    ad.dispose();
                    _isInterstitialAdLoaded = false;
                    _isAdShowing = false;
                    _lastInterstitialShown = DateTime.now();
                    notifyListeners();
                    _loadInterstitialAd();
                  },
                  onAdFailedToShowFullScreenContent: (ad, error) {
                    // Ad failed to show, dispose and load new ad
                    ad.dispose();
                    _isInterstitialAdLoaded = false;
                    _isAdShowing = false;
                    notifyListeners();
                    _loadInterstitialAd();
                  },
                );
          },
          onAdFailedToLoad: (error) {
            _isLoadingAd = false;
            _isInterstitialAdLoaded = false;
            notifyListeners();
            _handleAdLoadFailure();
          },
        ),
      );
    } catch (e) {
      _isLoadingAd = false;
      notifyListeners();
      _handleAdLoadFailure();
    }
  }

  void _handleAdLoadFailure() {
    if (_retryCount < AdsConfig.maxRetryAttempts) {
      _retryCount++;
      Timer(AdsConfig.retryDelay, () {
        _loadInterstitialAd();
      });
    } else {
      // Max retries reached, reset retry count and try again later
      _retryCount = 0;
    }
  }

  Future<void> _loadAppOpenAd() async {
    if (_isLoadingOpenAd || _isAppOpenAdLoaded) return;

    _isLoadingOpenAd = true;
    notifyListeners();

    try {
      await AppOpenAd.load(
        adUnitId: AdsConfig.openAdUnitId,
        request: const AdRequest(),
        adLoadCallback: AppOpenAdLoadCallback(
          onAdLoaded: (ad) {
            _appOpenAd = ad;
            _isAppOpenAdLoaded = true;
            _isLoadingOpenAd = false;
            _openAdRetryCount = 0;
            notifyListeners();

            // Set up ad event listeners
            _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
              onAdShowedFullScreenContent: (ad) {
                _isOpenAdShowing = true;
              },
              onAdDismissedFullScreenContent: (ad) {
                ad.dispose();
                _isAppOpenAdLoaded = false;
                _isOpenAdShowing = false;
                _lastOpenAdShown = DateTime.now();
                notifyListeners();
                _loadAppOpenAd();
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                ad.dispose();
                _isAppOpenAdLoaded = false;
                _isOpenAdShowing = false;
                notifyListeners();
                _handleOpenAdLoadFailure();
              },
            );
          },
          onAdFailedToLoad: (error) {
            _isLoadingOpenAd = false;
            _isAppOpenAdLoaded = false;
            notifyListeners();
            _handleOpenAdLoadFailure();
          },
        ),
      );
    } catch (e) {
      _isLoadingOpenAd = false;
      notifyListeners();
      _handleOpenAdLoadFailure();
    }
  }

  void _handleOpenAdLoadFailure() {
    if (_openAdRetryCount < AdsConfig.maxRetryAttempts) {
      _openAdRetryCount++;
      Timer(AdsConfig.retryDelay, () {
        _loadAppOpenAd();
      });
    } else {
      _openAdRetryCount = 0;
    }
  }

  Future<void> _loadRewardedAd() async {
    if (_isLoadingRewardedAd || _isRewardedAdLoaded) return;

    _isLoadingRewardedAd = true;
    notifyListeners();

    try {
      await RewardedAd.load(
        adUnitId: AdsConfig.rewardedAdUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _rewardedAd = ad;
            _isRewardedAdLoaded = true;
            _isLoadingRewardedAd = false;
            _rewardedAdRetryCount = 0;
            notifyListeners();

            // Set up ad event listeners
            _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
              onAdShowedFullScreenContent: (ad) {
                _isRewardedAdShowing = true;
              },
              onAdDismissedFullScreenContent: (ad) {
                ad.dispose();
                _isRewardedAdLoaded = false;
                _isRewardedAdShowing = false;
                _lastRewardedAdShown = DateTime.now();
                notifyListeners();
                _loadRewardedAd();
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                ad.dispose();
                _isRewardedAdLoaded = false;
                _isRewardedAdShowing = false;
                notifyListeners();
                _handleRewardedAdLoadFailure();
              },
            );
          },
          onAdFailedToLoad: (error) {
            _isLoadingRewardedAd = false;
            _isRewardedAdLoaded = false;
            notifyListeners();
            _handleRewardedAdLoadFailure();
          },
        ),
      );
    } catch (e) {
      _isLoadingRewardedAd = false;
      notifyListeners();
      _handleRewardedAdLoadFailure();
    }
  }

  void _handleRewardedAdLoadFailure() {
    if (_rewardedAdRetryCount < AdsConfig.maxRetryAttempts) {
      _rewardedAdRetryCount++;
      Timer(AdsConfig.retryDelay, () {
        _loadRewardedAd();
      });
    } else {
      _rewardedAdRetryCount = 0;
    }
  }

  Future<bool> showAppOpenAd() async {
    // Check if user is subscribed (no ads for subscribers)
    if (!_shouldShowAds) {
      return false;
    }

    // Check if enough time has passed since last open ad
    if (_lastOpenAdShown != null) {
      final timeSinceLastAd = DateTime.now().difference(_lastOpenAdShown!);
      final cooldownDuration = AdsConfig.getOpenAdCooldown();

      if (timeSinceLastAd < cooldownDuration) {
        return false;
      }
    }

    // Check if open ad is already showing
    if (_isOpenAdShowing) {
      return false;
    }

    // Check if ad is loaded and ready to show
    if (!_isAppOpenAdLoaded || _appOpenAd == null) {
      return false;
    }

    try {
      _isOpenAdShowing = true;

      await Future.delayed(AdsConfig.openAdShowDelay);
      await _appOpenAd!.show();

      return true;
    } catch (e) {
      _isOpenAdShowing = false;
      return false;
    }
  }

  Future<bool> showInterstitialAd() async {
    // Check if user is subscribed (no ads for subscribers)
    if (!_shouldShowAds) {
      return false;
    }

    // Check if enough time has passed since last interstitial
    if (_lastInterstitialShown != null) {
      final timeSinceLastAd = DateTime.now().difference(
        _lastInterstitialShown!,
      );
      final minCooldown = AdsConfig.interstitialMinCooldown;

      if (timeSinceLastAd < minCooldown) {
        return false;
      }
    }

    // Check if ad is already showing
    if (_isAdShowing) {
      return false;
    }

    // Check if ad is loaded and ready to show
    if (!_isInterstitialAdLoaded || _interstitialAd == null) {
      return false;
    }

    try {
      _isAdShowing = true;

      await Future.delayed(AdsConfig.interstitialShowDelay);
      await _interstitialAd!.show();

      return true;
    } catch (e) {
      _isAdShowing = false;
      return false;
    }
  }

  Future<bool> showRewardedAd({
    required Function(int amount, String type) onRewardEarned,
    required bool isLoggedIn,
  }) async {
    // Check if user should see rewarded ads (logged in but not premium)
    if (!shouldShowRewardedAds(isLoggedIn)) {
      return false;
    }

    // Reset daily counter if needed
    _resetDailyCounterIfNeeded();

    // Check if daily limit reached
    if (_rewardedAdsShownToday >= AdsConfig.maxRewardedAdsPerDay) {
      return false;
    }

    // Check if enough time has passed since last rewarded ad
    if (_lastRewardedAdShown != null) {
      final timeSinceLastAd = DateTime.now().difference(_lastRewardedAdShown!);
      if (timeSinceLastAd < AdsConfig.rewardedAdCooldown) {
        return false;
      }
    }

    // Check if ad is already showing
    if (_isRewardedAdShowing) {
      return false;
    }

    // Check if ad is loaded and ready to show
    if (!_isRewardedAdLoaded || _rewardedAd == null) {
      return false;
    }

    try {
      _isRewardedAdShowing = true;

      await Future.delayed(AdsConfig.rewardedAdShowDelay);

      await _rewardedAd!.show(
        onUserEarnedReward: (ad, reward) {
          _rewardedAdsShownToday++;
          onRewardEarned(reward.amount.toInt(), reward.type);
        },
      );

      return true;
    } catch (e) {
      _isRewardedAdShowing = false;
      return false;
    }
  }

  void _resetDailyCounterIfNeeded() {
    if (_lastRewardedAdResetDate == null) {
      _lastRewardedAdResetDate = DateTime.now();
      return;
    }

    final now = DateTime.now();
    final difference = now.difference(_lastRewardedAdResetDate!);

    if (difference >= AdsConfig.rewardedAdDailyReset) {
      _rewardedAdsShownToday = 0;
      _lastRewardedAdResetDate = now;
      notifyListeners();
    }
  }

  void incrementActionCount() {
    notifyListeners();
  }

  Future<void> preloadNextAd() async {
    if (!_isInterstitialAdLoaded) {
      _loadInterstitialAd();
    }
  }

  Future<void> preloadNextRewardedAd() async {
    if (!_isRewardedAdLoaded) {
      _loadRewardedAd();
    }
  }

  bool canShowInterstitialAd() {
    // Check if user is subscribed (no ads for subscribers)
    if (!_shouldShowAds) {
      return false;
    }

    // Check cooldown (3 seconds)
    if (_lastInterstitialShown != null) {
      final timeSinceLastAd = DateTime.now().difference(
        _lastInterstitialShown!,
      );
      if (timeSinceLastAd < const Duration(seconds: 3)) {
        return false;
      }
    }

    // Check if ad is already showing
    if (_isAdShowing) {
      return false;
    }

    // Check if ad is loaded
    return _isInterstitialAdLoaded;
  }

  bool canShowAppOpenAd() {
    // Check if user is subscribed (no ads for subscribers)
    if (!_shouldShowAds) {
      return false;
    }

    // Check cooldown using dynamic cooldown
    if (_lastOpenAdShown != null) {
      final timeSinceLastAd = DateTime.now().difference(_lastOpenAdShown!);
      final cooldownDuration = AdsConfig.getOpenAdCooldown();
      if (timeSinceLastAd < cooldownDuration) {
        return false;
      }
    }

    // Check if open ad is already showing
    if (_isOpenAdShowing) {
      return false;
    }

    // Check if ad is loaded
    return _isAppOpenAdLoaded;
  }

  Future<void> preloadNextOpenAd() async {
    if (!_isAppOpenAdLoaded) {
      _loadAppOpenAd();
    }
  }

  bool canShowRewardedAd(bool isLoggedIn) {
    // Check if user should see rewarded ads (not premium users only)
    if (!shouldShowRewardedAds(isLoggedIn)) {
      return false;
    }

    // Reset daily counter if needed
    _resetDailyCounterIfNeeded();

    // Check daily limit
    if (_rewardedAdsShownToday >= AdsConfig.maxRewardedAdsPerDay) {
      return false;
    }

    // Check cooldown
    if (_lastRewardedAdShown != null) {
      final timeSinceLastAd = DateTime.now().difference(_lastRewardedAdShown!);
      if (timeSinceLastAd < AdsConfig.rewardedAdCooldown) {
        return false;
      }
    }

    // Check if ad is already showing
    if (_isRewardedAdShowing) {
      return false;
    }

    // Check if ad is loaded
    return _isRewardedAdLoaded;
  }

  int getRemainingRewardedAdsToday() {
    _resetDailyCounterIfNeeded();
    return AdsConfig.maxRewardedAdsPerDay - _rewardedAdsShownToday;
  }

  Duration? getTimeUntilNextRewardedAd() {
    if (_lastRewardedAdShown == null) return null;

    final timeSinceLastAd = DateTime.now().difference(_lastRewardedAdShown!);
    final cooldown = AdsConfig.rewardedAdCooldown;

    if (timeSinceLastAd >= cooldown) return null;

    return cooldown - timeSinceLastAd;
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  void _resetScanCounterIfNeeded() {
    final now = DateTime.now();
    if (_lastScanResetDate == null || !_isSameDay(_lastScanResetDate!, now)) {
      _scansToday = 0;
      _hasShownInterstitialAfterScans = false;
      _lastScanResetDate = now;
    }
  }

  void _resetAnalysisVisitCounterIfNeeded() {
    final now = DateTime.now();
    if (_lastAnalysisVisitResetDate == null ||
        !_isSameDay(_lastAnalysisVisitResetDate!, now)) {
      _hasVisitedAnalysisToday = false;
      _hasShownInterstitialOnAnalysisEntry = false;
      _lastAnalysisVisitResetDate = now;
    }
  }

  void trackScan() {
    _resetScanCounterIfNeeded();
    _scansToday++;
  }

  Future<bool> showInterstitialAfterScans() async {
    // Check if user is subscribed (no ads for premium users)
    if (!_shouldShowAds) {
      return false;
    }

    _resetScanCounterIfNeeded();

    // Check if we've already shown the ad after scans today
    if (_hasShownInterstitialAfterScans) {
      return false;
    }

    // Check if user has done required scans today
    if (_scansToday < AdsConfig.scansBeforeInterstitial) {
      return false;
    }

    // Check if enough time has passed since last interstitial (5 minutes)
    if (_lastInterstitialShown != null) {
      final timeSinceLastAd = DateTime.now().difference(
        _lastInterstitialShown!,
      );
      if (timeSinceLastAd < AdsConfig.interstitialMinCooldown) {
        return false;
      }
    }

    // Show the ad
    final shown = await showInterstitialAd();
    if (shown) {
      _hasShownInterstitialAfterScans = true;
    }

    return shown;
  }

  Future<bool> showInterstitialOnAnalysisEntry() async {
    // Check if user is subscribed (no ads for premium users)
    if (!_shouldShowAds) {
      return false;
    }

    _resetAnalysisVisitCounterIfNeeded();

    // Check if we've already shown the ad on analysis entry today
    if (_hasShownInterstitialOnAnalysisEntry) {
      return false;
    }

    // Check if this is the first visit today
    if (_hasVisitedAnalysisToday) {
      return false;
    }

    // Mark as visited
    _hasVisitedAnalysisToday = true;

    // Check if enough time has passed since last interstitial (5 minutes)
    if (_lastInterstitialShown != null) {
      final timeSinceLastAd = DateTime.now().difference(
        _lastInterstitialShown!,
      );
      if (timeSinceLastAd < AdsConfig.interstitialMinCooldown) {
        return false;
      }
    }

    // Show the ad
    final shown = await showInterstitialAd();
    if (shown) {
      _hasShownInterstitialOnAnalysisEntry = true;
    }

    return shown;
  }

  @override
  void dispose() {
    _interstitialAd?.dispose();
    _appOpenAd?.dispose();
    _rewardedAd?.dispose();
    super.dispose();
  }
}
