import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:nutriscan/config/app_colors.dart';
import 'package:nutriscan/config/app_localizations.dart';
import 'package:nutriscan/models/food.dart';
import 'package:nutriscan/providers/food/food_provider.dart';
import 'package:nutriscan/providers/theme/language_provider.dart';
import 'package:nutriscan/providers/theme/theme_provider.dart';
import 'package:nutriscan/widgets/ads/adaptive_banner_ad.dart';
import 'package:nutriscan/widgets/food/food_detail_card.dart';
import 'package:provider/provider.dart';


class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with TickerProviderStateMixin {
  List<Food> _filteredFoods = [];
  String _searchQuery = '';
  String _sortBy = 'date'; // 'date', 'name', 'calories'
  bool _isInitialLoading = true;
  late AnimationController _loadingController;
  late Animation<double> _loadingRotation;
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();

    // Initialize search controller
    _searchController = TextEditingController();

    // Initialize loading animation controller
    _loadingController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _loadingRotation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _loadingController, curve: Curves.linear),
    );

    // Start loading animation
    _loadingController.repeat();

    // Reduce initial delay and make loading smoother
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFoods();
    });
  }

  @override
  void dispose() {
    _loadingController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _loadFoods() async {
    try {
      final foodProvider = context.read<FoodProvider>();
      // Load foods with a 1 second delay to show loading animation
      await Future.delayed(const Duration(seconds: 1));
      await foodProvider.loadFoods();
      if (mounted) {
        setState(() {
          _isInitialLoading = false;
        });
        _applyFiltersAndSort(); // Apply filters after loading
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitialLoading = false;
        });
      }
    }
  }

  void _applyFiltersAndSort() {
    final foodProvider = context.read<FoodProvider>();
    List<Food> allFoods = foodProvider.foods;

    // Check if we need to update the filtered list
    bool needsUpdate = false;

    // Apply search filter
    List<Food> newFilteredFoods;
    if (_searchQuery.isEmpty) {
      newFilteredFoods = List.from(allFoods);
    } else {
      newFilteredFoods = allFoods.where((food) {
        return food.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            food.description.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // Apply sorting
    switch (_sortBy) {
      case 'date':
        newFilteredFoods.sort((a, b) => b.analyzedAt.compareTo(a.analyzedAt));
        break;
      case 'name':
        newFilteredFoods.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        break;
      case 'calories':
        newFilteredFoods.sort((a, b) => b.calories.compareTo(a.calories));
        break;
    }

    // Only update if the filtered list has actually changed
    if (_filteredFoods.length != newFilteredFoods.length ||
        !_areListsEqual(_filteredFoods, newFilteredFoods)) {
      _filteredFoods = newFilteredFoods;
      needsUpdate = true;
    }

    if (mounted && needsUpdate) {
      setState(() {});
    }
  }

  // Helper method to check if two food lists are equal
  bool _areListsEqual(List<Food> list1, List<Food> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (list1[i].id != list2[i].id) return false;
    }
    return true;
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    _applyFiltersAndSort();
  }

  void _onSortChanged(String? value) {
    if (value != null) {
      setState(() {
        _sortBy = value;
      });
      _applyFiltersAndSort();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, LanguageProvider>(
      builder: (context, themeProvider, languageProvider, child) {
        final isDarkMode = themeProvider.isDarkMode;
        final currentLanguage = languageProvider.currentLanguage;

        return Scaffold(
          backgroundColor: isDarkMode
              ? AppColors.backgroundDark
              : AppColors.backgroundLight,
          appBar: AppBar(
            title: Text(
              AppLocalizations.getString('food_history', currentLanguage),
              style: themeProvider.getFontForCurrentLanguage(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.white,
              ),
            ),
            backgroundColor: AppColors.primary,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(IconlyBold.delete, color: Colors.white),
                onPressed: () => _showClearAllDialog(),
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: Consumer<FoodProvider>(
                  builder: (context, foodProvider, child) {
                    // Apply filters and sort whenever the provider data changes
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!_isInitialLoading && mounted) {
                        // Only apply filters if the data has actually changed
                        final currentFoodCount = foodProvider.foods.length;
                        if (_filteredFoods.length != currentFoodCount ||
                            _filteredFoods.isEmpty && currentFoodCount > 0 ||
                            _filteredFoods.isNotEmpty &&
                                currentFoodCount == 0) {
                          _applyFiltersAndSort();
                        }
                      }
                    });

                    if (_isInitialLoading) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Rotating Loading Circle
                            AnimatedBuilder(
                              animation: _loadingController,
                              builder: (context, child) {
                                return Transform.rotate(
                                  angle: _loadingRotation.value * 2 * 3.14159,
                                  // Convert to radians
                                  child: SizedBox(
                                    width: 40,
                                    height: 40,
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        isDarkMode
                                            ? AppColors.textSecondaryDark
                                            : AppColors.textSecondaryLight,
                                      ),
                                      strokeWidth: 3,
                                      backgroundColor: isDarkMode
                                          ? AppColors.grey800
                                          : AppColors.grey200,
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 20),

                            // Loading Text
                            Text(
                              AppLocalizations.getString(
                                'loading',
                                currentLanguage,
                              ),
                              style: themeProvider.getFontForCurrentLanguage(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: isDarkMode
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight,
                                letterSpacing: 0.5,
                              ),
                            ),

                            const SizedBox(height: 8),

                            // Loading Subtitle
                            Text(
                              AppLocalizations.getString(
                                'loading_subtitle',
                                currentLanguage,
                              ),
                              style: themeProvider.getFontForCurrentLanguage(
                                fontSize: 14,
                                color: isDarkMode
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    // Show loading when refreshing data
                    if (foodProvider.isLoading && !_isInitialLoading) {
                      return Column(
                        children: [
                          // Search and Sort Bar
                          Container(
                            padding: const EdgeInsets.all(16),
                            color: isDarkMode
                                ? AppColors.surfaceDark
                                : AppColors.grey50,
                            child: Column(
                              children: [
                                // Search Bar
                                TextField(
                                  controller: _searchController,
                                  onChanged: _onSearchChanged,
                                  style: themeProvider
                                      .getFontForCurrentLanguage(
                                        fontSize: 16,
                                        color: isDarkMode
                                            ? AppColors.textPrimaryDark
                                            : AppColors.textPrimaryLight,
                                      ),
                                  decoration: InputDecoration(
                                    hintText: AppLocalizations.getString(
                                      'search_foods',
                                      currentLanguage,
                                    ),
                                    hintStyle: themeProvider
                                        .getFontForCurrentLanguage(
                                          color: isDarkMode
                                              ? AppColors.textSecondaryDark
                                              : AppColors.textSecondaryLight,
                                          fontSize: 16,
                                        ),
                                    prefixIcon: Icon(
                                      IconlyLight.search,
                                      color: isDarkMode
                                          ? AppColors.textSecondaryDark
                                          : AppColors.textSecondaryLight,
                                    ),
                                    suffixIcon: _searchQuery.isNotEmpty
                                        ? IconButton(
                                            icon: Icon(
                                              Icons.clear,
                                              color: isDarkMode
                                                  ? AppColors.textSecondaryDark
                                                  : AppColors
                                                        .textSecondaryLight,
                                            ),
                                            onPressed: () {
                                              _searchController.clear();
                                              setState(() {
                                                _searchQuery = '';
                                              });
                                              _applyFiltersAndSort();
                                            },
                                          )
                                        : null,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: isDarkMode
                                            ? AppColors.grey600
                                            : AppColors.grey300,
                                        width: 1,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: isDarkMode
                                            ? AppColors.grey600
                                            : AppColors.grey300,
                                        width: 1,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: AppColors.primary,
                                        width: 2,
                                      ),
                                    ),
                                    filled: true,
                                    fillColor: isDarkMode
                                        ? AppColors.grey900
                                        : AppColors.surfaceLight,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // Sort and Stats Row
                                Row(
                                  children: [
                                    // Sort Dropdown
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isDarkMode
                                              ? AppColors.grey900
                                              : AppColors.surfaceLight,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: isDarkMode
                                                ? AppColors.grey600
                                                : AppColors.grey300,
                                          ),
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            value: _sortBy,
                                            onChanged: _onSortChanged,
                                            dropdownColor: isDarkMode
                                                ? AppColors.grey900
                                                : AppColors.surfaceLight,
                                            items: [
                                              DropdownMenuItem(
                                                value: 'date',
                                                child: Text(
                                                  AppLocalizations.getString(
                                                    'sort_by_date',
                                                    currentLanguage,
                                                  ),
                                                  style: themeProvider
                                                      .getFontForCurrentLanguage(
                                                        color: isDarkMode
                                                            ? AppColors
                                                                  .textPrimaryDark
                                                            : AppColors
                                                                  .textPrimaryLight,
                                                      ),
                                                ),
                                              ),
                                              DropdownMenuItem(
                                                value: 'name',
                                                child: Text(
                                                  AppLocalizations.getString(
                                                    'sort_by_name',
                                                    currentLanguage,
                                                  ),
                                                  style: themeProvider
                                                      .getFontForCurrentLanguage(
                                                        color: isDarkMode
                                                            ? AppColors
                                                                  .textPrimaryDark
                                                            : AppColors
                                                                  .textPrimaryLight,
                                                      ),
                                                ),
                                              ),
                                              DropdownMenuItem(
                                                value: 'calories',
                                                child: Text(
                                                  AppLocalizations.getString(
                                                    'sort_by_calories',
                                                    currentLanguage,
                                                  ),
                                                  style: themeProvider
                                                      .getFontForCurrentLanguage(
                                                        color: isDarkMode
                                                            ? AppColors
                                                                  .textPrimaryDark
                                                            : AppColors
                                                                  .textPrimaryLight,
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Total Count
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        '${AppLocalizations.getString('total', currentLanguage)}: ${_filteredFoods.length}',
                                        style: themeProvider
                                            .getFontForCurrentLanguage(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Loading overlay for content
                          Expanded(
                            child: Container(
                              color: isDarkMode
                                  ? AppColors.backgroundDark.withValues(
                                      alpha: 0.8,
                                    )
                                  : AppColors.backgroundLight.withValues(
                                      alpha: 0.8,
                                    ),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Rotating Loading Circle
                                    AnimatedBuilder(
                                      animation: _loadingController,
                                      builder: (context, child) {
                                        return Transform.rotate(
                                          angle:
                                              _loadingRotation.value *
                                              2 *
                                              3.14159,
                                          // Convert to radians
                                          child: SizedBox(
                                            width: 32,
                                            height: 32,
                                            child: CircularProgressIndicator(
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                    isDarkMode
                                                        ? AppColors
                                                              .textSecondaryDark
                                                        : AppColors
                                                              .textSecondaryLight,
                                                  ),
                                              strokeWidth: 2.5,
                                              backgroundColor: isDarkMode
                                                  ? AppColors.grey800
                                                  : AppColors.grey200,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 16),

                                    // Loading Text
                                    Text(
                                      AppLocalizations.getString(
                                        'refreshing',
                                        currentLanguage,
                                      ),
                                      style: themeProvider
                                          .getFontForCurrentLanguage(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                            color: isDarkMode
                                                ? AppColors.textPrimaryDark
                                                : AppColors.textPrimaryLight,
                                            letterSpacing: 0.5,
                                          ),
                                    ),

                                    const SizedBox(height: 6),

                                    // Loading Subtitle
                                    Text(
                                      AppLocalizations.getString(
                                        'updating',
                                        currentLanguage,
                                      ),
                                      style: themeProvider
                                          .getFontForCurrentLanguage(
                                            fontSize: 13,
                                            color: isDarkMode
                                                ? AppColors.textSecondaryDark
                                                : AppColors.textSecondaryLight,
                                            letterSpacing: 0.3,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    return Column(
                      children: [
                        // Search and Sort Bar
                        Container(
                          padding: const EdgeInsets.all(16),
                          color: isDarkMode
                              ? AppColors.surfaceDark
                              : AppColors.grey50,
                          child: Column(
                            children: [
                              // Search Bar
                              TextField(
                                controller: _searchController,
                                onChanged: _onSearchChanged,
                                style: themeProvider.getFontForCurrentLanguage(
                                  fontSize: 16,
                                  color: isDarkMode
                                      ? AppColors.textPrimaryDark
                                      : AppColors.textPrimaryLight,
                                ),
                                decoration: InputDecoration(
                                  hintText: AppLocalizations.getString(
                                    'search_foods',
                                    currentLanguage,
                                  ),
                                  hintStyle: themeProvider
                                      .getFontForCurrentLanguage(
                                        color: isDarkMode
                                            ? AppColors.textSecondaryDark
                                            : AppColors.textSecondaryLight,
                                        fontSize: 16,
                                      ),
                                  prefixIcon: Icon(
                                    IconlyLight.search,
                                    color: isDarkMode
                                        ? AppColors.textSecondaryDark
                                        : AppColors.textSecondaryLight,
                                  ),
                                  suffixIcon: _searchQuery.isNotEmpty
                                      ? IconButton(
                                          icon: Icon(
                                            Icons.clear,
                                            color: isDarkMode
                                                ? AppColors.textSecondaryDark
                                                : AppColors.textSecondaryLight,
                                          ),
                                          onPressed: () {
                                            _searchController.clear();
                                            setState(() {
                                              _searchQuery = '';
                                            });
                                            _applyFiltersAndSort();
                                          },
                                        )
                                      : null,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: isDarkMode
                                          ? AppColors.grey600
                                          : AppColors.grey300,
                                      width: 1,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: isDarkMode
                                          ? AppColors.grey600
                                          : AppColors.grey300,
                                      width: 1,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: AppColors.primary,
                                      width: 2,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: isDarkMode
                                      ? AppColors.grey900
                                      : AppColors.surfaceLight,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Sort and Stats Row
                              Row(
                                children: [
                                  // Sort Dropdown
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDarkMode
                                            ? AppColors.grey900
                                            : AppColors.surfaceLight,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isDarkMode
                                              ? AppColors.grey600
                                              : AppColors.grey300,
                                        ),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: _sortBy,
                                          onChanged: _onSortChanged,
                                          dropdownColor: isDarkMode
                                              ? AppColors.grey900
                                              : AppColors.surfaceLight,
                                          items: [
                                            DropdownMenuItem(
                                              value: 'date',
                                              child: Text(
                                                AppLocalizations.getString(
                                                  'sort_by_date',
                                                  currentLanguage,
                                                ),
                                                style: themeProvider
                                                    .getFontForCurrentLanguage(
                                                      color: isDarkMode
                                                          ? AppColors
                                                                .textPrimaryDark
                                                          : AppColors
                                                                .textPrimaryLight,
                                                    ),
                                              ),
                                            ),
                                            DropdownMenuItem(
                                              value: 'name',
                                              child: Text(
                                                AppLocalizations.getString(
                                                  'sort_by_name',
                                                  currentLanguage,
                                                ),
                                                style: themeProvider
                                                    .getFontForCurrentLanguage(
                                                      color: isDarkMode
                                                          ? AppColors
                                                                .textPrimaryDark
                                                          : AppColors
                                                                .textPrimaryLight,
                                                    ),
                                              ),
                                            ),
                                            DropdownMenuItem(
                                              value: 'calories',
                                              child: Text(
                                                AppLocalizations.getString(
                                                  'sort_by_calories',
                                                  currentLanguage,
                                                ),
                                                style: themeProvider
                                                    .getFontForCurrentLanguage(
                                                      color: isDarkMode
                                                          ? AppColors
                                                                .textPrimaryDark
                                                          : AppColors
                                                                .textPrimaryLight,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Total Count
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '${AppLocalizations.getString('total', currentLanguage)}: ${_filteredFoods.length}',
                                      style: themeProvider
                                          .getFontForCurrentLanguage(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Food List
                        Expanded(
                          child: _filteredFoods.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        _searchQuery.isEmpty
                                            ? IconlyBold.time_circle
                                            : IconlyBold.search,
                                        size: 64,
                                        color: isDarkMode
                                            ? AppColors.textSecondaryDark
                                            : AppColors.textSecondaryLight,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        _searchQuery.isEmpty
                                            ? AppLocalizations.getString(
                                                'no_food_history',
                                                currentLanguage,
                                              )
                                            : AppLocalizations.getString(
                                                'no_foods_found',
                                                currentLanguage,
                                              ),
                                        style: themeProvider
                                            .getFontForCurrentLanguage(
                                              fontSize: 18,
                                              color: isDarkMode
                                                  ? AppColors.textPrimaryDark
                                                  : AppColors.textPrimaryLight,
                                            ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _searchQuery.isEmpty
                                            ? AppLocalizations.getString(
                                                'no_history_subtitle',
                                                currentLanguage,
                                              )
                                            : AppLocalizations.getString(
                                                'no_foods_subtitle',
                                                currentLanguage,
                                              ),
                                        style: themeProvider
                                            .getFontForCurrentLanguage(
                                              fontSize: 14,
                                              color: isDarkMode
                                                  ? AppColors.textSecondaryDark
                                                  : AppColors
                                                        .textSecondaryLight,
                                            ),
                                      ),

                                      const SizedBox(height: 32),
                                    ],
                                  ),
                                )
                              : Column(
                                  children: [
                                    Expanded(
                                      child: ListView.builder(
                                        padding: const EdgeInsets.all(16),
                                        itemCount: _filteredFoods.length,
                                        itemBuilder: (context, index) {
                                          final food = _filteredFoods[index];
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 16,
                                            ),
                                            child: FoodDetailCard(
                                              food: food,
                                              onFoodDeleted: () {
                                                // The Consumer<FoodProvider> will automatically rebuild
                                                // when the provider notifies listeners after deletion
                                                // No need to manually refresh
                                              },
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const AdaptiveBannerAd(),
            ],
          ),
        );
      },
    );
  }

  void _showClearAllDialog() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;
    final languageProvider = Provider.of<LanguageProvider>(
      context,
      listen: false,
    );
    final currentLanguage = languageProvider.currentLanguage;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? AppColors.surfaceDark
                  : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: isDarkMode
                      ? Colors.black.withValues(alpha: 0.5)
                      : Colors.black.withValues(alpha: 0.1),
                  spreadRadius: 1,
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Warning Icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Icon(
                    IconlyBold.delete,
                    size: 48,
                    color: Colors.red[600],
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                Text(
                  AppLocalizations.getString(
                    'clear_all_history',
                    currentLanguage,
                  ),
                  style: themeProvider.getFontForCurrentLanguage(
                    fontSize: 22,
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
                    'clear_history_description',
                    currentLanguage,
                  ),
                  style: themeProvider.getFontForCurrentLanguage(
                    fontSize: 15,
                    color: isDarkMode
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Action Buttons
                Row(
                  children: [
                    // Cancel Button
                    Expanded(
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? AppColors.grey800
                              : AppColors.grey100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            AppLocalizations.getString(
                              'cancel',
                              currentLanguage,
                            ),
                            style: themeProvider.getFontForCurrentLanguage(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDarkMode
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Delete Button
                    Expanded(
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.red[500],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextButton(
                          onPressed: () async {
                            final foodProvider = context.read<FoodProvider>();
                            await foodProvider.clearAllFoods();
                            if (!mounted) return;
                            _loadFoods();
                            if (!mounted) return;
                            // ignore: use_build_context_synchronously
                            Navigator.of(context).pop();
                          },
                          style: TextButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            AppLocalizations.getString(
                              'delete_all',
                              currentLanguage,
                            ),
                            style: themeProvider.getFontForCurrentLanguage(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
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
