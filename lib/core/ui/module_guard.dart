import 'package:flutter/material.dart';
import 'package:framework_as/core/auth/auth_service.dart';

class ModuleGuard extends StatelessWidget {
  final String module;
  final Widget child;

  const ModuleGuard({
    super.key,
    required this.module,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AuthResult?>(
      future: AuthService().getAuthData(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final auth = snap.data!;
        if (!auth.modules.contains(module)) {
          return Scaffold(
            appBar: AppBar(title: const Text("Acceso denegado")),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock, size: 64),
                  const SizedBox(height: 12),
                  Text(
                    "No tienes acceso al módulo \"$module\"",
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () =>
                        Navigator.of(context).pop(),
                    child: const Text("Volver"),
                  ),
                ],
              ),
            ),
          );
        }

        return child;
      },
    );
  }
}
