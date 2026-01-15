// lib/modules/pos_unicaja/widgets/pos_inventory_list.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:framework_as/modules/pos_unicaja/controllers/pos_inventory_controller.dart';
import 'package:framework_as/modules/pos_unicaja/models/product.dart';

import 'pos_edit_product.dart';
import 'pos_inventory_report.dart';

enum _InventoryViewMode { byProduct, byStock }
enum _InventoryTypeFilter { all, weighed, pieces }

class PosInventoryListScreen extends StatefulWidget {
  final bool canEditInventory;
  final bool canViewInventoryReport;

  const PosInventoryListScreen({
    super.key,
    required this.canEditInventory,
    required this.canViewInventoryReport,
  });

  @override
  State<PosInventoryListScreen> createState() => _PosInventoryListScreenState();
}

class _PosInventoryListScreenState extends State<PosInventoryListScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  String _query = '';
  String _selectedDepartment = 'Todos';
  _InventoryViewMode _viewMode = _InventoryViewMode.byProduct;
  _InventoryTypeFilter _typeFilter = _InventoryTypeFilter.all;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _viewModeLabel(_InventoryViewMode m) {
    switch (m) {
      case _InventoryViewMode.byProduct:
        return 'Por producto';
      case _InventoryViewMode.byStock:
        return 'Por inventario';
    }
  }

  String _typeLabel(_InventoryTypeFilter f) {
    switch (f) {
      case _InventoryTypeFilter.all:
        return 'Todos';
      case _InventoryTypeFilter.weighed:
        return 'A granel';
      case _InventoryTypeFilter.pieces:
        return 'A piezas';
    }
  }

  @override
  Widget build(BuildContext context) {
    final inventory = context.watch<PosInventoryController>();

    // Departamentos únicos (siempre incluye "Todos")
    final departments = <String>{'Todos'};
    for (final p in inventory.products) {
      final d = p.department.trim(); // <- si tu campo se llama distinto, dímelo
      if (d.isNotEmpty) departments.add(d);
    }
    final departmentList = departments.toList()
      ..sort((a, b) {
        if (a == 'Todos') return -1;
        if (b == 'Todos') return 1;
        return a.toLowerCase().compareTo(b.toLowerCase());
      });

    // Filtrado
    final q = _query.trim().toLowerCase();

    final filtered = inventory.products.where((p) {
      // filtro por tipo
      if (_typeFilter == _InventoryTypeFilter.weighed && !p.isWeighed) return false;
      if (_typeFilter == _InventoryTypeFilter.pieces && p.isWeighed) return false;

      // filtro por departamento
      final dept = p.department.trim();
      if (_selectedDepartment != 'Todos' && dept != _selectedDepartment) return false;

      // búsqueda (producto / barcode / departamento)
      if (q.isEmpty) return true;

      final name = p.name.toLowerCase();
      final barcode = p.barcode.toLowerCase();
      final deptLower = dept.toLowerCase();

      return name.contains(q) || barcode.contains(q) || deptLower.contains(q);
    }).toList();

    // Orden
    if (_viewMode == _InventoryViewMode.byProduct) {
      filtered.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } else {
      // Por inventario: stock menor -> mayor (útil para ver faltantes)
      filtered.sort((a, b) => a.stock.compareTo(b.stock));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventario de productos'),
        actions: [
          if (widget.canViewInventoryReport)
            IconButton(
              tooltip: 'Reporte de inventario',
              icon: const Icon(Icons.assessment_outlined),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PosInventoryReportScreen(
                      inventoryCtrl: inventory,
                    ),
                  ),
                );
              },
            ),
        ],
      ),

      floatingActionButton: widget.canEditInventory
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PosEditProductScreen(
                      inventoryCtrl: inventory,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Nuevo producto'),
            )
          : null,

      body: inventory.products.isEmpty
          ? const Center(child: Text('No hay productos en inventario.'))
          : Column(
              children: [
                // 🔎 Buscador
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: 'Buscar por producto, código o departamento...',
                      border: const OutlineInputBorder(),
                      suffixIcon: _query.trim().isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Limpiar búsqueda',
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchCtrl.clear();
                              },
                            ),
                    ),
                  ),
                ),

                // 🎛️ Filtros
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Departamento
                      SizedBox(
                        width: 260,
                        child: DropdownButtonFormField<String>(
                          value: departmentList.contains(_selectedDepartment)
                              ? _selectedDepartment
                              : 'Todos',
                          decoration: const InputDecoration(
                            labelText: 'Departamento',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: departmentList
                              .map(
                                (d) => DropdownMenuItem(
                                  value: d,
                                  child: Text(d),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _selectedDepartment = v);
                          },
                        ),
                      ),

                      // Tipo: granel / piezas
                      SizedBox(
                        width: 200,
                        child: DropdownButtonFormField<_InventoryTypeFilter>(
                          value: _typeFilter,
                          decoration: const InputDecoration(
                            labelText: 'Tipo',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: _InventoryTypeFilter.values
                              .map(
                                (f) => DropdownMenuItem(
                                  value: f,
                                  child: Text(_typeLabel(f)),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _typeFilter = v);
                          },
                        ),
                      ),

                      // Vista: por producto / por inventario
                      SizedBox(
                        width: 220,
                        child: DropdownButtonFormField<_InventoryViewMode>(
                          value: _viewMode,
                          decoration: const InputDecoration(
                            labelText: 'Vista',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: _InventoryViewMode.values
                              .map(
                                (m) => DropdownMenuItem(
                                  value: m,
                                  child: Text(_viewModeLabel(m)),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _viewMode = v);
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                // 📦 Lista
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(child: Text('Sin resultados.'))
                      : ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (_, index) {
                            final Product p = filtered[index];

                            final dept = p.department.trim();
                            final deptText = dept.isEmpty ? '-' : dept;

                            return ListTile(
                              title: Text(p.name),
                              subtitle: Text(
                                'Depto: $deptText • '
                                'Código: ${p.barcode.isEmpty ? "-" : p.barcode} • '
                                'Precio: \$${p.salePrice.toStringAsFixed(2)} • '
                                'Stock: ${p.stock.toStringAsFixed(2)} ${p.unit}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    p.isWeighed ? Icons.scale : Icons.shopping_bag,
                                    size: 20,
                                  ),

                                  if (widget.canEditInventory) ...[
                                    const SizedBox(width: 4),
                                    PopupMenuButton<String>(
                                      onSelected: (value) async {
                                        if (value == 'edit') {
                                          await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => PosEditProductScreen(
                                                initial: p,
                                                inventoryCtrl: inventory,
                                              ),
                                            ),
                                          );
                                        } else if (value == 'delete') {
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: const Text('Eliminar producto'),
                                              content: Text('¿Eliminar "${p.name}" del inventario?'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(context, false),
                                                  child: const Text('Cancelar'),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () => Navigator.pop(context, true),
                                                  child: const Text('Eliminar'),
                                                ),
                                              ],
                                            ),
                                          );

                                          if (confirm == true) {
                                            inventory.remove(p.id);
                                            // ✅ FIX: Feedback rápido con limpieza
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).clearSnackBars();
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Producto eliminado.')),
                                              );
                                            }
                                          }
                                        }
                                      },
                                      itemBuilder: (context) => const [
                                        PopupMenuItem(
                                          value: 'edit',
                                          child: Text('Editar producto'),
                                        ),
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: Text('Eliminar producto del inventario'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}