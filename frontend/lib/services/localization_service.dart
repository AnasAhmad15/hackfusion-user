import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'translations.dart';

class LocalizationService {
  static const String _baseUrl = 'http://192.168.137.1:8000'; // Updated to match user's current backend IP
  static String _currentLanguage = 'English';
  static final List<VoidCallback> _listeners = [];
  static const String _langKey = 'selected_language';
  static const String _firstTimeKey = 'is_first_time';

  static void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  static void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  static void _notifyListeners() {
    for (var listener in _listeners) {
      listener();
    }
  }

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _currentLanguage = prefs.getString(_langKey) ?? 'English';
  }

  static String get currentLanguage => _currentLanguage;

  static Future<void> setLanguage(String language) async {
    if (_currentLanguage == language) return;
    _currentLanguage = language;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_langKey, language);
    _notifyListeners();
  }

  static Future<bool> isFirstTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_firstTimeKey) ?? true;
  }

  static Future<void> markFirstTimeDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_firstTimeKey, false);
    debugPrint('LocalizationService: marked first time as DONE');
  }

  static const String _tourKey = 'tour_seen';

  static Future<bool> isTourSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_tourKey) ?? false;
  }

  static Future<void> markTourSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_tourKey, true);
  }

  static String t(String key) {
    if (AppTranslations.translations.containsKey(_currentLanguage)) {
      return AppTranslations.translations[_currentLanguage]![key] ?? key;
    }
    return key;
  }

  static final List<String> supportedLanguages = [
    'English',
    'Hindi',
    'Spanish',
    'French',
    'German',
    'Arabic',
    'Bengali',
    'Marathi',
    'Telugu',
    'Tamil'
  ];

  static Future<Map<String, String>> translateBatch(List<String> texts) async {
    if (_currentLanguage == 'English' || texts.isEmpty) {
      return Map.fromIterable(texts, key: (e) => e, value: (e) => e);
    }
    
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/translate_batch?target_lang=$_currentLanguage'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(texts),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final List<dynamic> translatedList = data['translated_texts'] ?? [];
        
        Map<String, String> result = {};
        for (int i = 0; i < texts.length; i++) {
          result[texts[i]] = i < translatedList.length ? translatedList[i].toString() : texts[i];
        }
        return result;
      }
    } catch (e) {
      print('Batch translation error: $e');
    }
    return Map.fromIterable(texts, key: (e) => e, value: (e) => e);
  }

  static Future<String> translate(String text) async {
    if (_currentLanguage == 'English') return text;
    
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/translate?text=${Uri.encodeComponent(text)}&target_lang=$_currentLanguage'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return data['translated_text'] ?? text;
      }
    } catch (e) {
      print('Translation error: $e');
    }
    return text;
  }
}
