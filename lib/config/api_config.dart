class ApiConfig {
  // The OpenRouter API key and base URL used to live here and shipped inside
  // the client binary. They moved server-side into the `groqChatCompletion`
  // Cloud Function (functions/src/index.ts) so the real key is never in the
  // app and every AI call is authenticated and rate-limited per user.

  /// Model id used for every AI call — vision (food validation, food
  /// analysis) and text (meal plan, insights, health coach) alike.
  ///
  /// Two things this model has to be, both verified against openrouter.ai:
  ///  - vision-capable, because the scan path sends `image_url` content parts
  ///    (`qwen/qwen3-8b` is text-only there and rejects every scan);
  ///  - answering with reasoning switched off, which the Cloud Function forces
  ///    for every request — otherwise a thinking model spends the whole
  ///    max_tokens budget reasoning and returns empty content.
  static const String groqModel = 'qwen/qwen3.7-flash';

  // Bump whenever the food-analysis prompt changes materially.
  static const String scanPromptVersion = 'scan_v2';
}
