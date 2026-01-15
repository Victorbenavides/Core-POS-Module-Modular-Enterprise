import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:framework_as/core/customers/customer_provider.dart';
import 'package:framework_as/core/i18n/translation_service.dart';

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  final languages = const {
    "es": "Español",
    "en": "English",
  };

  late String selected;

  @override
  void initState() {
    super.initState();
    selected = CustomerProvider.instance.config.language;
  }

  @override
  Widget build(BuildContext context) {
    final t = Provider.of<TranslationService>(context);

    return Scaffold(
      appBar: AppBar(title: Text(t.t("settings.language"))),
      body: ListView(
        children: languages.entries.map((item) {
          return RadioListTile<String>(
            title: Text(item.value),
            value: item.key,
            groupValue: selected,
            onChanged: (value) async {
              if (value == null) return;

              setState(() => selected = value);

              CustomerProvider.instance.updateLanguage(value);
              TranslationService.instance.setLanguage(value);

              await CustomerProvider.instance.saveConfig();

              if (mounted) Navigator.pop(context);
            },
          );
        }).toList(),
      ),
    );
  }
}
