import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AppPaths {
  AppPaths._();
  static final AppPaths instance = AppPaths._();

  Directory? _baseDir;

  /// Base segura de la app (NO depende del working dir)
  Future<Directory> baseDir() async {
    if (_baseDir != null) return _baseDir!;

    final dir = await getApplicationSupportDirectory();

    final root = Directory(
      p.join(dir.path, 'framework_as'),
    );

    if (!await root.exists()) {
      await root.create(recursive: true);
    }

    _baseDir = root;
    return root;
  }

  /// app_data/
  Future<Directory> appData() async {
    final base = await baseDir();
    final dir = Directory(p.join(base.path, 'app_data'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// app_data/customers/
  Future<Directory> customers() async {
    final base = await appData();
    final dir = Directory(p.join(base.path, 'customers'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// app_data/customers/{customer}
  Future<Directory> customer(String customerCode) async {
    final root = await customers();
    final dir = Directory(
      p.join(root.path, customerCode.toLowerCase()),
    );
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }
}
