class ApiConfig {
  // The OpenRouter API key and base URL used to live here and shipped inside
  // the client binary. They moved server-side into the `groqChatCompletion`
  // Cloud Function (functions/src/index.ts) so the real key is never in the
  // app and every AI call is authenticated and rate-limited per user.

  /// Model id used for every AI call — vision (food validation, food
  /// analysis) and text (meal plan, insights, health coach) alike.
  ///
  /// Must be a vision-capable model: the scan path sends `image_url` content
  /// parts, which a text-only model rejects. `qwen/qwen3-8b` is text-only on
  /// OpenRouter and would break every scan.
  static const String groqModel = 'qwen/qwen3.8-flash';

  // Bump whenever the food-analysis prompt changes materially.
  static const String scanPromptVersion = 'scan_v2';
}
