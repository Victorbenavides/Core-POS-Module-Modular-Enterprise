import 'package:flutter/material.dart';
import 'app_strings.dart';

class TranslationService extends ChangeNotifier {
  static final TranslationService instance = TranslationService._internal();
  TranslationService._internal();

  String _language = "es";
  String get language => _language;

  String get fontFamily => _language == "en" ? "Roboto" : "Montserrat";

  void setLanguage(String lang) {
    _language = lang;
    notifyListeners();
  }

  String t(String key) {
    return AppStrings.text(key, _language);
  }
}
