import 'package:framework_as/core/customers/customer_config.dart';

class SettingsService {
  static CustomerConfig? _activeCustomerConfig;

  CustomerConfig get activeCustomerConfig {
    if (_activeCustomerConfig == null) {
      throw Exception("CustomerConfig no ha sido cargado aún.");
    }
    return _activeCustomerConfig!;
  }

  void setActiveCustomerConfig(CustomerConfig config) {
    _activeCustomerConfig = config;
  }
}
