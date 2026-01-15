import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/pos_session.dart';
import 'controllers/pos_inventory_controller.dart';
import 'controllers/pos_cashiers_controller.dart';
import 'pos_main.dart';

import 'package:framework_as/core/customers/customer_provider.dart';
import 'package:framework_as/core/ui/activation_entry.dart';
import 'package:framework_as/modules/pos_unicaja/data/database/app_database.dart';


class PosUnicajaRoot extends StatefulWidget {
  const PosUnicajaRoot({super.key});

  @override
  State<PosUnicajaRoot> createState() => _PosUnicajaRootState();
}

class _PosUnicajaRootState extends State<PosUnicajaRoot> {
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final provider = CustomerProvider.instance;
      final config = provider.config;

      // ❌ Cliente NO tiene licencia del POS
      if (!config.enabledModules.contains('pos')) {
        setState(() {
          _loading = false;
        });
        return;
      }

      // ✅ Cliente SÍ tiene licencia → inicializamos DB aislada
      await AppDatabase.initForCustomer(provider.customerId);

      setState(() {
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final customerId = context.watch<CustomerProvider>().customerId;
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Text(
            'Error inicializando POS:\n$_error',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final enabled = CustomerProvider.instance.config.enabledModules;

    // ❌ Sin licencia → pantalla de activación
    if (!enabled.contains('pos')) {
      return const ActivationEntry();
    }

    // ✅ Todo correcto → arrancamos POS
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PosSessionController(customerCode: customerId)),
        ChangeNotifierProvider(create: (_) => PosInventoryController()),
        ChangeNotifierProvider(create: (_) => PosCashiersController(customerCode: customerId)),
      ],
      child: const PosMainScreen(),
    );
  }
}
