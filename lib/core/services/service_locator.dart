import '../auth/auth_service.dart';
import '../settings/settings_service.dart';
import '../database/database_service.dart';

class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._internal();
  factory ServiceLocator() => _instance;
  ServiceLocator._internal();

  late AuthService auth;
  late SettingsService settings;
  late DatabaseService db;

  Future<void> init() async {
    auth = AuthService();
    settings = SettingsService();
    db = DatabaseService();
    await db.init();
  }
}

final locator = ServiceLocator();
