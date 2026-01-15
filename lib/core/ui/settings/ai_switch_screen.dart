import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:framework_as/core/customers/customer_provider.dart';
import 'package:framework_as/core/i18n/translation_service.dart';

class AISwitchScreen extends StatefulWidget {
  const AISwitchScreen({super.key});

  @override
  State<AISwitchScreen> createState() => _AISwitchScreenState();
}

class _AISwitchScreenState extends State<AISwitchScreen> {
  late bool enabled;

  @override
  void initState() {
    super.initState();
    enabled = CustomerProvider.instance.config.ai.enabled;
  }

  @override
  Widget build(BuildContext context) {
    final t = Provider.of<TranslationService>(context);

    return Scaffold(
      appBar: AppBar(title: Text(t.t("settings.ai"))),
      body: SwitchListTile(
        title: Text(t.t("settings.ai")),
        subtitle: Text(enabled ? t.t("settings.aiOn") : t.t("settings.aiOff")),
        value: enabled,
        onChanged: (v) async {
          setState(() => enabled = v);
          CustomerProvider.instance.updateAI(v);
          await CustomerProvider.instance.saveConfig();
        },
      ),
    );
  }
}
