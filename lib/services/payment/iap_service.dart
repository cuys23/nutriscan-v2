import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:nutriscan/config/app_config.dart';
import 'package:url_launcher/url_launcher.dart';

class IAPService {
  IAPService._();
  static final IAPService instance = IAPService._();

  final InAppPurchase _iap = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  
  // Product IDs
  static const String monthlySubscriptionId = AppConfig.monthlySubscriptionId;
  static const String yearlySubscriptionId = AppConfig.yearlySubscriptionId;
  
  static const Set<String> _productIds = {
    monthlySubscriptionId,
    yearlySubscriptionId,
  };

  bool _available = false;
  List<ProductDetails> _products = [];
  Function(PurchaseDetails)? _onPurchaseSuccess;
  Function(String)? _onPurchaseError;

  void initialize({
    required Function(PurchaseDetails) onPurchaseSuccess,
    required Function(String) onPurchaseError,
  }) {
    _onPurchaseSuccess = onPurchaseSuccess;
    _onPurchaseError = onPurchaseError;

    final Stream<List<PurchaseDetails>> purchaseUpdated = _iap.purchaseStream;
    _subscription = purchaseUpdated.listen(
      _onPurchaseUpdate,
      onDone: () => _subscription.cancel(),
      onError: (error) => _onPurchaseError?.call(error.toString()),
    );
    
    _checkAvailability();
  }

  Future<void> _checkAvailability() async {
    _available = await _iap.isAvailable();
    if (_available) {
      await _loadProducts();
    }
  }

  Future<void> _loadProducts() async {
    final ProductDetailsResponse response = await _iap.queryProductDetails(_productIds);
    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('Products not found: ${response.notFoundIDs}');
    }
    _products = response.productDetails;
  }

  Future<List<ProductDetails>> getProducts() async {
    if (_products.isEmpty) {
      await _loadProducts();
    }
    return _products;
  }

  Future<bool> buySubscription(String productId) async {
    if (!_available) return false;

    ProductDetails? product;
    try {
      product = _products.firstWhere((p) => p.id == productId);
    } catch (e) {
      // Products might not be loaded yet
      await _loadProducts();
      try {
        product = _products.firstWhere((p) => p.id == productId);
      } catch (e) {
        debugPrint('Product not found: $e');
        _onPurchaseError?.call('Product not found');
        return false;
      }
    }

    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
    
    // For subscriptions, use buyNonConsumable
    return await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // Handle pending
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        _onPurchaseError?.call(purchaseDetails.error?.message ?? 'Purchase failed');
      } else if (purchaseDetails.status == PurchaseStatus.purchased ||
                 purchaseDetails.status == PurchaseStatus.restored) {
        
        // Verify purchase if needed, then complete
        _onPurchaseSuccess?.call(purchaseDetails);
        
        if (purchaseDetails.pendingCompletePurchase) {
          _iap.completePurchase(purchaseDetails);
        }
      }
    }
  }

  Future<void> restorePurchases() async {
    await _iap.restorePurchases();
  }

  /// Launch the platform-specific subscription management page
  Future<void> manageSubscriptions() async {
    final String url = Platform.isIOS
        ? 'https://apps.apple.com/account/subscriptions'
        : 'https://play.google.com/store/account/subscriptions';
    
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      debugPrint('Could not launch subscription management URL: $url');
    }
  }

  void dispose() {
    _subscription.cancel();
  }
}
