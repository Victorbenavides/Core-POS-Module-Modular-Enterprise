// lib/core/ui/settings/manage_module_screen.dart
import 'package:flutter/material.dart';
import 'package:framework_as/core/ui/license_activation_screen.dart';
import 'package:framework_as/core/customers/customer_provider.dart';

class DefaultModuleScreen extends StatelessWidget {
  const DefaultModuleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = CustomerProvider.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Contratar o actualizar módulo"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Administra tus módulos",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            Text(
              "Módulos activos: ${provider.config.enabledModules.join(", ").toUpperCase()}",
            ),

            const SizedBox(height: 24),

            ListTile(
              leading: const Icon(Icons.vpn_key),
              title: const Text("Ingresar o renovar licencia"),
              subtitle: const Text("Activa nuevos módulos o renueva existentes"),
              trailing: const Icon(Icons.arrow_forward),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LicenseActivationScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
