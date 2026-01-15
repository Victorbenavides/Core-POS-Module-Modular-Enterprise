// lib/modules/pos_unicaja/controllers/pos_auth.dart
import '../models/cashier.dart';

/// Controlador de autenticación DEMO.
/// Ya no se usa directamente porque ahora usamos PosCashiersController
/// pero lo dejamos para que compile correctamente.
class POSAuthController {
  // Simulación de cajeros registrados
  final List<Cashier> _cashiers = const [
    Cashier(
      id: "admin",
      name: "Administrador",
      pin: "1234",
      isAdmin: true,
      canManageInventory: true,
      canViewReports: true,
      canCancelSales: true,
    ),
    Cashier(
      id: "2",
      name: "Empleado 2",
      pin: "2222",
      isAdmin: false,
      canManageInventory: false,
      canViewReports: false,
      canCancelSales: false,
    ),
  ];

  /// Login por PIN
  Cashier? loginWithPin(String pin) {
    try {
      return _cashiers.firstWhere((c) => c.pin == pin);
    } catch (_) {
      return null;
    }
  }
}
