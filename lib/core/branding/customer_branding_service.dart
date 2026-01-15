import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'package:framework_as/local/db/framework_local_database.dart';
import 'package:framework_as/local/customer_local_paths.dart';

class CustomerBrandingService {
  CustomerBrandingService._();
  static final CustomerBrandingService instance = CustomerBrandingService._();

  static const String _metaLogoKey = 'client_logo_path';

  final ValueNotifier<File?> logoFile = ValueNotifier<File?>(null);

  String? _customerCode;

  /// Llamar cada vez que entras/cambias de customer
  Future<void> initForCustomer(String customerCode) async {
    _customerCode = customerCode;

    try {
      await FrameworkLocalDatabase.instance.openForCustomer(customerCode);
      final saved = await FrameworkLocalDatabase.instance.getMeta(_metaLogoKey);

      if (saved == null || saved.trim().isEmpty) {
        logoFile.value = null;
        return;
      }

      final f = File(saved);
      if (await f.exists()) {
        logoFile.value = f;
      } else {
        // si ya no existe, limpiamos meta
        await FrameworkLocalDatabase.instance.setMeta(_metaLogoKey, '');
        logoFile.value = null;
      }
    } catch (_) {
      logoFile.value = null;
    }
  }

  /// Copia el logo a la carpeta del cliente y guarda el path en meta
  Future<void> setLogoFromPickedFile(File picked) async {
    final customer = _customerCode;
    if (customer == null || customer.isEmpty) {
      throw StateError(
        'CustomerBrandingService no inicializado. '
        'Llama initForCustomer() antes.',
      );
    }

    // Guardar portable dentro del customer
    final root = await CustomerLocalPaths.instance.customerRoot(customer);
    final brandingDir = Directory(p.join(root.path, 'branding'));
    if (!await brandingDir.exists()) {
      await brandingDir.create(recursive: true);
    }

    // Mantener extensión original
    final ext = p.extension(picked.path).toLowerCase();
    final safeExt = ext.isEmpty ? '.png' : ext;

    final dest = File(p.join(brandingDir.path, 'logo$safeExt'));

    // Copiar (overwrite)
    await picked.copy(dest.path);

    // Guardar en meta (DB local)
    await FrameworkLocalDatabase.instance.openForCustomer(customer);
    await FrameworkLocalDatabase.instance.setMeta(_metaLogoKey, dest.path);

    // 🔥 CLAVE: limpiar cache de imágenes
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();

    // Notificar a toda la app
    logoFile.value = dest;
  }

  /// Elimina el logo actual
  Future<void> clearLogo() async {
    final customer = _customerCode;
    if (customer == null || customer.isEmpty) return;

    await FrameworkLocalDatabase.instance.openForCustomer(customer);

    final saved = await FrameworkLocalDatabase.instance.getMeta(_metaLogoKey);
    if (saved != null && saved.isNotEmpty) {
      final f = File(saved);
      if (await f.exists()) {
        await f.delete();
      }
    }

    await FrameworkLocalDatabase.instance.setMeta(_metaLogoKey, '');

    // 🔥 limpiar cache también aquí
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();

    logoFile.value = null;
  }
}
