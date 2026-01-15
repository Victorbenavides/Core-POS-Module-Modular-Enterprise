// lib/core/ui/settings_button.dart
import 'package:flutter/material.dart';
import 'package:framework_as/core/ui/settings_center.dart';

class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.settings, size: 20),
      tooltip: "Settings",
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SettingsCenter()),
        );
      },
    );
  }
}
