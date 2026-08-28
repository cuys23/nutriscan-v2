import 'dart:convert';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import 'package:nutriscan/config/api_config.dart';
import 'package:nutriscan/models/chat_message.dart';
import 'package:nutriscan/models/meal_plan.dart';
import 'package:nutriscan/services/ai/image_prepare.dart';

class GroqService {
  static String get _model => ApiConfig.groqModel;

  /// Every AI call goes through this Cloud Function instead of hitting
  /// openrouter.ai directly — the API key stays server-side and the function
  /// enforces sign-in plus a real per-user daily cap (functions/src/index.ts).
  /// The callable keeps its original name so already-deployed builds keep
  /// working; only the provider behind it changed.
  final HttpsCallable _aiCallable = FirebaseFunctions.instance.httpsCallable(
    'groqChatCompletion',
    options: HttpsCallableOptions(timeout: const Duration(seconds: 120)),
  );

  /// Forwards an OpenAI-shaped chat-completions body and returns the raw
  /// response JSON, same shape the client used to get straight from the
  /// provider — so the parsing below is unchanged.
  Future<Map<String, dynamic>> _callAi(Map<String, dynamic> requestBody) async {
    final result = await _aiCallable.call<Map<String, dynamic>>(requestBody);
    return Map<String, dynamic>.from(result.data);
  }

  /// Maps a callable failure onto the same localized copy the Dio error
  /// handling used to produce, so callers and the UI see no difference.
  String _messageForCallableError(
    FirebaseFunctionsException e,
    String language,
  ) {
    switch (e.code) {
      case 'unauthenticated':
        return getLocalizedErrorMessage('login_required', language);
      case 'resource-exhausted':
        return getLocalizedErrorMessage('rate_limit', language);
      case 'deadline-exceeded':
        return getLocalizedErrorMessage('response_timeout', language);
      case 'unavailable':
        return getLocalizedErrorMessage('connection_failed', language);
      case 'invalid-argument':
        return getLocalizedErrorMessage('invalid_request', language);
      default:
        return getLocalizedErrorMessage('server_error', language, {
          'status': e.code,
        });
    }
  }

  static int? _findMatchingBraceEnd(String content, int start) {
    int depth = 0;
    bool inDouble = false;
    bool escape = false;
    for (int i = start; i < content.length; i++) {
      final c = content[i];
      if (escape) {
        escape = false;
        continue;
      }
      if (inDouble) {
        if (c == '\\') {
          escape = true;
        } else if (c == '"') {
          inDouble = false;
        }
        continue;
      }
      if (c == '"') {
        inDouble = true;
        continue;
      }
      if (c == '{') {
        depth++;
      } else if (c == '}') {
        depth--;
        if (depth == 0) return i + 1;
      }
    }
    return null;
  }

  static String _extractContentFromResponse(dynamic data) {
    if (data == null ||
        data['choices'] == null ||
        (data['choices'] as List).isEmpty) {
      return '';
    }
    final message = data['choices'][0]['message'];
    final rawContent = message?['content'];
    if (rawContent is String) return rawContent.trim();
    if (rawContent is List && rawContent.isNotEmpty) {
      final textPart = rawContent.firstWhere(
        (p) => p is Map && p['type'] == 'text',
        orElse: () => rawContent[0],
      );
      if (textPart is Map && textPart['text'] is String) {
        return (textPart['text'] as String).trim();
      }
      return rawContent.join('\n').toString().trim();
    }
    return '';
  }

