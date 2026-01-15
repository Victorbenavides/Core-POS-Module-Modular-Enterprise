// lib/core/ui/home_menu.dart
import 'package:flutter/material.dart';

import 'package:framework_as/core/module_registry.dart';
import 'package:framework_as/core/ui/settings_button.dart';
import 'package:framework_as/core/ui/license_activation_screen.dart';
import 'package:framework_as/core/auth/auth_service.dart';
import 'package:framework_as/core/customers/customer_provider.dart';

class HomeMenu extends StatefulWidget {
  const HomeMenu({super.key});

  @override
  State<HomeMenu> createState() => _HomeMenuState();
}

class _HomeMenuState extends State<HomeMenu> {
  AuthResult? _auth;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAuth();
  }

  Future<void> _loadAuth() async {
    final auth = await AuthService().getAuthData();
    if (!mounted) return;

    setState(() {
      _auth = auth;
      _loading = false;
    });
  }

  Future<void> _openLicenseActivation() async {
    if (_auth == null) return;

    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const LicenseActivationScreen(),
      ),
    );

    if (changed != true) return;

    // 🔥 releemos estado local (ya actualizado por bootstrap)
    final updated = await AuthService().getAuthData();
    if (updated == null || !mounted) return;

    // 🔥 sincronizamos CustomerProvider
    final currentCfg = CustomerProvider.instance.config;
    final merged = currentCfg.copyWith(
      enabledModules: updated.modules,
    );

    CustomerProvider.instance.setConfig(
      merged,
      CustomerProvider.instance.customerId,
    );

    setState(() => _auth = updated);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final modules = _auth?.modules ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Selecciona un módulo"),
        actions: const [
          SettingsButton(),
          SizedBox(width: 8),
        ],
      ),
      body: ListView(
        children: [
          // ================= LICENCIAS =================
          ListTile(
            leading: const Icon(Icons.vpn_key),
            title: const Text("Activar licencia / agregar módulo"),
            subtitle:
                const Text("Ingresa tu key para habilitar un módulo"),
            trailing: const Icon(Icons.arrow_forward),
            onTap: _openLicenseActivation,
          ),

          const Divider(height: 1),

          // ================= ESTADO =================
          if (modules.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                "No tienes módulos activos todavía.",
                style: TextStyle(fontSize: 15),
              ),
            ),

          // ================= MÓDULOS =================
          ...modules.map(
            (m) => ListTile(
              leading: const Icon(Icons.apps),
              title: Text(m.toUpperCase()),
              trailing: const Icon(Icons.arrow_forward),
              onTap: () {
                Navigator.of(context).push(
                  ModuleRegistry.route(m),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
