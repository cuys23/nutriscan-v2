import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:nutriscan/config/app_colors.dart';
import 'package:nutriscan/config/app_config.dart';
import 'package:nutriscan/config/app_localizations.dart';
import 'package:nutriscan/providers/payment/subscription_provider.dart';
import 'package:nutriscan/providers/theme/language_provider.dart';
import 'package:nutriscan/providers/theme/theme_provider.dart';
import 'package:nutriscan/screens/legal/privacy_policy_screen.dart';
import 'package:nutriscan/screens/legal/terms_of_service_screen.dart';
import 'package:nutriscan/services/payment/iap_service.dart';
import 'package:nutriscan/widgets/subscription/subscription_widgets.dart';
import 'package:provider/provider.dart';


class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  String _selectedPlan = 'monthly';
  List<ProductDetails> _products = [];
  bool _loadingProducts = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final products = await IAPService.instance.getProducts();
      if (mounted) {
        setState(() {
          _products = products;
          _loadingProducts = false;
        });

        if (_products.isEmpty) {
          debugPrint('IAP Error: No products found in the store. Check your configuration.');
        }
      }
    } catch (e) {
      debugPrint('IAP Error loading products: $e');
      if (mounted) {
        setState(() => _loadingProducts = false);
      }
    }
  }

  // Helper function to localize error messages
  String _getLocalizedErrorMessage(String error, String language) {
    // Map error messages to localization keys
    if (error.startsWith('Payment failed')) {
      return AppLocalizations.getString('payment_failed', language);
    } else if (error.startsWith('Invalid payment amount')) {
      return AppLocalizations.getString('invalid_payment_amount', language);
    } else if (error.startsWith('Subscription failed')) {
      return AppLocalizations.getString('subscription_error', language);
    } else if (error.startsWith('Failed to cancel subscription')) {
      return AppLocalizations.getString('cancellation_error', language);
    } else if (error.startsWith('Failed to load subscription status') ||
        error.startsWith('Failed to save subscription status')) {
      return AppLocalizations.getString('subscription_error', language);
    }
    // Return generic subscription error if no match
    return AppLocalizations.getString('subscription_error', language);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<ThemeProvider, LanguageProvider, SubscriptionProvider>(
      builder:
          (
            context,
            themeProvider,
            languageProvider,
            subscriptionProvider,
            child,
          ) {
            final isDarkMode = themeProvider.isDarkMode;

            return Scaffold(
              backgroundColor: isDarkMode
                  ? AppColors.backgroundDark
                  : AppColors.backgroundLight,
              appBar: AppBar(
                title: Text(
                  AppLocalizations.getString(
                    'premium_subscription',
                    languageProvider.currentLanguage,
                  ),
                  style: themeProvider.getFontForCurrentLanguage(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.white,
                  ),
                ),
                backgroundColor: AppColors.primary,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(IconlyLight.arrow_left, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Check if user already has premium subscription
                    if (subscriptionProvider.hasPremiumFeatures) ...[
                      // Current Subscription Status
                      _buildCurrentSubscriptionSection(
                        subscriptionProvider,
                        themeProvider,
                        languageProvider,
                        isDarkMode,
                      ),
                      const SizedBox(height: 32),

                      // Cancel Subscription Button
                      _buildCancelSubscriptionButton(
                        subscriptionProvider,
                        themeProvider,
                        languageProvider,
                        isDarkMode,
                      ),
                    ] else ...[
                      // Header Section
                      _buildHeaderSection(
                        themeProvider,
                        languageProvider,
                        isDarkMode,
                      ),
                      const SizedBox(height: 32),

                      // Features Section
                      _buildFeaturesSection(
                        themeProvider,
                        languageProvider,
                        isDarkMode,
                      ),
                      const SizedBox(height: 32),

                      // Pricing Plans
                      _buildPricingPlans(
                        themeProvider,
                        languageProvider,
                        isDarkMode,
                      ),
                      const SizedBox(height: 32),

                      // Subscribe Button
                      _buildSubscribeButton(
                        subscriptionProvider,
                        themeProvider,
                        languageProvider,
                        isDarkMode,
                      ),
                      const SizedBox(height: 20),

                      // Terms and Privacy
                      _buildTermsSection(
                        themeProvider,
                        languageProvider,
                        isDarkMode,
                        subscriptionProvider,
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
    );
  }

  Widget _buildHeaderSection(
    ThemeProvider themeProvider,
    LanguageProvider languageProvider,
    bool isDarkMode,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(IconlyBold.star, size: 48, color: Colors.white),
          ),
          const SizedBox(height: 20),
          Text(
            AppLocalizations.getString(
              'upgrade_to_premium',
              languageProvider.currentLanguage,
            ),
            style: themeProvider.getFontForCurrentLanguage(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.getString(
              'remove_ads_unlock_features',
              languageProvider.currentLanguage,
            ),
            style: themeProvider.getFontForCurrentLanguage(
              fontSize: 14,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesSection(
    ThemeProvider themeProvider,
    LanguageProvider languageProvider,
    bool isDarkMode,
  ) {
    final features = [
      {
        'icon': IconlyBold.shield_done,
        'title': AppLocalizations.getString(
          'ad_free_experience',
          languageProvider.currentLanguage,
        ),
        'description': AppLocalizations.getString(
          'ad_free_description',
          languageProvider.currentLanguage,
        ),
      },
      {
        'icon': IconlyBold.scan,
        'title': AppLocalizations.getString(
          'unlimited_scans',
          languageProvider.currentLanguage,
        ),
        'description': AppLocalizations.getString(
          'unlimited_scans_description',
          languageProvider.currentLanguage,
        ),
      },
      {
        'icon': IconlyBold.chart,
        'title': AppLocalizations.getString(
          'advanced_analytics',
          languageProvider.currentLanguage,
        ),
        'description': AppLocalizations.getString(
          'advanced_analytics_description',
          languageProvider.currentLanguage,
        ),
      },
      {
        'icon': IconlyBold.call,
        'title': AppLocalizations.getString(
          'priority_support',
          languageProvider.currentLanguage,
        ),
        'description': AppLocalizations.getString(
          'priority_support_description',
          languageProvider.currentLanguage,
        ),
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.getString(
            'premium_features',
            languageProvider.currentLanguage,
          ),
          style: themeProvider.getFontForCurrentLanguage(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isDarkMode
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: 16),
        ...features.map(
          (feature) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    feature['icon'] as IconData,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        feature['title'] as String,
                        style: themeProvider.getFontForCurrentLanguage(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        feature['description'] as String,
                        style: themeProvider.getFontForCurrentLanguage(
                          fontSize: 14,
                          color: isDarkMode
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPricingPlans(
    ThemeProvider themeProvider,
    LanguageProvider languageProvider,
    bool isDarkMode,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.getString(
            'choose_your_plan',
            languageProvider.currentLanguage,
          ),
          style: themeProvider.getFontForCurrentLanguage(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isDarkMode
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: 16),
        Column(
          children: [
            if (_loadingProducts)
              const Center(child: CircularProgressIndicator())
            else ...[
              _buildPlanListItem(
                AppLocalizations.getString(
                  'monthly_plan',
                  languageProvider.currentLanguage,
                ),
                _products.any((p) => p.id == AppConfig.monthlySubscriptionId)
                    ? _products.firstWhere((p) => p.id == AppConfig.monthlySubscriptionId).price
                    : '--',
                '/month',
                'monthly',
                AppLocalizations.getString(
                  'billed_monthly',
                  languageProvider.currentLanguage,
                ),
                themeProvider,
                isDarkMode,
              ),
              const SizedBox(height: 12),
              _buildPlanListItem(
                AppLocalizations.getString(
                  'yearly_plan',
                  languageProvider.currentLanguage,
                ),
                _products.any((p) => p.id == AppConfig.yearlySubscriptionId)
                    ? _products.firstWhere((p) => p.id == AppConfig.yearlySubscriptionId).price
                    : '--',
                '/year',
                'yearly',
                AppLocalizations.getString(
                  'billed_annually',
                  languageProvider.currentLanguage,
                ),
                themeProvider,
                isDarkMode,
                isPopular: true,
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildPlanListItem(
    String title,
    String price,
    String period,
    String planId,
    String description,
    ThemeProvider themeProvider,
    bool isDarkMode, {
    bool isPopular = false,
    bool isBestValue = false,
  }) {
    final languageProvider = Provider.of<LanguageProvider>(
      context,
      listen: false,
    );
    final isSelected = _selectedPlan == planId;

    return GestureDetector(
      onTap: () => setState(() => _selectedPlan = planId),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : isDarkMode
              ? AppColors.surfaceDark
              : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : isDarkMode
                ? AppColors.grey600
                : AppColors.grey300,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.2)
                  : isDarkMode
                  ? Colors.black.withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Selection indicator
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.primary : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : (isDarkMode ? AppColors.grey600 : AppColors.grey300),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(
                      IconlyBold.tick_square,
                      color: Colors.white,
                      size: 16,
                    )
                  : null,
            ),
            const SizedBox(width: 16),

            // Plan details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: themeProvider.getFontForCurrentLanguage(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isPopular) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            AppLocalizations.getString(
                              'popular',
                              languageProvider.currentLanguage,
                            ).toUpperCase(),
                            style: themeProvider.getFontForCurrentLanguage(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                      if (isBestValue) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            AppLocalizations.getString(
                              'best_value',
                              languageProvider.currentLanguage,
                            ).toUpperCase(),
                            style: themeProvider.getFontForCurrentLanguage(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: themeProvider.getFontForCurrentLanguage(
                      fontSize: 12,
                      color: isDarkMode
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),

            // Price
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      price,
                      style: themeProvider.getFontForCurrentLanguage(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      period,
                      style: themeProvider.getFontForCurrentLanguage(
                        fontSize: 12,
                        color: isDarkMode
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
                if (planId == 'yearly')
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      AppLocalizations.getString(
                        'save_percentage',
                        languageProvider.currentLanguage,
                      ),
                      style: themeProvider.getFontForCurrentLanguage(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscribeButton(
    SubscriptionProvider subscriptionProvider,
    ThemeProvider themeProvider,
    LanguageProvider languageProvider,
    bool isDarkMode,
  ) {
    return Column(
      children: [
        // Error message display
        if (subscriptionProvider.error != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(IconlyLight.danger, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getLocalizedErrorMessage(
                      subscriptionProvider.error!,
                      languageProvider.currentLanguage,
                    ),
                    style: themeProvider.getFontForCurrentLanguage(
                      fontSize: 14,
                      color: Colors.red[700],
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => subscriptionProvider.clearError(),
                  icon: Icon(
                    IconlyLight.close_square,
                    color: Colors.red[700],
                    size: 18,
                  ),
                ),
              ],
            ),
          ),

        // Subscribe button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: subscriptionProvider.isLoading
                ? null
                : () async {
                    // Clear any previous errors
                    subscriptionProvider.clearError();

                    // If no products loaded, show the error dialog
                    if (_products.isEmpty) {
                      StoreErrorDialog.show(context);
                      return;
                    }

                    bool success = false;
                    // Direct subscription
                    if (_selectedPlan == 'monthly') {
                      success = await subscriptionProvider.subscribeMonthly();
                    } else if (_selectedPlan == 'yearly') {
                      success = await subscriptionProvider.subscribeYearly();
                    }

                    if (success && mounted) {
                      Navigator.of(context).pop();
                    } else if (subscriptionProvider.error != null && mounted) {
                      // Error is already displayed above the button
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: subscriptionProvider.isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    AppLocalizations.getString(
                      'subscribe_now',
                      languageProvider.currentLanguage,
                    ),
                    style: themeProvider.getFontForCurrentLanguage(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildTermsSection(
    ThemeProvider themeProvider,
    LanguageProvider languageProvider,
    bool isDarkMode,
    SubscriptionProvider subscriptionProvider,
  ) {
    return Column(
      children: [
        Text(
          AppLocalizations.getString(
            'subscription_terms_detailed',
            languageProvider.currentLanguage,
          ),
          style: themeProvider.getFontForCurrentLanguage(
            fontSize: 12,
            color: isDarkMode
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TermsOfServiceScreen()),
                );
              },
              child: Text(
                AppLocalizations.getString(
                  'terms_of_service',
                  languageProvider.currentLanguage,
                ),
                style: themeProvider.getFontForCurrentLanguage(
                  fontSize: 12,
                  color: AppColors.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            Text(
              ' • ',
              style: TextStyle(
                color: isDarkMode
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
                );
              },
              child: Text(
                AppLocalizations.getString(
                  'privacy_policy',
                  languageProvider.currentLanguage,
                ),
                style: themeProvider.getFontForCurrentLanguage(
                  fontSize: 12,
                  color: AppColors.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () async {
            final scaffoldMessenger = ScaffoldMessenger.of(context);
            final success = await subscriptionProvider.restoreSubscription();
            if (success) {
              scaffoldMessenger.showSnackBar(
                const SnackBar(
                  content: Text('Subscription successfully restored from cloud!'),
                  backgroundColor: Colors.green,
                ),
              );
            } else {
              scaffoldMessenger.showSnackBar(
                SnackBar(
                  content: Text(subscriptionProvider.error ?? 'Restoration failed'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          child: Text(
            'Already subscribed? Restore',
            style: themeProvider.getFontForCurrentLanguage(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentSubscriptionSection(
    SubscriptionProvider subscriptionProvider,
    ThemeProvider themeProvider,
    LanguageProvider languageProvider,
    bool isDarkMode,
  ) {
    final subscriptionType = subscriptionProvider.subscriptionType ?? 'Unknown';
    String planName = '';
    String planDescription = '';
    IconData planIcon = IconlyBold.star;

    switch (subscriptionType) {
        case 'monthly':
          planName = AppLocalizations.getString(
            'monthly_plan',
            languageProvider.currentLanguage,
          );
          planDescription = AppLocalizations.getString(
            'billed_monthly_desc',
            languageProvider.currentLanguage,
          );
          planIcon = IconlyBold.calendar;
          break;
        case 'yearly':
          planName = AppLocalizations.getString(
            'yearly_plan',
            languageProvider.currentLanguage,
          );
          planDescription = AppLocalizations.getString(
            'billed_annually_desc',
            languageProvider.currentLanguage,
          );
          planIcon = IconlyBold.calendar;
          break;
      }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(IconlyBold.tick_square, size: 32, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  AppLocalizations.getString(
                    'active_premium_subscription',
                    languageProvider.currentLanguage,
                  ),
                  style: themeProvider.getFontForCurrentLanguage(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Plan Details
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(planIcon, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            planName,
                            style: themeProvider.getFontForCurrentLanguage(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            planDescription,
                            style: themeProvider.getFontForCurrentLanguage(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelSubscriptionButton(
    SubscriptionProvider subscriptionProvider,
    ThemeProvider themeProvider,
    LanguageProvider languageProvider,
    bool isDarkMode,
  ) {
    return Column(
      children: [
        // Warning message
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(IconlyLight.danger, color: AppColors.primary, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  AppLocalizations.getString(
                    'cancel_subscription_warning',
                    languageProvider.currentLanguage,
                  ),
                  style: themeProvider.getFontForCurrentLanguage(
                    fontSize: 14,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Cancel button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: subscriptionProvider.isLoading
                ? null
                : () => _showCancelConfirmationDialog(
                    subscriptionProvider,
                    themeProvider,
                    languageProvider,
                    isDarkMode,
                  ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: subscriptionProvider.isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(IconlyLight.close_square, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        AppLocalizations.getString(
                          'cancel_subscription',
                          languageProvider.currentLanguage,
                        ),
                        style: themeProvider.getFontForCurrentLanguage(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  void _showCancelConfirmationDialog(
    SubscriptionProvider subscriptionProvider,
    ThemeProvider themeProvider,
    LanguageProvider languageProvider,
    bool isDarkMode,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 20,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? AppColors.surfaceDark
                  : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Warning Icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    IconlyBold.danger,
                    size: 32,
                    color: Colors.red[600],
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                Text(
                  AppLocalizations.getString(
                    'cancel_subscription_question',
                    languageProvider.currentLanguage,
                  ),
                  style: themeProvider.getFontForCurrentLanguage(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // Description
                Text(
                  AppLocalizations.getString(
                    'cancel_subscription_description',
                    languageProvider.currentLanguage,
                  ),
                  style: themeProvider.getFontForCurrentLanguage(
                    fontSize: 14,
                    color: isDarkMode
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Warning Box
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        IconlyLight.info_circle,
                        color: Colors.orange[700],
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          AppLocalizations.getString(
                            'resubscribe_info',
                            languageProvider.currentLanguage,
                          ),
                          style: themeProvider.getFontForCurrentLanguage(
                            fontSize: 12,
                            color: Colors.orange[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Action Buttons
                Column(
                  children: [
                    // Keep Subscription Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary.withValues(
                            alpha: 0.1,
                          ),
                          foregroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                          shadowColor: Colors.transparent,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              IconlyBold.tick_square,
                              size: 20,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              AppLocalizations.getString(
                                'keep_subscription',
                                languageProvider.currentLanguage,
                              ),
                              style: themeProvider.getFontForCurrentLanguage(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Cancel Subscription Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.of(context).pop();
                          await subscriptionProvider.cancelSubscription();
                          if (mounted) {
                            // Subscription cancelled - no snackbar shown
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[600],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 2,
                          shadowColor: Colors.red.withValues(alpha: 0.3),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              IconlyBold.close_square,
                              size: 20,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              AppLocalizations.getString(
                                'cancel_subscription',
                                languageProvider.currentLanguage,
                              ),
                              style: themeProvider.getFontForCurrentLanguage(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
