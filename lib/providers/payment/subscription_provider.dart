import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:nutriscan/config/firebase_config.dart';
import 'package:nutriscan/providers/auth/cloud_backup_provider.dart';
import 'package:nutriscan/providers/notifications/notification_provider.dart';
import 'package:nutriscan/services/payment/iap_service.dart';

class SubscriptionProvider with ChangeNotifier {
  NotificationProvider? _notificationProvider;
  bool _isSubscribed = false;
  bool _isLoading = false;
  String? _subscriptionType;
  String? _error;
  
  /// Purchases are verified server-side by the `verifyPurchase` Cloud
  /// Function (functions/src/index.ts), which checks the receipt with
  /// Apple/Google and is the only writer of `subscription` on `/users/{uid}`
  /// — firestore.rules blocks clients from writing that field.
  /// [_onPurchaseSuccess] calls that function and then re-reads Firestore
  /// rather than trusting the client-side PurchaseDetails, which a
  /// device-side tool can forge.
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  CloudBackupProvider? _backupProvider;

  // Getters
  bool get isSubscribed => _isSubscribed;
  bool get isLoading => _isLoading;
  String? get subscriptionType => _subscriptionType;
  String? get error => _error;

  // Check if subscription is active
  bool get isSubscriptionActive {
    return _isSubscribed;
  }

  // Check if user has premium features (only subscribed)
  bool get hasPremiumFeatures => isSubscriptionActive;

  SubscriptionProvider() {
    _loadSubscriptionStatus();
    _initializeIAP();
  }

  void _initializeIAP() {
    IAPService.instance.initialize(
      onPurchaseSuccess: _onPurchaseSuccess,
      onPurchaseError: _onPurchaseError,
    );
  }

  Future<void> _onPurchaseSuccess(PurchaseDetails purchase) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await FirebaseFunctions.instance
          .httpsCallable('verifyPurchase')
          .call<Map<String, dynamic>>({
            'platform': Platform.isIOS ? 'ios' : 'android',
            'productId': purchase.productID,
            'verificationData':
                purchase.verificationData.serverVerificationData,
          });

      // The Cloud Function is the only writer of `subscription` — re-read it
      // instead of setting premium from the client-side purchase event.
      await _syncWithFirestore();

      if (_notificationProvider != null) {
        await _notificationProvider!.cancelPremiumPromotionForPremiumUser();
      }
    } catch (e) {
      debugPrint('Purchase verification failed: $e');
      // Deliberately leaves _isSubscribed as it was: an unverified purchase
      // must not grant premium, and the transaction is still completed by
      // IAPService so it cannot hang or auto-refund.
      _error = e is FirebaseFunctionsException && e.code == 'unauthenticated'
          ? 'Please sign in, then use "Restore Purchases" to activate your subscription.'
          : 'Could not verify your purchase. Try "Restore Purchases", or contact support if this continues.';
    }

    _isLoading = false;
    notifyListeners();
  }

  void _onPurchaseError(String errorMessage) {
    _error = errorMessage;
    _isLoading = false;
    notifyListeners();
  }

  // Set notification provider reference
  void setNotificationProvider(NotificationProvider provider) {
    _notificationProvider = provider;
  }

  // Set cloud backup provider reference and sync
  void setAuth(CloudBackupProvider provider) {
    _backupProvider = provider;
    if (_backupProvider!.isSignedIn) {
      _syncWithFirestore();
    }
  }

  // Sync subscription status with Firestore
  Future<void> _syncWithFirestore() async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (userId.isEmpty) return;

    try {
      final doc = await _firestore.collection(FirebaseConfig.usersCollection).doc(userId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (data.containsKey(FirebaseConfig.subscriptionField)) {
          final sub = data[FirebaseConfig.subscriptionField] as Map<String, dynamic>;
          
          _isSubscribed = sub[FirebaseConfig.isSubscribedField] ?? false;
          _subscriptionType = sub[FirebaseConfig.subscriptionTypeField];

          // Save locally as well
          await _saveSubscriptionStatus();
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Firestore Sync Error: $e');
    }
  }

  // Restore subscription manually
  Future<bool> restoreSubscription() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // First try to restore IAP purchases from store
      await IAPService.instance.restorePurchases();
      
      // Then sync with Firestore if signed in
      if (_backupProvider != null && _backupProvider!.isSignedIn) {
        await _syncWithFirestore();
      }
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to restore: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Load subscription status from secure storage
  Future<void> _loadSubscriptionStatus() async {
    try {
      final subStr = await _secureStorage.read(key: 'is_subscribed');
      _isSubscribed = subStr == 'true';
      _subscriptionType = await _secureStorage.read(key: 'subscription_type');

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading secure subscription status: $e');
      _error = 'Failed to load subscription status';
      notifyListeners();
    }
  }

  /// Caches the verified status locally so the UI is right on next launch
  /// before Firestore has been re-read. Firestore stays the source of truth
  /// and only `verifyPurchase` writes it.
  Future<void> _saveSubscriptionStatus() async {
    try {
      await _secureStorage.write(key: 'is_subscribed', value: _isSubscribed.toString());
      await _secureStorage.write(key: 'subscription_type', value: _subscriptionType ?? '');
    } catch (e) {
      debugPrint('Error saving secure subscription status: $e');
      _error = 'Failed to save subscription status';
      notifyListeners();
    }
  }

  // Subscribe to monthly plan
  Future<bool> subscribeMonthly() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    final success = await IAPService.instance.buySubscription(IAPService.monthlySubscriptionId);
    if (!success) {
      _isLoading = false;
      notifyListeners();
    }
    return success;
  }

  // Subscribe to yearly plan
  Future<bool> subscribeYearly() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    final success = await IAPService.instance.buySubscription(IAPService.yearlySubscriptionId);
    if (!success) {
      _isLoading = false;
      notifyListeners();
    }
    return success;
  }

  // Cancel subscription
  Future<void> cancelSubscription() async {
    _isLoading = true;
    notifyListeners();

    try {
      // In-app purchase subscriptions MUST be cancelled via the store
      await IAPService.instance.manageSubscriptions();
      
      // We don't clear local state until we get a notification from the store
      // or the user restores their status and we find it's expired.
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error opening subscription management: $e');
      _error = 'Please cancel your subscription in the App Store/Play Store settings.';
      _isLoading = false;
      notifyListeners();
    }
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Reload subscription status (public method for external use)
  Future<void> reloadSubscriptionStatus() async {
    await _loadSubscriptionStatus();
  }

  // Get subscription info for display
  Map<String, dynamic> getSubscriptionInfo() {
    return {
      'isSubscribed': _isSubscribed,
      'subscriptionType': _subscriptionType,
      'isActive': isSubscriptionActive,
      'hasPremiumFeatures': hasPremiumFeatures,
    };
  }
}
