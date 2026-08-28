import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:iconly/iconly.dart';
import 'package:intl/intl.dart';
import 'package:nutriscan/config/app_colors.dart';
import 'package:nutriscan/config/app_localizations.dart';
import 'package:nutriscan/models/chat_message.dart';
import 'package:nutriscan/providers/chat/chat_provider.dart';
import 'package:nutriscan/providers/food/food_provider.dart';
import 'package:nutriscan/providers/food/meal_plan_provider.dart';
import 'package:nutriscan/providers/theme/language_provider.dart';
import 'package:nutriscan/providers/theme/theme_provider.dart';
import 'package:nutriscan/widgets/ads/adaptive_banner_ad.dart';
import 'package:nutriscan/widgets/dialogs/confirmation_dialog.dart';
import 'package:provider/provider.dart';

class HealthCoachScreen extends StatefulWidget {
  const HealthCoachScreen({super.key});

  @override
  State<HealthCoachScreen> createState() => _HealthCoachScreenState();
}

class _HealthCoachScreenState extends State<HealthCoachScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  String _buildUserContext(BuildContext context) {
    final foodProvider = context.read<FoodProvider>();
    final mealPlanProvider = context.read<MealPlanProvider>();
    
    final target = mealPlanProvider.calorieTarget;
    final dietStyle = mealPlanProvider.dietStyle;
    final restrictions = mealPlanProvider.restrictions;
    
    final allFoods = foodProvider.foods;
    final todayFoods = foodProvider.getTodayFoodsSync();
    final todayCals = foodProvider.getTodayCaloriesSync();
    
    // Calculate 7-day averages
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    final recentFoods = allFoods.where((f) => f.analyzedAt.isAfter(sevenDaysAgo)).toList();
    
    double avgCals = 0;
    double avgProtein = 0;
    double avgCarbs = 0;
    double avgFat = 0;
    
    if (recentFoods.isNotEmpty) {
      final daysWithData = recentFoods.map((f) => "${f.analyzedAt.year}-${f.analyzedAt.month}-${f.analyzedAt.day}").toSet().length;
      final totalRecentCals = recentFoods.fold(0.0, (sum, f) => sum + f.calories);
      final totalRecentProtein = recentFoods.fold(0.0, (sum, f) => sum + f.protein);
      final totalRecentCarbs = recentFoods.fold(0.0, (sum, f) => sum + f.carbs);
      final totalRecentFat = recentFoods.fold(0.0, (sum, f) => sum + f.fat);
      
      avgCals = totalRecentCals / (daysWithData > 0 ? daysWithData : 1);
      avgProtein = totalRecentProtein / (daysWithData > 0 ? daysWithData : 1);
      avgCarbs = totalRecentCarbs / (daysWithData > 0 ? daysWithData : 1);
      avgFat = totalRecentFat / (daysWithData > 0 ? daysWithData : 1);
    }

    // Frequent foods
    final foodCounts = <String, int>{};
    for (var f in allFoods) {
      foodCounts[f.name] = (foodCounts[f.name] ?? 0) + 1;
    }
    final topFoods = (foodCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(5).map((e) => e.key).toList();

    String contextStr = "USER PROFILE & GOALS:\n";
    contextStr += "- Calorie Target: ${target.round()} kcal/day\n";
    contextStr += "- Diet Style: $dietStyle\n";
    if (restrictions.isNotEmpty) contextStr += "- Restrictions: ${restrictions.join(", ")}\n";
    
    contextStr += "\nTODAY'S PROGRESS:\n";
    contextStr += "- Foods Logged: ${todayFoods.length}\n";
    contextStr += "- Calories Consumed: ${todayCals.round()} kcal\n";
    if (todayFoods.isNotEmpty) {
      contextStr += "- Today's Items: ${todayFoods.map((f) => f.name).join(", ")}\n";
    }
    
    contextStr += "\n7-DAY AVERAGES:\n";
    contextStr += "- Avg Calories: ${avgCals.round()} kcal/day\n";
    contextStr += "- Avg Protein: ${avgProtein.round()}g, Carbs: ${avgCarbs.round()}g, Fat: ${avgFat.round()}g\n";
    
    if (topFoods.isNotEmpty) {
      contextStr += "\nTOP FREQUENT FOODS: ${topFoods.join(", ")}\n";
    }
    
    return contextStr;
  }

