import 'package:flutter/material.dart';
import 'package:framework_as/core/auth/auth_service.dart';

class LicenseActivationScreen extends StatefulWidget {
  const LicenseActivationScreen({super.key});

  @override
  State<LicenseActivationScreen> createState() =>
      _LicenseActivationScreenState();
}

class _LicenseActivationScreenState extends State<LicenseActivationScreen> {
  final TextEditingController _keyCtrl = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _keyCtrl.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    final key = _keyCtrl.text.trim();

    if (key.isEmpty) {
      setState(() => _error = "Ingresa una licencia válida.");
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final ok = await AuthService().activateLicenseKey(
        key: key, // ✅ SOLO key
      );

      if (!mounted) return;

      if (!ok) {
        setState(() {
          _loading = false;
          _error = "Licencia inválida o ya utilizada.";
        });
        return;
      }

      // ✅ avisamos al HomeMenu que hubo cambios
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = "No se pudo activar la licencia.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Activar licencia"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Ingresa la key para habilitar un módulo.",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _keyCtrl,
                enabled: !_loading,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _loading ? null : _activate(),
                decoration: const InputDecoration(
                  labelText: "License key",
                  hintText: "POS-AB12-CD34-EF56",
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 10),

              if (_error != null)
                Text(
                  _error!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),

              const Spacer(),

              Row(
                children: [
                  TextButton(
                    onPressed:
                        _loading ? null : () => Navigator.of(context).pop(false),
                    child: const Text("Cancelar"),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _loading ? null : _activate,
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: const Text("Activar"),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              const Text(
                "La licencia es proporcionada por el administrador del sistema.",
                style: TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
