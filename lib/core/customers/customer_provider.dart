// lib/core/customers/customer_provider.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'customer_config.dart';
import 'package:framework_as/core/system/app_paths.dart';


class CustomerProvider extends ChangeNotifier {
  static final CustomerProvider instance = CustomerProvider._internal();
  CustomerProvider._internal();

  CustomerConfig? _config;
  String _customerId = "";

  String? _basePath; // ⬅️ ahora nullable
  bool _initialized = false;

  // ============================================================
  // GETTERS SEGUROS
  // ============================================================

  bool get initialized => _initialized;

  String get customerId => _customerId;

  String get basePath => _basePath ?? "";

  CustomerConfig get config {
    // ⛔️ NO warnings, NO fallback ruidoso
    if (_config == null) {
      return _emptyConfig;
    }
    return _config!;
  }

  static final CustomerConfig _emptyConfig = CustomerConfig(
    name: "Loading",
    enabledModules: const [],
    theme: CustomerTheme(
      primary: Colors.blueGrey,
      secondary: Colors.grey,
      background: Colors.white,
    ),
    logo: "",
    posFeatures: const [],
    agendaFeatures: const [],
    branding: CustomerBranding(
      designStyle: "default",
      roundedCorners: false,
    ),
    ai: CustomerAIConfig(enabled: false),
    language: "es",
    currency: "MXN",
  );

  // ============================================================
  // CONFIGURACIÓN PRINCIPAL (login / restore)
  // ============================================================

  Future<void> setConfig(CustomerConfig cfg, String customerId) async {
    _customerId = customerId;
    _config = cfg;

    _basePath = await _resolveCustomerPath(customerId);

    _initialized = true;
    notifyListeners();
  }

  // ============================================================
  // PATH RESOLUTION (SAFE)
  // ============================================================

  Future<String> _resolveCustomerPath(String id) async {
  final dir = await AppPaths.instance.customer(id);
  return dir.path;
}


  // ============================================================
  // UPDATE HELPERS
  // ============================================================

  void updateTheme(CustomerTheme theme) {
    if (_config == null) return;
    _config = _config!.copyWith(theme: theme);
    notifyListeners();
  }

  void updateLanguage(String lang) {
    if (_config == null) return;
    _config = _config!.copyWith(language: lang);
    notifyListeners();
  }

  void updateCurrency(String currency) {
    if (_config == null) return;
    _config = _config!.copyWith(currency: currency);
    notifyListeners();
  }

  void updateAI(bool enabled) {
    if (_config == null) return;
    _config = _config!.copyWith(
      ai: _config!.ai.copyWith(enabled: enabled),
    );
    notifyListeners();
  }

  void setEnabledModules(List<String> modules) {
    if (_config == null) return;
    _config = _config!.copyWith(enabledModules: modules);
    notifyListeners();
  }

  bool hasModule(String module) =>
      _config?.enabledModules.contains(module) ?? false;

  // ============================================================
  // SAVE CONFIG
  // ============================================================

  Future<void> saveConfig() async {
    if (_basePath == null || _config == null) return;

    final file = File(p.join(_basePath!, "config.json"));
    await file.writeAsString(
      const JsonEncoder.withIndent("  ").convert(_config!.toJson()),
    );
  }

  // ============================================================
  // CLEAR (logout)
  // ============================================================

  void clear() {
    _initialized = false;
    _config = null;
    _customerId = "";
    _basePath = null;
    notifyListeners();
  }
}
