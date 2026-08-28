import 'package:cloud_firestore/cloud_firestore.dart';
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
  
  /// ⚠️ PRODUCTION WARNING:
  /// For production-grade security, subscription status SHOULD be verified 
  /// server-side using App Store/Play Store Server Notifications or Receipt 
  /// Validation. Local state is encrypted via Flutter Secure Storage but 
  /// can still be targeted by advanced client-side manipulation tools.
  /// Ensure you deploy a Firebase Cloud Function for robust validation.
  
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

  void _onPurchaseSuccess(PurchaseDetails purchase) async {
    _isSubscribed = true;
    
    // Determine type based on product ID
    if (purchase.productID == IAPService.monthlySubscriptionId) {
      _subscriptionType = 'monthly';
    } else if (purchase.productID == IAPService.yearlySubscriptionId) {
      _subscriptionType = 'yearly';
    }

    await _saveSubscriptionStatus();
    
    if (_notificationProvider != null) {
      await _notificationProvider!.cancelPremiumPromotionForPremiumUser();
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
          await _saveSubscriptionStatus(syncToFirestore: false);
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Firestore Sync Error: $e');
    }
  }

  // NOTE: Subscription status in Firestore should ONLY be updated by a
  // server-side Cloud Function that validates receipts with Apple/Google.
  // Client-side writes to the subscription field are blocked by Firestore Rules.
  // This method is intentionally a no-op to prevent client-side tampering.
  // 
  // TODO: Deploy a Firebase Cloud Function that:
  //   1. Receives App Store / Play Store server notifications
  //   2. Validates the receipt with Apple/Google
  //   3. Updates the Firestore subscription field accordingly
  Future<void> _updateFirestoreSubscription() async {
    // Server-side only — no client-side Firestore write for subscription
    debugPrint('Subscription status saved locally. Firestore sync is handled server-side.');
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

  // Save subscription status to secure storage
  Future<void> _saveSubscriptionStatus({bool syncToFirestore = true}) async {
    try {
      await _secureStorage.write(key: 'is_subscribed', value: _isSubscribed.toString());
      await _secureStorage.write(key: 'subscription_type', value: _subscriptionType ?? '');

      if (syncToFirestore) {
        await _updateFirestoreSubscription();
      }
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
