import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:framework_as/core/customers/customer_provider.dart';
import 'package:framework_as/core/i18n/translation_service.dart';

class CurrencyScreen extends StatefulWidget {
  const CurrencyScreen({super.key});

  @override
  State<CurrencyScreen> createState() => _CurrencyScreenState();
}

class _CurrencyScreenState extends State<CurrencyScreen> {
  final currencies = const ["MXN", "USD", "EUR"];

  late String selected;

  @override
  void initState() {
    super.initState();
    selected = CustomerProvider.instance.config.currency;
  }

  @override
  Widget build(BuildContext context) {
    final t = Provider.of<TranslationService>(context);

    return Scaffold(
      appBar: AppBar(title: Text(t.t("settings.currency"))),
      body: ListView(
        children: currencies.map((c) {
          return RadioListTile<String>(
            title: Text(c),
            value: c,
            groupValue: selected,
            onChanged: (value) async {
              if (value == null) return;

              setState(() => selected = value);

              CustomerProvider.instance.updateCurrency(value);
              await CustomerProvider.instance.saveConfig();

              if (mounted) Navigator.pop(context);
            },
          );
        }).toList(),
      ),
    );
  }
}