  Future<bool> isFoodImage(File imageFile, {String language = 'en'}) async {
    try {
      if (!await _checkNetworkConnectivity()) {
        throw Exception(getLocalizedErrorMessage('no_internet', language));
      }
      if (!await imageFile.exists()) return false;

      int fileSize = await imageFile.length();
      if (fileSize > 10 * 1024 * 1024) return false;

      final imageDataUrl = await ImagePrepare.processAndEncodeImage(imageFile);
      final prompt = _getFoodValidationPrompt(language);

      final requestBody = {
        "model": _model,
        "messages": [
          {
            "role": "user",
            "content": [
              {"type": "text", "text": prompt},
              {
                "type": "image_url",
                "image_url": {"url": imageDataUrl},
              },
            ],
          },
        ],
        "temperature": 0.1,
        "top_p": 1,
        "max_tokens": 256,
      };

      final data = await _callAi(requestBody);

      String content = _extractContentFromResponse(data);
      if (content.isEmpty) return true;

      content = content
          .replaceAll(RegExp(r'^```(?:json)?\s*'), '')
          .replaceAll(RegExp(r'\s*```$'), '')
          .trim();

      int jsonStart = content.indexOf('{');
      int jsonEnd = content.lastIndexOf('}') + 1;
      if (jsonStart != -1 && jsonEnd > jsonStart) {
        try {
          String jsonString = content.substring(jsonStart, jsonEnd);
          Map<String, dynamic> result = json.decode(jsonString);
          if (result['is_food'] == true) return true;
          if (result['is_food'] == false) return false;
        } catch (e) {
          debugPrint('JSON parse error in food validation: $e');
        }
      }

      final lower = content.toLowerCase();
      if (lower.contains('"is_food":true') ||
          lower.contains('"is_food": true')) {
        return true;
      }
      if (lower.contains('"is_food":false') ||
          lower.contains('"is_food": false')) {
        return false;
      }

      final notFood =
          lower.contains('not a food') ||
          lower.contains('not food') ||
          lower.contains('no food') ||
          lower.contains('খাবারের ছবি নয়') ||
          lower.contains('not a food image');
      if (notFood) return false;

      if (lower.contains('is_food') && lower.contains('true')) return true;
      if (RegExp(r'\b(true|yes)\b').hasMatch(lower) &&
          (lower.contains('food') ||
              lower.contains('খাবার') ||
              lower.contains('dish') ||
              lower.contains('meal'))) {
        return true;
      }
      if (lower.contains('this is food') ||
          lower.contains('contains food') ||
          lower.contains('it is food') ||
          lower.contains('খাবারের ছবি') ||
          lower.contains('food image') ||
          lower.contains('image of food')) {
        return true;
      }

      return false;
    } on FirebaseFunctionsException catch (e) {
      // Not-signed-in and out-of-quota are hard stops: letting the permissive
      // fallback wave the image through only makes analyzeFoodImage fail a
      // second time, and the user never sees why. Surface the real reason.
      debugPrint('groqChatCompletion error in isFoodImage: ${e.code}');
      if (e.code == 'unauthenticated' || e.code == 'resource-exhausted') {
        throw Exception(_messageForCallableError(e, language));
      }
      return _fallbackFoodDetection(imageFile);
    } catch (e) {
      debugPrint('Error in isFoodImage: $e');
      try {
        return await _fallbackFoodDetection(imageFile);
      } catch (inner) {
        debugPrint('Fallback food detection failed: $inner');
        return true;
      }
    }
  }

