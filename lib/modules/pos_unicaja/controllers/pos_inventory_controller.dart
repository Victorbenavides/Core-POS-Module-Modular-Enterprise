import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:framework_as/modules/pos_unicaja/data/database/app_database.dart';
import 'package:framework_as/modules/pos_unicaja/models/product.dart';

class PosInventoryController extends ChangeNotifier {
  final List<Product> _products = [];
  late final Future<void> _ready;
  Future<void> get ready => _ready;

  List<Product> get products => List.unmodifiable(_products);

  PosInventoryController() {
    _ready = _init();
  }

  Future<void> _init() async {
    await _loadFromDb();
  }

  /// Helper para asegurar que los booleanos se guarden como 1 o 0 en SQLite
  Map<String, dynamic> _toSqlMap(Product p) {
    final json = p.toJson();
    return {
      ...json,
      'usesInventory': p.usesInventory ? 1 : 0,
      'isWeighed': p.isWeighed ? 1 : 0,
    };
  }

  Future<void> _loadFromDb() async {
    try {
      final db = AppDatabase.db;
      final maps = await db.query('products');

      final list = maps.map((e) => Product.fromJson(e)).toList();

      _products
        ..clear()
        ..addAll(list);

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print("Error cargando inventario SQL: $e");
      }
      // Reintento simple por si la DB tardó en iniciar
      if (e.toString().contains("initialized")) {
         await Future.delayed(const Duration(seconds: 1));
         try {
           final db = AppDatabase.db;
           final maps = await db.query('products');
           _products..clear()..addAll(maps.map((e) => Product.fromJson(e)));
           notifyListeners();
         } catch (_) {}
      }
    }
  }

  Future<void> upsert(Product product) async {
    // 1. Actualizar memoria (UI rápida)
    final index = _products.indexWhere((p) => p.id == product.id);
    if (index == -1) {
      _products.add(product);
    } else {
      _products[index] = product;
    }
    notifyListeners();

    // 2. Persistir en SQLite
    try {
      final db = AppDatabase.db;
      await db.insert(
        'products',
        _toSqlMap(product),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      if (kDebugMode) print("Error guardando producto SQL: $e");
    }
  }

  Future<void> remove(String id) async {
    _products.removeWhere((p) => p.id == id);
    notifyListeners();

    try {
      final db = AppDatabase.db;
      await db.delete('products', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      if (kDebugMode) print("Error eliminando producto SQL: $e");
    }
  }

  Product? findByBarcodeOrName(String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return null;

    try {
      return _products.firstWhere(
        (p) =>
            p.barcode.toLowerCase() == q ||
            p.name.toLowerCase().contains(q),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> discountStock(String productId, double quantity) async {
    final index = _products.indexWhere((p) => p.id == productId);
    if (index == -1) return;

    final p = _products[index];
    if (!p.usesInventory) return;

    final double newStock =
        (p.stock - quantity).clamp(0, double.infinity).toDouble();

    final updatedProduct = p.copyWith(stock: newStock);
    
    // Actualizamos memoria
    _products[index] = updatedProduct;
    notifyListeners();

    // Actualizamos SQL
    await upsert(updatedProduct);
  }

  Future<void> restoreStock(String productId, double quantity) async {
    final index = _products.indexWhere((p) => p.id == productId);
    if (index == -1) return;

    final p = _products[index];
    if (!p.usesInventory) return;

    final double newStock =
        (p.stock + quantity).clamp(0, double.infinity).toDouble();

    final updatedProduct = p.copyWith(stock: newStock);

    // Actualizamos memoria
    _products[index] = updatedProduct;
    notifyListeners();

    // Actualizamos SQL
    await upsert(updatedProduct);
  }
}