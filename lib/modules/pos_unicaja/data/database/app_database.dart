// lib/modules/pos_unicaja/data/database/app_database.dart
import 'package:sqflite/sqflite.dart';
import 'package:framework_as/local/customer_local_paths.dart';

class AppDatabase {
  static Database? _db;
  static Future<void>? _initFuture;

  // ✅ customer actualmente “montado” (para evitar mezclar)
  static String? _currentCustomer;

  /// ✅ Inicializa DB del POS para un customer específico (AISLADO).
  static Future<void> initForCustomer(String customerCode) {
    final safe = customerCode.trim().toLowerCase();

    // Si ya está inicializada para ese customer, no hacemos nada.
    if (_db != null && _currentCustomer == safe) {
      return Future.value();
    }

    // Si había otra DB abierta (otro customer), la cerramos y reiniciamos.
    if (_db != null && _currentCustomer != safe) {
      _initFuture ??= Future.value(); 
      return _switchCustomer(safe);
    }

    // Primera vez
    _currentCustomer = safe;
    _initFuture ??= _initImpl(safe);
    return _initFuture!;
  }

  static Future<void> init() {
    throw Exception(
      "AppDatabase.init() ya no se usa. Usa AppDatabase.initForCustomer(customerCode).",
    );
  }

  static Future<void> _switchCustomer(String safeCustomer) async {
    try {
      await close();
    } catch (_) {}
    _currentCustomer = safeCustomer;
    _initFuture = _initImpl(safeCustomer);
    await _initFuture!;
  }

  static Future<void> _initImpl(String safeCustomer) async {
    if (_db != null) return;

    final path = await CustomerLocalPaths.instance.moduleDbPath(
      safeCustomer,
      'pos_unicaja',
    );

    _db = await openDatabase(
      path,
      // 🚨 CAMBIO IMPORTANTE: Versión 10 para aplicar Promos y Descuentos
      version: 10, 
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
      },
      onCreate: (db, _) async {
        await _createAll(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // Ejecutamos todo (es seguro por IF NOT EXISTS)
        await _createCashiers(db);
        await _migrateCashiersColumns(db);

        await _createSales(db);
        await _createCashSessions(db);
        await _createProducts(db);
        await _createCustomers(db);
        await _createPrintTemplate(db);
        await _createCredits(db);
        
        // ✅ NUEVO: Tablas de ofertas
        await _createPromotions(db);
        await _createDiscounts(db);

        // ✅ NUEVO: Índices actualizados
        await _createIndexes(db);
      },
    );

    await _migrateCashiersColumns(_db!);
  }

  static Database get db {
    if (_db == null) {
      throw Exception(
        "La base de datos POS no fue inicializada. "
        "Llama AppDatabase.initForCustomer(customerCode) antes de usarla.",
      );
    }
    return _db!;
  }

  static Future<void> close() async {
    final d = _db;
    _db = null;
    _initFuture = null;
    _currentCustomer = null;

    if (d != null) {
      await d.close();
    }
  }

  // =========================
  // CREACIÓN / MIGRACIONES
  // =========================

  static Future<void> _createAll(Database db) async {
    await _createCashiers(db);
    await _migrateCashiersColumns(db);
    await _createSales(db);
    await _createCashSessions(db);
    await _createProducts(db);
    await _createCustomers(db);
    await _createPrintTemplate(db);
    await _createCredits(db);
    // ✅ Agregamos ofertas
    await _createPromotions(db);
    await _createDiscounts(db);
    
    await _createIndexes(db);
  }

