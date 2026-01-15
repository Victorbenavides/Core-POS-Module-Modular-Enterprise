import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import 'package:framework_as/core/customers/customer_provider.dart';
import 'package:framework_as/core/i18n/translation_service.dart';

class ThemeEditorScreen extends StatefulWidget {
  const ThemeEditorScreen({super.key});

  @override
  State<ThemeEditorScreen> createState() => _ThemeEditorScreenState();
}

class _ThemeEditorScreenState extends State<ThemeEditorScreen> {
  late Color primary;
  late Color secondary;
  late Color background;

  @override
  void initState() {
    super.initState();
    final theme = CustomerProvider.instance.config.theme;
    primary = theme.primary;
    secondary = theme.secondary;
    background = theme.background;
  }

  @override
  Widget build(BuildContext context) {
    final t = Provider.of<TranslationService>(context);

    return Scaffold(
      appBar: AppBar(title: Text(t.t("settings.themeTitle"))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _colorRow("Primario", primary, (c) => setState(() => primary = c)),
            const SizedBox(height: 16),
            _colorRow("Secundario", secondary, (c) => setState(() => secondary = c)),
            const SizedBox(height: 16),
            _colorRow("Fondo", background, (c) => setState(() => background = c)),
            const Spacer(),
            ElevatedButton(
              onPressed: () async {
                final provider = CustomerProvider.instance;
                provider.updateTheme(
                  provider.config.theme.copyWith(
                    primary: primary,
                    secondary: secondary,
                    background: background,
                  ),
                );

                await provider.saveConfig();

                if (!mounted) return;
                Navigator.pop(context);
              },
              child: Text("Guardar cambios"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _colorRow(String label, Color color, Function(Color) onChanged) {
    return Row(
      children: [
        Text(label),
        const SizedBox(width: 16),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.black26),
          ),
        ),
        const SizedBox(width: 16),
        ElevatedButton(
          onPressed: () {
            showDialog(
  context: context,
  builder: (dialogContext) => AlertDialog(
    title: Text("Seleccionar color ($label)"),
    content: BlockPicker(
      pickerColor: color,
      onColorChanged: (c) => onChanged(c),
    ),
    actions: [
      TextButton(
        child: const Text("Cerrar"),
        onPressed: () => Navigator.of(dialogContext).pop(),
      ),
    ],
  ),
);
          },
          child: const Text("Cambiar"),
        ),
      ],
    );
  }
}
