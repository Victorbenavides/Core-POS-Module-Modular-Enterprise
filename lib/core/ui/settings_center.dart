// lib/core/ui/settings_center.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:framework_as/core/auth/auth_service.dart';
import 'package:framework_as/core/customers/customer_provider.dart';
import 'package:framework_as/core/i18n/translation_service.dart';

import 'package:framework_as/core/ui/settings/theme_editor.dart';
import 'package:framework_as/core/ui/settings/language_screen.dart';
import 'package:framework_as/core/ui/settings/currency_screen.dart';
import 'package:framework_as/core/ui/settings/manage_modules_screen.dart';
import 'package:framework_as/core/ui/settings/ai_switch_screen.dart';
import 'package:framework_as/core/ui/settings/logo_screen.dart';
import 'package:framework_as/modules/pos_unicaja/data/database/app_database.dart';

import 'package:framework_as/main.dart';

class SettingsCenter extends StatelessWidget {
  const SettingsCenter({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<CustomerProvider>(context);
    final t = Provider.of<TranslationService>(context);

    final customer = provider.config;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.t("settings.title")),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 10),

          // CLIENTE ACTIVO
          ListTile(
            title: Text(
              customer.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(t.t("settings.clientActive")),
            leading: const Icon(Icons.business),
          ),

          const Divider(),

          // MODULO PREDETERMINADO
          // CONTRATAR / ACTUALIZAR MÓDULOS
ListTile(
  title: const Text("Contratar o actualizar módulo"),
  subtitle: const Text("Gestiona tus licencias"),
  leading: const Icon(Icons.vpn_key),
  onTap: () async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const DefaultModuleScreen(),
      ),
    );
  },
),


          const Divider(),

          // TEMA Y DISEÑO
          ListTile(
            title: Text(t.t("settings.themeTitle")),
            subtitle: Text(t.t("settings.themeSubtitle")),
            leading: const Icon(Icons.palette),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ThemeEditorScreen()),
              );
            },
          ),

          const Divider(),

// LOGO_CLIENTE
ListTile(
  title: const Text("Logo del cliente"),
  subtitle: const Text("Subir o cambiar el logo"),
  leading: const Icon(Icons.image),
  onTap: () async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LogoScreen()),
    );
  },
),
const Divider(),


          // IDIOMA
          ListTile(
            title: Text(t.t("settings.language")),
            subtitle: Text(customer.language),
            leading: const Icon(Icons.language),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LanguageScreen()),
              );
            },
          ),

          const Divider(),

          // MONEDA
          ListTile(
            title: Text(t.t("settings.currency")),
            subtitle: Text(customer.currency),
            leading: const Icon(Icons.attach_money),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CurrencyScreen()),
              );
            },
          ),

          const Divider(),

          // IA
          ListTile(
            title: Text(t.t("settings.ai")),
            subtitle: Text(
                customer.ai.enabled ? t.t("settings.aiOn") : t.t("settings.aiOff")),
            leading: const Icon(Icons.smart_toy),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AISwitchScreen()),
              );
            },
          ),

          const Divider(),

          // CERRAR SESIÓN
          ListTile(
  title: Text(
    t.t("settings.logout"),
    style: const TextStyle(color: Colors.red),
  ),
  leading: const Icon(Icons.logout, color: Colors.red),
  onTap: () async {
  await AuthService().logout();

  // ✅ cierra DB del pos (evita que quede montada para otro customer)
  try { await AppDatabase.close(); } catch (_) {}

  provider.clear();

  if (!context.mounted) return;

  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const FrameworkRoot()),
    (route) => false,
  );
},

),

        ],
      ),
    );
  }
}
