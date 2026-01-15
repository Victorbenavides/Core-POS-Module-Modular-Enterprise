import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:framework_as/core/branding/customer_branding_service.dart';
import 'package:framework_as/core/branding/customer_logo.dart';

class LogoScreen extends StatefulWidget {
  const LogoScreen({super.key});

  @override
  State<LogoScreen> createState() => _LogoScreenState();
}

class _LogoScreenState extends State<LogoScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _pickLogo() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: false,
      );

      if (!mounted) return;

      if (result == null || result.files.isEmpty || result.files.first.path == null) {
        setState(() => _loading = false);
        return;
      }

      final file = File(result.files.first.path!);

      await CustomerBrandingService.instance.setLogoFromPickedFile(file);

      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = "No se pudo cargar el logo: $e";
      });
    }
  }

  Future<void> _removeLogo() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await CustomerBrandingService.instance.clearLogo();
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = "No se pudo borrar el logo: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Logo del cliente")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Sube el logo del cliente. Se guardará por instalación y se verá en toda la app.",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 14),

              Center(
                child: Container(
                  height: 160,
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: const Center(
                    child: CustomerLogo(
                      height: 130,
                      fit: BoxFit.contain,
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              if (_error != null)
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
                ),

              const Spacer(),

              Row(
                children: [
                  TextButton.icon(
                    onPressed: _loading ? null : _removeLogo,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text("Quitar"),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _loading ? null : _pickLogo,
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_file),
                    label: const Text("Subir logo"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
