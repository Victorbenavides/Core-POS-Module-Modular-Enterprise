// lib/core/customers/customer_loader.dart
import 'dart:convert';
import 'dart:io';

import 'customer_config.dart';
import 'package:framework_as/core/system/app_paths.dart';
import 'package:flutter/material.dart';

class CustomerLoader {
  /// Carga el config de un cliente desde el path oficial
  static Future<CustomerConfig> load(String customerId) async {
    final dir = await AppPaths.instance.customer(customerId);
    final file = File('${dir.path}/config.json');

    if (await file.exists()) {
      final jsonString = await file.readAsString();
      final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
      return CustomerConfig.fromJson(jsonData);
    }

    // 🔥 no existe config aún → default controlado
    return _defaultConfigFor(customerId);
  }

  /// Config por defecto (cliente válido, pero sin config.json todavía)
  static CustomerConfig _defaultConfigFor(String customerId) {
    return CustomerConfig(
      name: customerId,
      enabledModules: const [],

      theme: const CustomerTheme(
        primary: Color(0xFF2E66C7),
        secondary: Color(0xFFA4D5D0),
        background: Color(0xFFFFFFFF),
      ),

      logo: "",
      posFeatures: const [],
      agendaFeatures: const [],

      branding: const CustomerBranding(
        designStyle: "default",
        roundedCorners: true,
      ),

      ai: const CustomerAIConfig(enabled: false),

      language: "es",
      currency: "MXN",
    );
  }
}
