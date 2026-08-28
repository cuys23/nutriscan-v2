import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:nutriscan/config/app_colors.dart';
import 'package:nutriscan/config/app_localizations.dart';
import 'package:nutriscan/models/food.dart';
import 'package:nutriscan/providers/theme/language_provider.dart';
import 'package:nutriscan/providers/theme/theme_provider.dart';
import 'package:provider/provider.dart';

class HealthScoreChart extends StatelessWidget {
  final List<Food> foods;
  final double height;
  final String? title;

  const HealthScoreChart({
    super.key,
    required this.foods,
    this.height = 320,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, LanguageProvider>(
      builder: (context, themeProvider, languageProvider, child) {
        final isDarkMode = themeProvider.isDarkMode;
        if (foods.isEmpty) return const SizedBox.shrink();

        // Group foods by health score
        final Map<int, int> scoreDistribution = {};
        for (int i = 1; i <= 10; i++) {
          scoreDistribution[i] = 0;
        }

        for (final food in foods) {
          scoreDistribution[food.healthScore] =
              (scoreDistribution[food.healthScore] ?? 0) + 1;
        }

        final maxCount = scoreDistribution.values.fold(
          0,
          (max, count) => count > max ? count : max,
        );

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
                    AppLocalizations.getString(
                      'health_score_distribution',
                      languageProvider.currentLanguage,
                    ),
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
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceEvenly,
                    maxY: maxCount.toDouble(),
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          return BarTooltipItem(
                            '${rod.toY.toInt()}',
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 50,
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
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 50,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              value.toInt().toString(),
                              style: TextStyle(
                                fontSize: 10,
                                color: isDarkMode
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                                fontWeight: FontWeight.w500,
                              ),
                            );
                          },
                        ),
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
                    barGroups: scoreDistribution.entries.map((entry) {
                      final score = entry.key;
                      final count = entry.value;
                      Color barColor;

                      if (score >= 8) {
                        barColor = Colors.green;
                      } else if (score >= 6) {
                        barColor = Colors.orange;
                      } else {
                        barColor = Colors.red;
                      }

                      return BarChartGroupData(
                        x: score,
                        barRods: [
                          BarChartRodData(
                            toY: count.toDouble(),
                            color: barColor,
                            width: 14,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(4),
                              topRight: Radius.circular(4),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
