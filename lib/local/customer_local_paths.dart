import 'dart:io';
import 'package:path/path.dart' as p;

/// Servicio ÚNICO para resolver paths locales por cliente.
/// ✅ Portable: guarda al lado del exe en /data/app_data/
/// ❗ Nadie más debe construir paths manualmente.
class CustomerLocalPaths {
  CustomerLocalPaths._();
  static final CustomerLocalPaths instance = CustomerLocalPaths._();

  // Puedes cambiar esto si quieres otro nombre
  static const String _rootFolderName = 'app_data';

  /// Base portable:
  /// <exeDir>/data/app_data/customers
  Future<Directory> _baseDir() async {
    // Evita Directory.current (varía según cómo se ejecute)
    final exeDir = p.dirname(Platform.resolvedExecutable);

    final base = Directory(
      p.join(exeDir, 'data', _rootFolderName, 'customers'),
    );

    if (!await base.exists()) {
      await base.create(recursive: true);
    }

    // 🔎 LOGS CLAVE
    print("📌 [PATHS] exeDir: $exeDir");
    print("📌 [PATHS] baseDir: ${base.path}");

    return base;
  }

  /// ✅ EXPUESTO PARA AUTH SERVICE (FUENTE DE VERDAD)
  /// <exeDir>/data/app_data/customers
  Future<Directory> baseCustomersDir() async {
    return _baseDir();
  }

  /// Carpeta raíz de un cliente
  /// <base>/<customerCode>/
  Future<Directory> customerRoot(String customerCode) async {
    final base = await _baseDir();

    // Normaliza para evitar duplicados tipo "Demo" vs "demo"
    final safe = customerCode.trim().toLowerCase();

    final dir = Directory(p.join(base.path, safe));

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    print("📌 [PATHS] customerRoot($safe): ${dir.path}");
    return dir;
  }

  /// Carpeta del framework local
  /// <customerRoot>/framework/
  Future<Directory> frameworkDir(String customerCode) async {
    final root = await customerRoot(customerCode);
    final dir = Directory(p.join(root.path, 'framework'));

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    print("📌 [PATHS] frameworkDir: ${dir.path}");
    return dir;
  }

  /// Path completo del framework.db
  Future<String> frameworkDbPath(String customerCode) async {
    final dir = await frameworkDir(customerCode);
    final dbPath = p.join(dir.path, 'framework.db');
    print("📌 [PATHS] frameworkDbPath: $dbPath");
    return dbPath;
  }

  /// Carpeta base de módulos
  /// <customerRoot>/modules/
  Future<Directory> modulesDir(String customerCode) async {
    final root = await customerRoot(customerCode);
    final dir = Directory(p.join(root.path, 'modules'));

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    print("📌 [PATHS] modulesDir: ${dir.path}");
    return dir;
  }

  /// Path del módulo específico
  /// <modules>/<module>/<module>.db
  Future<String> moduleDbPath(String customerCode, String module) async {
    final modules = await modulesDir(customerCode);

    final mod = module.trim().toLowerCase();
    final dir = Directory(p.join(modules.path, mod));

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final dbPath = p.join(dir.path, '$mod.db');
    print("📌 [PATHS] moduleDbPath($mod): $dbPath");
    return dbPath;
  }
}
