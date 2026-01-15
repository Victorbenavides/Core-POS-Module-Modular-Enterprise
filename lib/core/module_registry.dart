import 'package:flutter/material.dart';
import 'package:framework_as/modules/pos_unicaja/pos_unicaja_root.dart';
import 'package:framework_as/modules/agenda/agenda_main.dart';
import 'package:framework_as/core/customers/customer_provider.dart';
import 'package:framework_as/core/ui/activation_entry.dart';
import 'package:framework_as/modules/pos_unicaja/data/database/app_database.dart';


class ModuleRegistry {
  static const String routePos = 'module:pos';
  static const String routeAgenda = 'module:agenda';

  static final Map<String, Widget Function()> _modules = {
    "pos": () => const PosUnicajaRoot(),
    "agenda": () => const AgendaMainScreen(),
  };

  static Widget load(String name) {
    final builder = _modules[name];
    if (builder == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Error")),
        body: Center(
          child: Text("El módulo '$name' no existe."),
        ),
      );
    }
    return builder();
  }

  static String routeNameFor(String name) {
    switch (name) {
      case 'pos':
        return routePos;
      case 'agenda':
        return routeAgenda;
      default:
        return 'module:$name';
    }
  }

  // ✅ GUARDIA DE LICENCIAS CENTRAL (SIN CUSTOMER POR UI)
   static Route<void> route(String name) {
    return MaterialPageRoute(
      settings: RouteSettings(name: routeNameFor(name)),
      builder: (context) {
        final provider = CustomerProvider.instance;
        final enabled = provider.config.enabledModules;

        // ❌ módulo no registrado
        if (!_modules.containsKey(name)) {
          return Scaffold(
            appBar: AppBar(title: const Text("Error")),
            body: Center(
              child: Text("El módulo '$name' no existe."),
            ),
          );
        }

        // ❌ módulo no habilitado (sin licencia)
        if (!enabled.contains(name)) {
          return const ActivationEntry();
        }

        // ✅ módulo permitido → inicializaciones por módulo
        final customerId = provider.customerId.trim().toLowerCase();

        // ✅ POS: DB aislada por customer, solo si POS está habilitado
        if (name == 'pos') {
          // IMPORTANTE: esto no crea “mil veces”
          // AppDatabase.initForCustomer ya está blindado por customer
          AppDatabase.initForCustomer(customerId);
        }

        return load(name);
      },
    );
  }


  static bool exists(String name) => _modules.containsKey(name);

  static List<String> get registeredModules => _modules.keys.toList();
}
