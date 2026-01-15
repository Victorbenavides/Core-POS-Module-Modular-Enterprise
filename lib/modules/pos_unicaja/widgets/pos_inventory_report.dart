import 'package:flutter/material.dart';

import 'package:framework_as/modules/pos_unicaja/controllers/pos_inventory_controller.dart';
import 'package:framework_as/modules/pos_unicaja/models/product.dart';

class PosInventoryReportScreen extends StatelessWidget {
  final PosInventoryController inventoryCtrl;

  const PosInventoryReportScreen({
    super.key,
    required this.inventoryCtrl,
  });

  @override
  Widget build(BuildContext context) {
    // Copiamos la lista para no mutar el controlador
    final List<Product> products = [...inventoryCtrl.products];

    // Orden: primero por departamento, luego por nombre (como tenías)
    products.sort((a, b) {
      final dep =
          a.department.toLowerCase().compareTo(b.department.toLowerCase());
      if (dep != 0) return dep;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    // --------- Cálculos para "Total invertido" ---------

    // Inversión por producto
    final List<_ProductInvest> byProduct = products
        .map(
          (p) => _ProductInvest(
            product: p,
            invested: p.costPrice * p.stock,
          ),
        )
        .toList()
      ..sort((a, b) => b.invested.compareTo(a.invested));

    // Inversión por departamento
    final Map<String, double> deptMap = {};
    for (final p in products) {
      final deptRaw = p.department.trim();
      final dept = deptRaw.isEmpty ? 'GENERAL' : deptRaw;
      final invested = p.costPrice * p.stock;
      deptMap[dept] = (deptMap[dept] ?? 0) + invested;
    }

    final List<MapEntry<String, double>> byDept = deptMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final double totalInvested =
        byProduct.fold(0.0, (sum, e) => sum + e.invested);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Reporte de inventario'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Stock'),
              Tab(text: 'Por producto'),
              Tab(text: 'Por depto.'),
              Tab(text: 'General'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildStockTab(products),
            _buildByProductTab(context, byProduct),
            _buildByDeptTab(context, byDept),
            _buildGeneralTab(context, totalInvested, byDept, products.length),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------
  //  TAB 1: tu listado original de stock
  // --------------------------------------------------

  Widget _buildStockTab(List<Product> products) {
    if (products.isEmpty) {
      return const Center(
        child: Text('No hay productos registrados.'),
      );
    }

    return ListView.separated(
      itemCount: products.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, index) {
        final p = products[index];
        final color = _stockColor(p);

        return ListTile(
          title: Text(
            p.name,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Depto: ${p.department}'),
              Text(
                'Stock: ${p.stock.toStringAsFixed(2)} ${p.unit} '
                '• Mín: ${p.minStock.toStringAsFixed(2)} '
                '• Máx: ${p.maxStock.toStringAsFixed(2)}',
              ),
              Text(
                'Ganancia: ${p.gainPercent.toStringAsFixed(2)} %  '
                '• Precio venta: \$${p.salePrice.toStringAsFixed(2)}',
              ),
            ],
          ),
          trailing: Icon(
            Icons.circle,
            color: color,
            size: 14,
          ),
        );
      },
    );
  }

  Color _stockColor(Product p) {
    if (!p.usesInventory) return Colors.grey;

    if (p.stock <= 0) {
      return Colors.red.shade600;
    }

    // Umbrales: 10 pzas, 3 unidades a granel (igual que antes)
    final double threshold = p.isWeighed ? 3.0 : 10.0;
    if (p.stock < threshold) {
      return Colors.orange.shade700;
    }

    return Colors.green.shade700;
  }

  // --------------------------------------------------
  //  TAB 2: Total invertido POR PRODUCTO
  // --------------------------------------------------

  Widget _buildByProductTab(
    BuildContext context,
    List<_ProductInvest> items,
  ) {
    if (items.isEmpty) {
      return const Center(
        child: Text('No hay productos en inventario.'),
      );
    }

    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Text(
                    'Total invertido por producto',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Text(
                    '${items.length} productos',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, index) {
                  final e = items[index];
                  final p = e.product;
                  return ListTile(
                    title: Text(p.name),
                    subtitle: Text(
                      'Depto: ${p.department.isEmpty ? "GENERAL" : p.department}\n'
                      'Costo: \$${p.costPrice.toStringAsFixed(2)}  •  '
                      'Existencia: ${p.stock.toStringAsFixed(2)} ${p.unit}',
                    ),
                    trailing: Text(
                      _money(e.invested),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------
  //  TAB 3: Total invertido POR DEPARTAMENTO
  // --------------------------------------------------

  Widget _buildByDeptTab(
    BuildContext context,
    List<MapEntry<String, double>> depts,
  ) {
    if (depts.isEmpty) {
      return const Center(
        child: Text('No hay datos de departamentos.'),
      );
    }

    final theme = Theme.of(context);
    final double total =
        depts.fold(0.0, (sum, e) => sum + e.value);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Text(
                    'Total invertido por departamento',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Text(
                    'Total: ${_money(total)}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                itemCount: depts.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, index) {
                  final e = depts[index];
                  final dept = e.key.isEmpty ? 'GENERAL' : e.key;
                  final value = e.value;
                  final percent = total == 0
                      ? 0
                      : (value / total) * 100.0;
                  return ListTile(
                    title: Text(dept),
                    subtitle: Text(
                      '${percent.toStringAsFixed(1)} % del inventario',
                    ),
                    trailing: Text(
                      _money(value),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------
  //  TAB 4: RESUMEN GENERAL
  // --------------------------------------------------

  Widget _buildGeneralTab(
    BuildContext context,
    double totalInvested,
    List<MapEntry<String, double>> depts,
    int productCount,
  ) {
    final theme = Theme.of(context);

    final String topDept = depts.isEmpty
        ? 'N/A'
        : depts.first.key.isEmpty
            ? 'GENERAL'
            : depts.first.key;

    final double topDeptValue =
        depts.isEmpty ? 0.0 : depts.first.value;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Resumen general de inversión',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _summaryRow(
                theme,
                label: 'Total invertido en inventario',
                value: _money(totalInvested),
                big: true,
              ),
              const SizedBox(height: 12),
              _summaryRow(
                theme,
                label: 'Número de productos',
                value: productCount.toString(),
              ),
              const SizedBox(height: 12),
              _summaryRow(
                theme,
                label: 'Departamento con mayor inversión',
                value: topDept,
              ),
              const SizedBox(height: 4),
              if (depts.isNotEmpty)
                Text(
                  _money(topDeptValue),
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              const Spacer(),
              const Text(
                '“Total invertido” = costo unitario × existencia actual.',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------
  //  Helpers
  // --------------------------------------------------

  Widget _summaryRow(
    ThemeData theme, {
    required String label,
    required String value,
    bool big = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: (big
                  ? theme.textTheme.titleLarge
                  : theme.textTheme.titleMedium)
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  static String _money(double value) =>
      '\$${value.toStringAsFixed(2)}';
}

class _ProductInvest {
  final Product product;
  final double invested;

  _ProductInvest({
    required this.product,
    required this.invested,
  });
}