  static Future<void> _createCashiers(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cashiers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL DEFAULT '',
        pin TEXT NOT NULL DEFAULT '',
        isAdmin INTEGER NOT NULL DEFAULT 0,
        
        -- Permisos (legacy + nuevos)
        canManageInventory INTEGER NOT NULL DEFAULT 0,
        canViewReports INTEGER NOT NULL DEFAULT 0,
        canCancelSales INTEGER NOT NULL DEFAULT 0,
        canOpenCash INTEGER NOT NULL DEFAULT 0,
        canCloseCash INTEGER NOT NULL DEFAULT 0,
        canCharge INTEGER NOT NULL DEFAULT 0,
        canEditSale INTEGER NOT NULL DEFAULT 0,
        canViewInventory INTEGER NOT NULL DEFAULT 0,
        canEditInventory INTEGER NOT NULL DEFAULT 0,
        canAdjustStock INTEGER NOT NULL DEFAULT 0,
        canManagePromotions INTEGER NOT NULL DEFAULT 0,
        canManageCustomers INTEGER NOT NULL DEFAULT 0,
        canUseCredits INTEGER NOT NULL DEFAULT 0,
        canManageCredits INTEGER NOT NULL DEFAULT 0,
        canDailyClose INTEGER NOT NULL DEFAULT 0,
        canSalesReport INTEGER NOT NULL DEFAULT 0,
        canSalesSummary INTEGER NOT NULL DEFAULT 0,
        canManageCashiers INTEGER NOT NULL DEFAULT 0,
        canManagePeripherals INTEGER NOT NULL DEFAULT 0,
        canManagePrintTemplate INTEGER NOT NULL DEFAULT 0,
        canManageSettings INTEGER NOT NULL DEFAULT 0
      );
    ''');
  }

  static Future<void> _migrateCashiersColumns(Database db) async {
    final cols = await db.rawQuery("PRAGMA table_info(cashiers);");
    final existing = <String>{};
    for (final c in cols) {
      final name = (c['name'] ?? '').toString();
      if (name.isNotEmpty) existing.add(name);
    }

    Future<void> add(String name, String typeAndDefault) async {
      if (existing.contains(name)) return;
      await db.execute('ALTER TABLE cashiers ADD COLUMN $name $typeAndDefault;');
      existing.add(name);
    }

    // Aseguramos todas las columnas
    await add('name', "TEXT NOT NULL DEFAULT ''");
    await add('pin', "TEXT NOT NULL DEFAULT ''");
    await add('isAdmin', 'INTEGER NOT NULL DEFAULT 0');
    await add('canManageInventory', 'INTEGER NOT NULL DEFAULT 0');
    await add('canViewReports', 'INTEGER NOT NULL DEFAULT 0');
    await add('canCancelSales', 'INTEGER NOT NULL DEFAULT 0');
    await add('canOpenCash', 'INTEGER NOT NULL DEFAULT 0');
    await add('canCloseCash', 'INTEGER NOT NULL DEFAULT 0');
    await add('canCharge', 'INTEGER NOT NULL DEFAULT 0');
    await add('canEditSale', 'INTEGER NOT NULL DEFAULT 0');
    await add('canViewInventory', 'INTEGER NOT NULL DEFAULT 0');
    await add('canEditInventory', 'INTEGER NOT NULL DEFAULT 0');
    await add('canAdjustStock', 'INTEGER NOT NULL DEFAULT 0');
    await add('canManagePromotions', 'INTEGER NOT NULL DEFAULT 0');
    await add('canManageCustomers', 'INTEGER NOT NULL DEFAULT 0');
    await add('canUseCredits', 'INTEGER NOT NULL DEFAULT 0');
    await add('canManageCredits', 'INTEGER NOT NULL DEFAULT 0');
    await add('canDailyClose', 'INTEGER NOT NULL DEFAULT 0');
    await add('canSalesReport', 'INTEGER NOT NULL DEFAULT 0');
    await add('canSalesSummary', 'INTEGER NOT NULL DEFAULT 0');
    await add('canManageCashiers', 'INTEGER NOT NULL DEFAULT 0');
    await add('canManagePeripherals', 'INTEGER NOT NULL DEFAULT 0');
    await add('canManagePrintTemplate', 'INTEGER NOT NULL DEFAULT 0');
    await add('canManageSettings', 'INTEGER NOT NULL DEFAULT 0');
  }

  static Future<void> _createSales(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sales (
        id TEXT PRIMARY KEY,
        createdAtMs INTEGER NOT NULL,
        cashierId TEXT NOT NULL,
        paymentMethod TEXT NOT NULL,
        customerId TEXT NOT NULL DEFAULT '',
        total REAL NOT NULL,
        json TEXT NOT NULL
      );
    ''');
  }

  static Future<void> _createCashSessions(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cash_sessions (
        id TEXT PRIMARY KEY,
        cashierId TEXT NOT NULL,
        openedAtMs INTEGER NOT NULL,
        closedAtMs INTEGER,
        openingAmount REAL NOT NULL,
        salesTotal REAL NOT NULL,
        cancelledTotal REAL NOT NULL,
        isOpen INTEGER NOT NULL,
        json TEXT NOT NULL
      );
    ''');
  }

  static Future<void> _createProducts(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS products (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        barcode TEXT NOT NULL,
        costPrice REAL NOT NULL DEFAULT 0,
        gainPercent REAL NOT NULL DEFAULT 0,
        salePrice REAL NOT NULL DEFAULT 0,
        wholesalePrice REAL NOT NULL DEFAULT 0,
        usesInventory INTEGER NOT NULL DEFAULT 0,
        stock REAL NOT NULL DEFAULT 0,
        minStock REAL NOT NULL DEFAULT 0,
        maxStock REAL NOT NULL DEFAULT 0,
        isWeighed INTEGER NOT NULL DEFAULT 0,
        unit TEXT NOT NULL DEFAULT 'PZA',
        department TEXT NOT NULL DEFAULT 'GENERAL'
      );
    ''');
  }

  static Future<void> _createCustomers(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS customers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT NOT NULL DEFAULT '',
        notes TEXT NOT NULL DEFAULT '',
        creditLimit REAL NOT NULL DEFAULT 0,
        creditUsed REAL NOT NULL DEFAULT 0,
        enabled INTEGER NOT NULL DEFAULT 1,
        createdAtMs INTEGER NOT NULL DEFAULT 0,
        updatedAtMs INTEGER NOT NULL DEFAULT 0,
        json TEXT NOT NULL
      );
    ''');
  }
  
  static Future<void> _createPrintTemplate(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS print_template (
        id TEXT PRIMARY KEY,
        json TEXT NOT NULL
      );
    ''');
  }
  
  static Future<void> _createCredits(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS credit_entries (
        id TEXT PRIMARY KEY,
        customerId TEXT NOT NULL,
        saleId TEXT NOT NULL,
        status TEXT NOT NULL, 
        createdAtMs INTEGER NOT NULL,
        json TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS credit_payments (
        id TEXT PRIMARY KEY,
        customerId TEXT NOT NULL,
        entryId TEXT NOT NULL,
        createdAtMs INTEGER NOT NULL,
        json TEXT NOT NULL
      );
    ''');
  }

  // ✅ NUEVA: Tabla de Promociones (ej: 2x1)
  static Future<void> _createPromotions(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS promotions (
        id TEXT PRIMARY KEY,
        productId TEXT NOT NULL DEFAULT '',
        enabled INTEGER NOT NULL DEFAULT 1,
        startsAtMs INTEGER,
        endsAtMs INTEGER,
        json TEXT NOT NULL
      );
    ''');
  }

  // ✅ NUEVA: Tabla de Descuentos (ej: -10%)
  static Future<void> _createDiscounts(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS discounts (
        id TEXT PRIMARY KEY,
        productId TEXT NOT NULL DEFAULT '',
        department TEXT NOT NULL DEFAULT '',
        enabled INTEGER NOT NULL DEFAULT 1,
        startsAtMs INTEGER,
        endsAtMs INTEGER,
        json TEXT NOT NULL
      );
    ''');
  }

  // ✅ ÍNDICES OPTIMIZADOS (Incluyendo los nuevos)
  static Future<void> _createIndexes(Database db) async {
    // Ventas
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sales_createdAtMs ON sales(createdAtMs);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sales_cashierId ON sales(cashierId);');

    // Caja
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sessions_openedAtMs ON cash_sessions(openedAtMs);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sessions_cashierId ON cash_sessions(cashierId);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sessions_isOpen ON cash_sessions(isOpen);');

    // Productos
    await db.execute('CREATE INDEX IF NOT EXISTS idx_products_barcode ON products(barcode);');

    // Clientes
    await db.execute('CREATE INDEX IF NOT EXISTS idx_customers_name ON customers(name);');

    // Créditos
    await db.execute('CREATE INDEX IF NOT EXISTS idx_cred_ent_cust ON credit_entries(customerId);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_cred_pay_cust ON credit_payments(customerId);');

    // ✅ OFERTAS: Índices para búsqueda ultra rápida al escanear
    await db.execute('CREATE INDEX IF NOT EXISTS idx_promos_prod ON promotions(productId);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_discounts_prod ON discounts(productId);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_discounts_dept ON discounts(department);');
  }
}