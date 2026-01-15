class LicenseRules {
  /// días después de expirar permitidos
  static const int graceDays = 7;

  /// módulos que nunca se bloquean del todo
  static const List<String> alwaysAllowed = [
    'pos',
  ];
}
