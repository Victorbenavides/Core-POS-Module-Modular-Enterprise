// lib/core/ui/activation_entry.dart
import 'package:flutter/material.dart';
import 'license_activation_screen.dart';

class ActivationEntry extends StatelessWidget {
  const ActivationEntry({super.key});

  @override
  Widget build(BuildContext context) {
    return Navigator(
      onGenerateRoute: (_) => MaterialPageRoute(
        builder: (_) => const LicenseActivationScreen(),
      ),
    );
  }
}
