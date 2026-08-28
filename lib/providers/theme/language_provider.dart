import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  String _currentLanguage = 'en'; // Default to English
  String get currentLanguage => _currentLanguage;
  SharedPreferences? _prefs;
  Function(String)? _onLanguageChanged;

  LanguageProvider() {
    _loadLanguagePreference();
  }

  void setLanguageChangeCallback(Function(String) callback) {
    _onLanguageChanged = callback;
  }

  Future<void> _loadLanguagePreference() async {
    _prefs = await SharedPreferences.getInstance();
    _currentLanguage = _prefs?.getString('selected_language') ?? 'en';
    notifyListeners();
  }

  Future<void> setLanguage(String languageCode) async {
    // Immediately update UI
    _currentLanguage = languageCode;
    notifyListeners();

    // Save to storage in background
    try {
      if (_prefs != null) {
        await _prefs!.setString('selected_language', languageCode);
      } else {
        _prefs = await SharedPreferences.getInstance();
        await _prefs!.setString('selected_language', languageCode);
      }

      // Notify callback (e.g., for FCM topic subscription)
      _onLanguageChanged?.call(languageCode);
    } catch (e) {
      _currentLanguage = 'en';
      notifyListeners();
    }
  }

  // Get localized text based on current language
  String getLocalizedText(Map<String, String> translations) {
    return translations[_currentLanguage] ?? translations['en'] ?? '';
  }

  // Get current language display name
  String getCurrentLanguageName() {
    switch (_currentLanguage) {
      case 'en':
        return 'English';
      case 'bn':
        return 'বাংলা';
      case 'hi':
        return 'हिंदी';
      case 'es':
        return 'Español';
      case 'fr':
        return 'Français';
      case 'de':
        return 'Deutsch';
      case 'zh':
        return '中文';
      case 'tr':
        return 'Türkçe';
      case 'ko':
        return '한국어';
      case 'id':
        return 'Bahasa Indonesia';
      case 'ja':
        return '日本語';
      case 'ru':
        return 'Русский';
      case 'ur':
        return 'اردو';
      case 'pt':
        return 'Português';
      case 'pt-BR':
        return 'Português (Brasil)';
      case 'ar':
        return 'العربية';
      default:
        return 'English';
    }
  }

  // Get supported languages
  List<Map<String, String>> getSupportedLanguages() {
    return [
      {'code': 'en', 'name': 'English', 'nativeName': 'English'},
      {'code': 'bn', 'name': 'Bangla', 'nativeName': 'বাংলা'},
      {'code': 'hi', 'name': 'Hindi', 'nativeName': 'हिंदी'},
      {'code': 'es', 'name': 'Spanish', 'nativeName': 'Español'},
      {'code': 'fr', 'name': 'French', 'nativeName': 'Français'},
      {'code': 'de', 'name': 'German', 'nativeName': 'Deutsch'},
      {'code': 'zh', 'name': 'Chinese', 'nativeName': '中文'},
      {'code': 'tr', 'name': 'Turkish', 'nativeName': 'Türkçe'},
      {'code': 'ko', 'name': 'Korean', 'nativeName': '한국어'},
      {'code': 'id', 'name': 'Indonesian', 'nativeName': 'Bahasa Indonesia'},
      {'code': 'ja', 'name': 'Japanese', 'nativeName': '日本語'},
      {'code': 'ru', 'name': 'Russian', 'nativeName': 'Русский'},
      {'code': 'ur', 'name': 'Urdu', 'nativeName': 'اردو'},
      {'code': 'pt', 'name': 'Portuguese', 'nativeName': 'Português'},
      {
        'code': 'pt-BR',
        'name': 'Brazilian Portuguese',
        'nativeName': 'Português (Brasil)',
      },
      {'code': 'ar', 'name': 'Arabic', 'nativeName': 'العربية'},
    ];
  }
  // Get specific font family for each language
  String _getFontFamilyForLanguage(String language) {
    switch (language) {
      case 'en':
        return 'Poppins';
      case 'bn':
        return 'Hind Siliguri';
      case 'hi':
        return 'Amiko';
      case 'es':
        return 'Poppins';
      case 'fr':
        return 'Poppins';
      case 'de':
        return 'Poppins';
      case 'zh':
        return 'Noto Sans SC';
      case 'tr':
        return 'Poppins';
      case 'ko':
        return 'Noto Sans KR';
      case 'id':
        return 'Poppins';
      case 'ja':
        return 'Noto Sans JP';
      case 'ru':
        return 'Poppins';
      case 'ur':
        return 'Noto Nastaliq Urdu';
      case 'pt':
        return 'Poppins';
      case 'pt-BR':
        return 'Poppins';
      case 'ar':
        return 'Cairo';
      default:
        return 'Poppins';
    }
  }

  // Get current font family name
  String get currentFontFamily {
    return _getFontFamilyForLanguage(_currentLanguage);
  }
}
