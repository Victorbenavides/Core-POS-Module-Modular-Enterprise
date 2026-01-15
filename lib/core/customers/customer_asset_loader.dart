// lib/core/customers/customer_asset_loader.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'customer_provider.dart';

class CustomerAssets {
  static Widget image(
    String relativePath, {
    BoxFit fit = BoxFit.contain,
    double width = 40,
    double height = 40,
  }) {
    final provider = CustomerProvider.instance;

    // Verificación crítica
    if (provider.basePath.isEmpty) {
      debugPrint("[CustomerAssets] ERROR: basePath aún no está definido.");

      return Container(
        width: width,
        height: height,
        color: Colors.orange.withOpacity(0.2),
        child: const Icon(Icons.image_not_supported, color: Colors.orange),
      );
    }

    final clean = relativePath.replaceAll("\\", "/");
    final fullPath = p.join(provider.basePath, clean);

    final file = File(fullPath);

    if (!file.existsSync()) {
      debugPrint("[CustomerAssets] Imagen no encontrada: $fullPath");

      return SizedBox(
        width: width,
        height: height,
        child: const Icon(Icons.error, color: Colors.red),
      );
    }

    return Image.file(
      file,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, __, ___) {
        debugPrint("[CustomerAssets] Error cargando imagen: $fullPath");

        return SizedBox(
          width: width,
          height: height,
          child: const Icon(Icons.error, color: Colors.red),
        );
      },
    );
  }

  /// ✅ Devuelve el archivo físico de un asset del cliente (si existe).
  /// Útil si quieres pasar el path a otra lib.
  static File? file(String relativePath) {
    final provider = CustomerProvider.instance;

    if (provider.basePath.isEmpty) {
      debugPrint("[CustomerAssets] ERROR: basePath aún no está definido.");
      return null;
    }

    final clean = relativePath.replaceAll("\\", "/");
    final fullPath = p.join(provider.basePath, clean);

    final f = File(fullPath);
    if (!f.existsSync()) {
      debugPrint("[CustomerAssets] Archivo no encontrado: $fullPath");
      return null;
    }

    return f;
  }

  /// ✅ Lee el archivo como bytes para cosas como PDF (pw.MemoryImage)
  static Future<Uint8List> bytes(String relativePath) async {
    final provider = CustomerProvider.instance;

    if (provider.basePath.isEmpty) {
      debugPrint("[CustomerAssets] ERROR: basePath aún no está definido.");
      throw Exception("Customer basePath no definido");
    }

    final clean = relativePath.replaceAll("\\", "/");
    final fullPath = p.join(provider.basePath, clean);

    final f = File(fullPath);
    final exists = await f.exists();
    if (!exists) {
      debugPrint("[CustomerAssets] Archivo no encontrado (bytes): $fullPath");
      throw Exception("Asset no encontrado: $relativePath");
    }

    try {
      return await f.readAsBytes();
    } catch (e) {
      debugPrint("[CustomerAssets] Error leyendo bytes: $fullPath => $e");
      rethrow;
    }
  }
}
