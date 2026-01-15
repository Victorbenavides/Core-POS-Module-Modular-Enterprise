// lib/core/i18n/app_strings.dart
class AppStrings {
  static const Map<String, Map<String, String>> _data = {
    "es": {
      // Login
      "login.title": "Iniciar sesión",
      "login.username": "Usuario",
      "login.password": "Contraseña",
      "login.button": "Entrar",
      "login.error": "Credenciales incorrectas",

      // Settings
      "settings.title": "Ajustes del sistema",
      "settings.clientActive": "Cliente activo",
      "settings.defaultModule": "Módulo predeterminado",
      "settings.themeTitle": "Tema y diseño",
      "settings.themeSubtitle": "Colores, estilo visual",
      "settings.language": "Idioma",
      "settings.currency": "Moneda",
      "settings.ai": "IA",
      "settings.aiOn": "Activada",
      "settings.aiOff": "Desactivada",
      "settings.logout": "Cerrar sesión",

      // POS
      "pos.title": "POS",
      "pos.total": "Total de la venta",

      // Agenda
      "agenda.title": "Agenda",
      "agenda.clients": "Clientes",
      "agenda.appointments": "Citas",
    },

    "en": {
      // Login
      "login.title": "Sign in",
      "login.username": "Username",
      "login.password": "Password",
      "login.button": "Sign in",
      "login.error": "Invalid credentials",

      // Settings
      "settings.title": "System settings",
      "settings.clientActive": "Active customer",
      "settings.defaultModule": "Default module",
      "settings.themeTitle": "Theme & design",
      "settings.themeSubtitle": "Colors, visual style",
      "settings.language": "Language",
      "settings.currency": "Currency",
      "settings.ai": "AI",
      "settings.aiOn": "Enabled",
      "settings.aiOff": "Disabled",
      "settings.logout": "Log out",

      // POS
      "pos.title": "POS",
      "pos.total": "Sale total",

      // Agenda
      "agenda.title": "Schedule",
      "agenda.clients": "Clients",
      "agenda.appointments": "Appointments",
    },
  };

  static String text(String key, String language) {
    final lang = _data[language] ?? _data["es"]!;
    return lang[key] ?? _data["es"]![key] ?? key;
  }
}
