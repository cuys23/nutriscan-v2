class ApiConfig {
  // API key and model moved server-side in the original project, but for
  // NutriScan 2 we use OpenRouter directly from the client.
  static const String _envApiKey = String.fromEnvironment('GROQ_API_KEY');

  // Hardcoded fallback key (OpenRouter)
  static const String _fallbackApiKey =
      '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';

  static String get groqApiKey {
    if (_envApiKey.isNotEmpty) return _envApiKey;
    return _fallbackApiKey;
  }

  /// Returns true if the API key is properly configured
  static bool get isApiKeyConfigured {
    final key = groqApiKey;
    return key.isNotEmpty &&
        key != 'YOUR_GROQ_API_KEY_HERE' &&
        key.length > 10;
  }

  // Model: Qwen 3.8 Flash via OpenRouter
  static const String groqModel = 'qwen/qwen3-8b';

  // Bump whenever VisionAiService's food-analysis prompt changes materially
  static const String scanPromptVersion = 'scan_v2';

  // OpenRouter API endpoint (compatible with OpenAI format)
  static String get groqBaseUrl =>
      'https://openrouter.ai/api/v1/chat/completions';
}