  Future<bool> _fallbackFoodDetection(File imageFile) async {
    try {
      String fileName = imageFile.path.toLowerCase();
      List<String> foodKeywords = [
        'food', 'meal', 'lunch', 'dinner', 'breakfast', 'snack',
        'খাবার', 'খাওয়া', 'রান্না', 'ভাত', 'রুটি', 'মাছ', 'মাংস',
      ];

      for (String keyword in foodKeywords) {
        if (fileName.contains(keyword)) return true;
      }

      int fileSize = await imageFile.length();
      if (fileSize < 1024 || fileSize > 5 * 1024 * 1024) return false;

      return true;
    } catch (e) {
      debugPrint('Error in fallbackFoodDetection: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> analyzeFoodImage(
    File imageFile, {
    String language = 'en',
  }) async {
    try {
      if (!await _checkNetworkConnectivity()) {
        throw Exception(getLocalizedErrorMessage('no_internet', language));
      }

      // Compress unconditionally rather than only above a size threshold:
      // a 900KB photo is still far larger than the model needs, and the old
      // gate guarded a stub that returned the original bytes anyway.
      final imageDataUrl = await ImagePrepare.processAndEncodeImage(imageFile);
      final prompt = _getLocalizedPrompt(language);

      final requestBody = {
        "model": _model,
        "messages": [
          {
            "role": "user",
            "content": [
              {"type": "text", "text": prompt},
              {
                "type": "image_url",
                "image_url": {"url": imageDataUrl},
              },
            ],
          },
        ],
        "temperature": 0.4,
        "top_p": 1,
        "max_tokens": 2048,
      };

      final data = await _callAi(requestBody);

      final content = _extractContentFromResponse(data);
      if (content.isEmpty) {
        throw Exception(getLocalizedErrorMessage('parse_error', language));
      }
      final jsonStart = content.indexOf('{');
      final jsonEnd = content.lastIndexOf('}') + 1;
      if (jsonStart == -1 || jsonEnd <= jsonStart) {
        throw Exception(getLocalizedErrorMessage('parse_error', language));
      }
      return json.decode(content.substring(jsonStart, jsonEnd))
          as Map<String, dynamic>;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('groqChatCompletion error in analyzeFoodImage: ${e.code}');
      throw Exception(_messageForCallableError(e, language));
    } catch (e) {
      debugPrint('General error in analyzeFoodImage: $e');
      rethrow;
    }
  }

  String getLocalizedErrorMessage(
    String errorKey,
    String language, [
    Map<String, String>? params,
  ]) {
    Map<String, Map<String, String>> errorMessages = {
      'en': {
        'no_internet': 'No internet connection. Please check your network and try again.',
        'login_required': 'Please sign in to use AI features.',
        'parse_error': 'Could not parse JSON response from AI',
        'api_failed': 'API request failed with status: {status}',
        'network_error': 'Network error occurred',
        'connection_timeout': 'Connection timeout. Please check your internet speed and try again.',
        'response_timeout': 'Response timeout. The server is taking too long to respond.',
        'connection_failed': 'Connection failed. Please check your internet connection and try again.',
        'invalid_request': 'Invalid request. Please try with a different image.',
        'invalid_api_key': 'API key is invalid. Please check your configuration.',
        'access_denied': 'Access denied. Please check your API key permissions.',
        'rate_limit': 'Rate limit exceeded. Please wait a moment and try again.',
        'server_error': 'Server error ({status}). Please try again later.',
        'network_error_generic': 'Network error: {message}',
      },
      'bn': {
        'no_internet': 'ইন্টারনেট সংযোগ নেই। অনুগ্রহ করে আপনার নেটওয়ার্ক পরীক্ষা করুন এবং আবার চেষ্টা করুন।',
        'login_required': 'AI ফিচার ব্যবহার করতে অনুগ্রহ করে সাইন ইন করুন।',
        'parse_error': 'AI থেকে JSON প্রতিক্রিয়া পার্স করতে পারেনি',
        'api_failed': 'API অনুরোধ ব্যর্থ হয়েছে স্ট্যাটাস: {status}',
        'network_error': 'নেটওয়ার্ক ত্রুটি ঘটেছে',
        'connection_timeout': 'সংযোগ টাইমআউট। অনুগ্রহ করে আপনার ইন্টারনেট গতি পরীক্ষা করুন এবং আবার চেষ্টা করুন।',
        'response_timeout': 'প্রতিক্রিয়া টাইমআউট। সার্ভার প্রতিক্রিয়া দিতে খুব বেশি সময় নিচ্ছে।',
        'connection_failed': 'সংযোগ ব্যর্থ হয়েছে। অনুগ্রহ করে আপনার ইন্টারনেট সংযোগ পরীক্ষা করুন এবং আবার চেষ্টা করুন।',
        'invalid_request': 'অবৈধ অনুরোধ। অনুগ্রহ করে একটি ভিন্ন ছবি দিয়ে চেষ্টা করুন।',
        'invalid_api_key': 'API কী অবৈধ। অনুগ্রহ করে আপনার কনফিগারেশন পরীক্ষা করুন।',
        'access_denied': 'অ্যাক্সেস অস্বীকৃত। অনুগ্রহ করে আপনার API কী অনুমতি পরীক্ষা করুন।',
        'rate_limit': 'হার সীমা অতিক্রম করেছে। অনুগ্রহ করে একটু অপেক্ষা করুন এবং আবার চেষ্টা করুন।',
        'server_error': 'সার্ভার ত্রুটি ({status})। অনুগ্রহ করে পরে আবার চেষ্টা করুন।',
        'network_error_generic': 'নেটওয়ার্ক ত্রুটি: {message}',
      },
    };

    final langMap = errorMessages[language] ?? errorMessages['en']!;
    String message = langMap[errorKey] ?? langMap['network_error']!;

    params?.forEach((key, value) {
      message = message.replaceAll('{$key}', value);
    });

    return message;
  }

  String _getFoodValidationPrompt(String language) {
    switch (language) {
      case 'bn':
        return """ছবিতে খাবার আছে কিনা যাচাই করুন। উত্তর শুধুমাত্র এই JSON ফরম্যাটে দিন:
{"is_food": true/false, "confidence": 0.95}

নিয়ম:
- ছবিতে যেকোনো খাবার থাকলে is_food: true দিন (ভাত, রুটি, মাছ, মাংস, সবজি, ফল, পানীয়, স্ন্যাকস, প্যাকেট/ক্যান/বোতলের খাবার, প্লেটে খাবার, টেবিলে খাবার, মানুষ সহ খাবারের ছবি)
- শুধুমাত্র যখন ছবিতে কোনো খাবার নেই (শুধু মানুষ, প্রাণী, গাড়ি, দৃশ্য, বস্তু) তখনই is_food: false দিন
- সন্দেহ থাকলে true দিন। শুধুমাত্র JSON লিখুন।""";
      default:
        return """Decide if this image contains any food. Reply with ONLY this JSON (no other text):
{"is_food": true/false, "confidence": 0.95}

Rules:
- Set is_food to true if the image shows ANY food: meals, dishes, drinks, snacks, fruits, vegetables, packaged food, food on plate/table, or person with food.
- Set is_food to false ONLY when there is clearly NO food (e.g. only person, animal, car, landscape, object with no food).
- When unsure, use true. Output only the JSON object.""";
    }
  }

  static const String _foodAnalysisJsonSchema = '''
{
  "food_name": "string",
  "description": "string",
  "calories": 0,
  "protein": 0,
  "carbs": 0,
  "fat": 0,
  "fiber": 0,
  "sugar": 0,
  "sodium": 0,
  "health_score": 0,
  "health_benefits": ["benefit 1", "benefit 2"],
  "health_warnings": ["warning 1", "warning 2"],
  "serving_size": "string"
}''';

  static const String _mealPlanJsonSchema = '''
{
  "plan_title": "string",
  "goal_summary": "string",
  "target_calories": 2000,
  "nutrition_overview": {
    "total_calories": 2000,
    "protein": 100,
    "carbs": 250,
    "fat": 65,
    "fiber": 30,
    "sugar": 50
  },
  "meals": [
    {
      "type": "breakfast",
      "title": "string",
      "description": "string",
      "calories": 500,
      "protein": 25,
      "carbs": 60,
      "fat": 15,
      "ingredients": ["item 1", "item 2"],
      "instructions": ["step 1", "step 2"]
    }
  ],
  "hydration_reminders": ["tip 1", "tip 2"],
  "lifestyle_tips": ["tip 1", "tip 2"],
  "grocery_list": ["item 1", "item 2"]
}''';

  static String _languageNameForModel(String code) {
    switch (code) {
      case 'bn': return 'Bangla';
      case 'hi': return 'Hindi';
      case 'es': return 'Spanish';
      case 'fr': return 'French';
      case 'de': return 'German';
      case 'zh': return 'Chinese';
      case 'tr': return 'Turkish';
      case 'ko': return 'Korean';
      case 'id': return 'Indonesian';
      case 'ja': return 'Japanese';
      case 'ru': return 'Russian';
      case 'ur': return 'Urdu';
      case 'pt': case 'pt-BR': return 'Portuguese';
      case 'ar': return 'Arabic';
      default: return 'English';
    }
  }

  String _getLocalizedPrompt(String language) {
    final langName = _languageNameForModel(language);
    return '''You are a nutrition expert. Analyze the food image and return exactly one JSON object.

CRITICAL LANGUAGE RULE: The user's app language is $langName (code: $language). You MUST write ALL text fields in $langName only—no English for bn/hi/es/fr/de/zh/tr/ko/id/ja/ru/ur/pt/ar:
- "food_name" in $langName.
- "description" in $langName: 1–3 sentences speaking directly to the user as advice.
- "serving_size" and "notes" in $langName.

Schema:
$_foodAnalysisJsonSchema

Rules:
- healthScore: integer 1–10 based on nutrition.
- Respond with ONLY one valid JSON object. No markdown.''';
  }

  Future<MealPlan> generateMealPlan({
    required int targetCalories,
    required String dietStyle,
    required int mealsPerDay,
    List<String> restrictions = const [],
    String language = 'en',
    String? userNutritionContext,
  }) async {
    try {
      if (!await _checkNetworkConnectivity()) {
        throw Exception(getLocalizedErrorMessage('no_internet', language));
      }

      final prompt = _getMealPlanPrompt(
        language: language,
        targetCalories: targetCalories,
        dietStyle: dietStyle,
        mealsPerDay: mealsPerDay,
        restrictions: restrictions,
        userNutritionContext: userNutritionContext,
      );

      final requestBody = {
        // Was hardcoded to a Groq-only llama id, which no longer resolves on
        // OpenRouter — all paths now use the single configured model.
        "model": _model,
        "messages": [
          {"role": "user", "content": prompt},
        ],
        "temperature": 0.45,
        "top_p": 0.95,
        "max_tokens": 8192,
        // Honoured by the Cloud Function's fetch abort, replacing the Dio
        // per-request receiveTimeout this call used to set.
        "receiveTimeoutMs": 90000,
      };

      final data = await _callAi(requestBody);

      String content = _extractContentFromResponse(data);
      if (content.isEmpty) throw Exception(getLocalizedErrorMessage('parse_error', language));
      content = content.replaceAll(RegExp(r'^```(?:json)?\s*'), '').replaceAll(RegExp(r'\s*```\s*$'), '').trim();
      final jsonStart = content.indexOf('{');
      if (jsonStart == -1) throw Exception(getLocalizedErrorMessage('parse_error', language));
      final jsonEnd = _findMatchingBraceEnd(content, jsonStart);
      if (jsonEnd == null) throw Exception(getLocalizedErrorMessage('parse_error', language));
      final jsonString = content.substring(jsonStart, jsonEnd);
      final Map<String, dynamic> result = json.decode(jsonString) as Map<String, dynamic>;
      return MealPlan.fromMap(result);
    } on FirebaseFunctionsException catch (e) {
      debugPrint('groqChatCompletion error in generateMealPlan: ${e.code}');
      throw Exception(_messageForCallableError(e, language));
    } catch (e) {
      debugPrint('Error in generateMealPlan: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchInsights(
    List<Map<String, dynamic>> foodData, {
    String language = 'en',
  }) async {
    try {
      if (!await _checkNetworkConnectivity()) throw Exception(getLocalizedErrorMessage('no_internet', language));

      final requestBody = {
        "model": _model,
        "messages": [{"role": "user", "content": _getInsightsPrompt(language, foodData)}],
        "temperature": 0.3, "top_p": 1, "max_tokens": 2048,
      };

      final data = await _callAi(requestBody);
      final content = _extractContentFromResponse(data);
      final jsonStart = content.indexOf('[');
      final jsonEnd = content.lastIndexOf(']') + 1;
      if (jsonStart != -1 && jsonEnd > jsonStart) {
        return (json.decode(content.substring(jsonStart, jsonEnd)) as List).cast<Map<String, dynamic>>();
      }
      throw Exception(getLocalizedErrorMessage('parse_error', language));
    } on FirebaseFunctionsException catch (e) {
      debugPrint('groqChatCompletion error in fetchInsights: ${e.code}');
      throw Exception(_messageForCallableError(e, language));
    } catch (e) {
      debugPrint('Error in fetchInsights: $e');
      rethrow;
    }
  }

  String _getMealPlanPrompt({
    required String language,
    required int targetCalories,
    required String dietStyle,
    required int mealsPerDay,
    required List<String> restrictions,
    String? userNutritionContext,
  }) {
    final langName = _languageNameForModel(language);
    return '''As a nutrition expert, generate a $mealsPerDay meal plan for exactly $targetCalories kcal daily ($dietStyle diet) in $langName.
The plan must strictly follow the provided JSON schema.

User restrictions/preferences: ${restrictions.isEmpty ? 'None' : restrictions.join(', ')}
${userNutritionContext != null ? 'User health context: $userNutritionContext' : ''}

CRITICAL: Return ONLY the JSON object. ALL text fields must be in $langName.
Schema:
$_mealPlanJsonSchema''';
  }

  String _getInsightsPrompt(String language, List<Map<String, dynamic>> foodData) {
    return "As a dietary advisor, analyze this food history and provide exactly 3-5 actionable insights in ${_languageNameForModel(language)} as a JSON array of objects with 'title' and 'insight' fields. Data: ${jsonEncode(foodData)}";
  }

  Future<bool> _checkNetworkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      debugPrint('Connectivity check failed: $e');
      return false; 
    }
  }

  static void showNonFoodImageDialog(BuildContext context, {String language = 'en'}) {
    // Show dialog implementation...
  }

  Future<String> getHealthCoachResponse({
    required List<ChatMessage> history,
    required String userContext,
    String language = 'en',
  }) async {
    try {
      final messages = [{"role": "system", "content": _getHealthCoachSystemPrompt(language, userContext)}];
      messages.addAll(history.map((m) => {"role": m.role == MessageRole.user ? "user" : "assistant", "content": m.content}));
      final data = await _callAi({"model": _model, "messages": messages});
      return _extractContentFromResponse(data);
    } on FirebaseFunctionsException catch (e) {
      debugPrint('groqChatCompletion error in getHealthCoachResponse: ${e.code}');
      throw Exception(_messageForCallableError(e, language));
    } catch (e) {
      debugPrint('Error in getHealthCoachResponse: $e');
      rethrow;
    }
  }

  String _getHealthCoachSystemPrompt(String language, String userContext) {
    return "You are a professional nutrition coach in ${_languageNameForModel(language)}. Context: $userContext. Provide empathetic, scientifically-grounded advice.";
  }
}
