import 'package:flutter/material.dart';

class CustomerConfig {
  final String name;
  final List<String> enabledModules;

  final CustomerTheme theme;
  final String logo;

  final List<String> posFeatures;
  final List<String> agendaFeatures;

  final CustomerBranding branding;
  final CustomerAIConfig ai;

  final String language;
  final String currency;

  const CustomerConfig({
    required this.name,
    required this.enabledModules,
    required this.theme,
    required this.logo,
    required this.posFeatures,
    required this.agendaFeatures,
    required this.branding,
    required this.ai,
    required this.language,
    required this.currency,
  });

  factory CustomerConfig.fromJson(Map<String, dynamic> json) {
    return CustomerConfig(
      name: json["name"] ?? "Cliente",
      enabledModules: List<String>.from(json["enabledModules"] ?? const []),

      theme: CustomerTheme.fromJson(json["theme"] ?? const {}),
      logo: json["logo"] ?? "",

      posFeatures: List<String>.from(json["posFeatures"] ?? const []),
      agendaFeatures: List<String>.from(json["agendaFeatures"] ?? const []),

      branding: CustomerBranding.fromJson(json["branding"] ?? const {}),
      ai: CustomerAIConfig.fromJson(json["ai"] ?? const {}),

      language: json["language"] ?? "es",
      currency: json["currency"] ?? "MXN",
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "name": name,
      "enabledModules": enabledModules,
      "theme": theme.toJson(),
      "logo": logo,
      "posFeatures": posFeatures,
      "agendaFeatures": agendaFeatures,
      "branding": branding.toJson(),
      "ai": ai.toJson(),
      "language": language,
      "currency": currency,
    };
  }

  CustomerConfig copyWith({
    String? name,
    List<String>? enabledModules,
    CustomerTheme? theme,
    String? logo,
    List<String>? posFeatures,
    List<String>? agendaFeatures,
    CustomerBranding? branding,
    CustomerAIConfig? ai,
    String? language,
    String? currency,
  }) {
    return CustomerConfig(
      name: name ?? this.name,
      enabledModules: enabledModules ?? this.enabledModules,
      theme: theme ?? this.theme,
      logo: logo ?? this.logo,
      posFeatures: posFeatures ?? this.posFeatures,
      agendaFeatures: agendaFeatures ?? this.agendaFeatures,
      branding: branding ?? this.branding,
      ai: ai ?? this.ai,
      language: language ?? this.language,
      currency: currency ?? this.currency,
    );
  }
}

// -----------------------------------------------
// THEME
// -----------------------------------------------
class CustomerTheme {
  final Color primary;
  final Color secondary;
  final Color background;

  const CustomerTheme({
    required this.primary,
    required this.secondary,
    required this.background,
  });

  factory CustomerTheme.fromJson(Map<String, dynamic> json) {
    return CustomerTheme(
      primary: _hexToColor(json["primary"] ?? "#000000"),
      secondary: _hexToColor(json["secondary"] ?? "#000000"),
      background: _hexToColor(json["background"] ?? "#FFFFFF"),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "primary": _colorToHex(primary),
      "secondary": _colorToHex(secondary),
      "background": _colorToHex(background),
    };
  }

  CustomerTheme copyWith({
    Color? primary,
    Color? secondary,
    Color? background,
  }) {
    return CustomerTheme(
      primary: primary ?? this.primary,
      secondary: secondary ?? this.secondary,
      background: background ?? this.background,
    );
  }
}

// -----------------------------------------------
// BRANDING
// -----------------------------------------------
class CustomerBranding {
  final String designStyle;
  final bool roundedCorners;

  const CustomerBranding({
    required this.designStyle,
    required this.roundedCorners,
  });

  factory CustomerBranding.fromJson(Map<String, dynamic> json) {
    return CustomerBranding(
      designStyle: json["designStyle"] ?? "default",
      roundedCorners: json["roundedCorners"] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "designStyle": designStyle,
      "roundedCorners": roundedCorners,
    };
  }

  CustomerBranding copyWith({
    String? designStyle,
    bool? roundedCorners,
  }) {
    return CustomerBranding(
      designStyle: designStyle ?? this.designStyle,
      roundedCorners: roundedCorners ?? this.roundedCorners,
    );
  }
}

// -----------------------------------------------
// AI
// -----------------------------------------------
class CustomerAIConfig {
  final bool enabled;

  const CustomerAIConfig({
    required this.enabled,
  });

  factory CustomerAIConfig.fromJson(Map<String, dynamic> json) {
    return CustomerAIConfig(
      enabled: json["enabled"] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {"enabled": enabled};
  }

  CustomerAIConfig copyWith({bool? enabled}) {
    return CustomerAIConfig(enabled: enabled ?? this.enabled);
  }
}

// -----------------------------------------------
// UTIL
// -----------------------------------------------
Color _hexToColor(String hex) {
  hex = hex.toUpperCase().replaceAll("#", "");
  if (hex.length == 6) hex = "FF$hex";
  return Color(int.parse(hex, radix: 16));
}

String _colorToHex(Color color) {
  final value = color.value & 0x00FFFFFF;
  return "#${value.toRadixString(16).padLeft(6, "0").toUpperCase()}";
}