  void _sendMessage() {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    final chatProvider = context.read<ChatProvider>();
    final languageProvider = context.read<LanguageProvider>();
    final userContext = _buildUserContext(context);

    chatProvider.sendMessage(
      content,
      userContext: userContext,
      language: languageProvider.currentLanguage,
    );

    _messageController.clear();
    FocusScope.of(context).unfocus();
    
    // Add a small delay then scroll to bottom to show typing indicator
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<ThemeProvider, LanguageProvider, ChatProvider>(
      builder: (context, themeProvider, languageProvider, chatProvider, child) {
        final isDarkMode = themeProvider.isDarkMode;
        final currentLanguage = languageProvider.currentLanguage;

        // Auto-scroll when new messages arrive
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (chatProvider.messages.isNotEmpty) {
            _scrollToBottom();
          }
        });

        return Scaffold(
          backgroundColor: isDarkMode ? AppColors.backgroundDark : AppColors.backgroundLight,
          appBar: AppBar(
            title: Text(
              AppLocalizations.getString('health_coach_title', currentLanguage),
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
            actions: [
              IconButton(
                icon: const Icon(IconlyBold.delete, color: Colors.white),
                onPressed: () => _showClearChatDialog(context, chatProvider, currentLanguage),
                tooltip: AppLocalizations.getString('clear', currentLanguage),
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: chatProvider.messages.isEmpty
                    ? _buildWelcomeView(themeProvider, currentLanguage)
                    : _buildChatList(chatProvider, themeProvider, currentLanguage),
              ),
              _buildInputArea(themeProvider, chatProvider, currentLanguage),
              const AdaptiveBannerAd(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWelcomeView(ThemeProvider theme, String lang) {
    final isDarkMode = theme.isDarkMode;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(IconlyBold.chat, size: 64, color: AppColors.primary),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              AppLocalizations.getString('coach_welcome', lang),
              textAlign: TextAlign.center,
              style: theme.getFontForCurrentLanguage(
                fontSize: 16,
                color: isDarkMode ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatList(ChatProvider chat, ThemeProvider theme, String lang) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: chat.messages.length + (chat.isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (chat.isLoading && index == chat.messages.length) {
          return _buildTypingIndicator(theme, lang);
        }
        final message = chat.messages[index];
        return _buildMessageBubble(message, theme);
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage message, ThemeProvider theme) {
    final isUser = message.role == MessageRole.user;
    final isDarkMode = theme.isDarkMode;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) _buildAvatar(false),
          const SizedBox(width: 8),
          Flexible(
              child: Column(
                crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: isUser 
                          ? LinearGradient(
                              colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: isUser 
                          ? null 
                          : (isDarkMode ? AppColors.surfaceDark : Colors.white),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(isUser ? 20 : 0),
                        topRight: Radius.circular(isUser ? 0 : 20),
                        bottomLeft: const Radius.circular(20),
                        bottomRight: const Radius.circular(20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: !isUser ? Border.all(color: isDarkMode ? AppColors.grey800 : AppColors.grey200) : null,
                    ),
                    child: isUser 
                      ? SelectableText(
                          message.content,
                          style: theme.getFontForCurrentLanguage(
                            color: Colors.white,
                            fontSize: 15,
                            height: 1.4,
                          ),
                        )
                      : MarkdownBody(
                          data: message.content,
                          selectable: true,
                          styleSheet: MarkdownStyleSheet(
                            p: theme.getFontForCurrentLanguage(
                              color: isDarkMode
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight,
                              fontSize: 15,
                              height: 1.4,
                            ),
                            strong: theme.getFontForCurrentLanguage(
                              color: isDarkMode
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight,
                              fontSize: 15,
                              height: 1.4,
                              fontWeight: FontWeight.bold,
                            ),
                            em: theme.getFontForCurrentLanguage(
                              color: isDarkMode
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight,
                              fontSize: 15,
                              fontStyle: FontStyle.italic,
                            ),
                            listBullet: theme.getFontForCurrentLanguage(
                              color: isDarkMode
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight,
                              fontSize: 15,
                            ),
                            h1: theme.getFontForCurrentLanguage(
                              color: isDarkMode ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                            h2: theme.getFontForCurrentLanguage(
                              color: isDarkMode ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            h3: theme.getFontForCurrentLanguage(
                              color: isDarkMode ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            code: theme.getFontForCurrentLanguage(
                              color: isDarkMode ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                              fontSize: 14,
                              backgroundColor: isDarkMode ? AppColors.grey900 : AppColors.grey100,
                            ),
                            codeblockDecoration: BoxDecoration(
                              color: isDarkMode ? AppColors.grey900 : AppColors.grey100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            blockquote: theme.getFontForCurrentLanguage(
                              color: isDarkMode ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              fontSize: 15,
                              fontStyle: FontStyle.italic,
                            ),
                            tableHead: theme.getFontForCurrentLanguage(
                              color: isDarkMode ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            tableBody: theme.getFontForCurrentLanguage(
                              color: isDarkMode ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                              fontSize: 14,
                            ),
                            a: theme.getFontForCurrentLanguage(
                              color: AppColors.primary,
                              fontSize: 15,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('hh:mm a').format(message.timestamp),
                    style: theme.getFontForCurrentLanguage(
                      fontSize: 10,
                      color: isDarkMode ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
          ),
          const SizedBox(width: 8),
          if (isUser) _buildAvatar(true),
        ],
      ),
    );
  }

  Widget _buildAvatar(bool isUser) {
    return CircleAvatar(
      radius: 18,
      backgroundColor: isUser ? AppColors.grey200 : AppColors.primary.withValues(alpha: 0.1),
      child: Icon(
        isUser ? IconlyBold.profile : Icons.smart_toy_rounded,
        size: 20,
        color: isUser ? AppColors.grey600 : AppColors.primary,
      ),
    );
  }

  Widget _buildTypingIndicator(ThemeProvider theme, String lang) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildAvatar(false),
          const SizedBox(width: 8),
          Text(
            AppLocalizations.getString('typing', lang),
            style: theme.getFontForCurrentLanguage(
              fontSize: 12,
              color: theme.isDarkMode ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(ThemeProvider theme, ChatProvider chat, String lang) {
    final isDarkMode = theme.isDarkMode;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.backgroundDark : Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.05),
            blurRadius: 15,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDarkMode ? AppColors.surfaceDark : AppColors.grey100,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: isDarkMode ? AppColors.grey800 : AppColors.grey300,
                ),
              ),
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: AppLocalizations.getString('chat_placeholder', lang),
                  hintStyle: theme.getFontForCurrentLanguage(
                    color: isDarkMode ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    fontSize: 15,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                style: theme.getFontForCurrentLanguage(
                  color: isDarkMode ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  fontSize: 15,
                ),
                maxLines: 5,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: chat.isLoading ? null : _sendMessage,
            child: Container(
              height: 50,
              width: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: chat.isLoading 
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(IconlyBold.send, color: Colors.white, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showClearChatDialog(BuildContext context, ChatProvider chat, String lang) {
    showDialog(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: AppLocalizations.getString('chat_clear_confirm', lang),
        description: AppLocalizations.getString('chat_clear_description', lang),
        confirmText: AppLocalizations.getString('clear', lang),
        cancelText: AppLocalizations.getString('cancel', lang),
        icon: IconlyBold.delete,
        iconColor: Colors.red[600]!,
        iconBackgroundColor: Colors.red[50]!,
        onConfirm: () {
          chat.clearChat();
        },
      ),
    );
  }
}
