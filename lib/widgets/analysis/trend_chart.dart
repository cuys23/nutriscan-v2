import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:nutriscan/config/app_colors.dart';
import 'package:nutriscan/config/app_localizations.dart';
import 'package:nutriscan/models/food.dart';
import 'package:nutriscan/providers/theme/language_provider.dart';
import 'package:nutriscan/providers/theme/theme_provider.dart';
import 'package:provider/provider.dart';

class TrendChart extends StatelessWidget {
  final List<Food> foods;
  final String metric;
  final double height;
  final String? title;

  const TrendChart({
    super.key,
    required this.foods,
    required this.metric,
    this.height = 370,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, LanguageProvider>(
      builder: (context, themeProvider, languageProvider, child) {
        final isDarkMode = themeProvider.isDarkMode;
        if (foods.length < 2) return const SizedBox.shrink();

        final chartData = _prepareChartData(foods, metric);
        final maxValue = chartData.fold(
          0.0,
          (max, spot) => spot.y > max ? spot.y : max,
        );
        final minValue = chartData.fold(
          double.infinity,
          (min, spot) => spot.y < min ? spot.y : min,
        );

        // Ensure we have a valid range for the chart
        final valueRange = maxValue - minValue;
        final safeMinValue = valueRange == 0 ? minValue - 1 : minValue;
        final safeMaxValue = valueRange == 0 ? maxValue + 1 : maxValue;
        final safeRange = safeMaxValue - safeMinValue;

        return Container(
          height: height,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDarkMode ? AppColors.surfaceDark : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: isDarkMode
                    ? Colors.black.withValues(alpha: 0.3)
                    : Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title ??
                    '${AppLocalizations.getString(metric, languageProvider.currentLanguage)} ${AppLocalizations.getString('trends', languageProvider.currentLanguage)}',
                style: themeProvider.getFontForCurrentLanguage(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: isDarkMode
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: true,
                      horizontalInterval: safeRange / 4,
                      verticalInterval: 1,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: isDarkMode
                              ? AppColors.grey600.withValues(alpha: 0.3)
                              : AppColors.grey300.withValues(alpha: 0.3),
                          strokeWidth: 1,
                        );
                      },
                      getDrawingVerticalLine: (value) {
                        return FlLine(
                          color: isDarkMode
                              ? AppColors.grey600.withValues(alpha: 0.3)
                              : AppColors.grey300.withValues(alpha: 0.3),
                          strokeWidth: 1,
                        );
                      },
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 60,
                          interval: safeRange / 4,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              value.toInt().toString(),
                              style: TextStyle(
                                fontSize: 12,
                                color: isDarkMode
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                                fontWeight: FontWeight.w500,
                              ),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          interval: 1,
                          getTitlesWidget: (value, meta) {
                            if (value.toInt() < chartData.length) {
                              final food = foods[value.toInt()];
                              final date = food.analyzedAt;
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  '${date.day}/${date.month}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isDarkMode
                                        ? AppColors.textSecondaryDark
                                        : AppColors.textSecondaryLight,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              );
                            }
                            return const Text('');
                          },
                        ),
                      ),
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border.all(
                        color: isDarkMode
                            ? AppColors.grey600.withValues(alpha: 0.3)
                            : AppColors.grey300.withValues(alpha: 0.3),
                      ),
                    ),
                    minX: 0,
                    maxX: (chartData.length - 1).toDouble(),
                    minY: safeMinValue * 0.9,
                    maxY: safeMaxValue * 1.1,
                    lineBarsData: [
                      LineChartBarData(
                        spots: chartData,
                        isCurved: true,
                        color: AppColors.primary,
                        barWidth: 3,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) {
                            return FlDotCirclePainter(
                              radius: 4,
                              color: AppColors.primary,
                              strokeWidth: 2,
                              strokeColor: isDarkMode
                                  ? AppColors.surfaceDark
                                  : AppColors.surfaceLight,
                            );
                          },
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          color: AppColors.primary.withValues(alpha: 0.1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<FlSpot> _prepareChartData(List<Food> foods, String metric) {
    final sortedFoods = List<Food>.from(foods)
      ..sort((a, b) => a.analyzedAt.compareTo(b.analyzedAt));

    return sortedFoods.asMap().entries.map((entry) {
      final index = entry.key;
      final food = entry.value;
      double value;

      switch (metric) {
        case 'calories':
          value = food.calories;
          break;
        case 'protein':
          value = food.protein;
          break;
        case 'carbs':
          value = food.carbs;
          break;
        case 'fat':
          value = food.fat;
          break;
        default:
          value = food.calories;
      }

      return FlSpot(index.toDouble(), value);
    }).toList();
  }
}
