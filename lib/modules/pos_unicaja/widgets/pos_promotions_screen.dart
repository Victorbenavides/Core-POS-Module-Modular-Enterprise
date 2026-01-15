// lib/modules/pos_unicaja/widgets/pos_promotions_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:framework_as/modules/pos_unicaja/controllers/pos_inventory_controller.dart';
import 'package:framework_as/modules/pos_unicaja/controllers/pos_session.dart';
import 'package:framework_as/modules/pos_unicaja/models/product.dart';

import 'package:framework_as/modules/pos_unicaja/pos_product_search.dart';

import 'package:framework_as/modules/pos_unicaja/promotions/pos_promotion.dart';
import 'package:framework_as/modules/pos_unicaja/promotions/pos_promotions_controller.dart';
import 'package:framework_as/modules/pos_unicaja/promotions/pos_discount.dart';
import 'package:framework_as/modules/pos_unicaja/promotions/pos_discounts_controller.dart';

enum _PromoFilter { all, active, inactive }
enum _DiscountFilter { all, active, inactive }

class PosPromotionsScreen extends StatefulWidget {
  const PosPromotionsScreen({super.key});

  @override
  State<PosPromotionsScreen> createState() => _PosPromotionsScreenState();
}

class _PosPromotionsScreenState extends State<PosPromotionsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  final _promoSearchCtrl = TextEditingController();
  final _discSearchCtrl = TextEditingController();

  String _promoQuery = '';
  String _discQuery = '';

  _PromoFilter _promoFilter = _PromoFilter.all;
  _DiscountFilter _discFilter = _DiscountFilter.all;

  @override
  void initState() {
    super.initState();

    _tabCtrl = TabController(length: 2, vsync: this);

    PosDiscountsController.instance.ensureLoaded();
    PosPromotionsController.instance.ensureLoaded();

    _promoSearchCtrl.addListener(() => setState(() => _promoQuery = _promoSearchCtrl.text));
    _discSearchCtrl.addListener(() => setState(() => _discQuery = _discSearchCtrl.text));
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _promoSearchCtrl.dispose();
    _discSearchCtrl.dispose();
    super.dispose();
  }

  // ✅ Helper para limpiar mensajes acumulados
  void _clearSnack() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
  }

  Future<void> _createOrEditDiscount({PosDiscount? initial}) async {
    final inventory = context.read<PosInventoryController>();

    final res = await showDialog<PosDiscount>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DiscountEditorDialog(
        products: inventory.products,
        initial: initial,
      ),
    );

    if (res == null) return;

    try {
      await PosDiscountsController.instance.upsert(res);
      if (!mounted) return;
      _clearSnack(); // ✅ Limpia antes
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Descuento guardado.'), duration: Duration(seconds: 2)),
      );
    } catch (e) {
      if (!mounted) return;
      _clearSnack(); // ✅ Limpia antes
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _createOrEditPromo({PosPromotion? initial}) async {
    final inventory = context.read<PosInventoryController>();

    final res = await showDialog<PosPromotion>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PromotionEditorDialog(
        products: inventory.products,
        initial: initial,
      ),
    );

    if (res == null) return;

    try {
      await PosPromotionsController.instance.upsert(res);
      if (!mounted) return;
      _clearSnack(); // ✅ Limpia antes
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Promoción guardada.'), duration: Duration(seconds: 2)),
      );
    } catch (e) {
      if (!mounted) return;
      _clearSnack(); // ✅ Limpia antes
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<PosSessionController>();
    final cashier = session.currentCashier;

    final canPromos = cashier != null && (cashier.isAdmin || cashier.canManagePromotions);

    if (!canPromos) {
      return Scaffold(
        appBar: AppBar(title: const Text('Promociones')),
        body: const Center(
          child: Text('No tienes permiso para administrar promociones.'),
        ),
      );
    }

    final inventory = context.watch<PosInventoryController>();
    final promoCtrl = PosPromotionsController.instance;
    final discCtrl = PosDiscountsController.instance;

    final now = DateTime.now();

    return AnimatedBuilder(
      animation: Listenable.merge([promoCtrl, discCtrl]),
      builder: (context, _) {
        final promos = promoCtrl.promotions;
        final discounts = discCtrl.discounts;

        // -------- PROMOS filtradas --------
        final pq = _promoQuery.trim().toLowerCase();
        final filteredPromos = promos.where((p) {
          final activeNow = p.isActiveAt(now);

          if (_promoFilter == _PromoFilter.active && !activeNow) return false;
          if (_promoFilter == _PromoFilter.inactive && activeNow) return false;

          if (pq.isEmpty) return true;

          final inName = p.name.toLowerCase().contains(pq);
          final inProd = p.productName.toLowerCase().contains(pq);
          final inBar = p.productBarcode.toLowerCase().contains(pq);
          return inName || inProd || inBar;
        }).toList();

        // -------- DESCUENTOS filtrados --------
        final dq = _discQuery.trim().toLowerCase();
        final filteredDiscounts = discounts.where((d) {
          final activeNow = d.isActiveAt(now);

          if (_discFilter == _DiscountFilter.active && !activeNow) return false;
          if (_discFilter == _DiscountFilter.inactive && activeNow) return false;

          if (dq.isEmpty) return true;

          final inName = d.name.toLowerCase().contains(dq);
          final inProd = d.productName.toLowerCase().contains(dq);
          final inDep = d.department.toLowerCase().contains(dq);
          return inName || inProd || inDep;
        }).toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Promociones'),
            bottom: TabBar(
              controller: _tabCtrl,
              tabs: const [
                Tab(text: 'Promociones'),
                Tab(text: 'Descuentos'),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () async {
              final currentIndex = _tabCtrl.index;

              if (currentIndex == 0) {
                await _createOrEditPromo();
                return;
              }

              await _createOrEditDiscount();
            },
            icon: const Icon(Icons.add),
            label: AnimatedBuilder(
              animation: _tabCtrl,
              builder: (_, __) => Text(_tabCtrl.index == 0 ? 'Añadir promo' : 'Añadir descuento'),
            ),
          ),
          body: TabBarView(
            controller: _tabCtrl,
            children: [
              // =========================
              // TAB 0: PROMOCIONES
              // =========================
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    child: TextField(
                      controller: _promoSearchCtrl,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: 'Buscar promo / producto / código...',
                        border: const OutlineInputBorder(),
                        suffixIcon: _promoQuery.trim().isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Limpiar',
                                icon: const Icon(Icons.clear),
                                onPressed: () => _promoSearchCtrl.clear(),
                              ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ChoiceChip(
                          label: const Text('Todas'),
                          selected: _promoFilter == _PromoFilter.all,
                          onSelected: (_) => setState(() => _promoFilter = _PromoFilter.all),
                        ),
                        ChoiceChip(
                          label: const Text('Activas'),
                          selected: _promoFilter == _PromoFilter.active,
                          onSelected: (_) => setState(() => _promoFilter = _PromoFilter.active),
                        ),
                        ChoiceChip(
                          label: const Text('Inactivas'),
                          selected: _promoFilter == _PromoFilter.inactive,
                          onSelected: (_) => setState(() => _promoFilter = _PromoFilter.inactive),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Productos: ${inventory.products.length}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: filteredPromos.isEmpty
                        ? const Center(child: Text('No hay promociones.'))
                        : ListView.builder(
                            itemCount: filteredPromos.length,
                            itemBuilder: (_, i) {
                              final p = filteredPromos[i];

                              final isBundle = p.maxQty != null && (p.maxQty! - p.minQty).abs() < 0.000001;

                              final rango = isBundle
                                  ? 'Paquete: ${_fmtQty(p.minQty)}'
                                  : (p.maxQty == null ? '≥ ${_fmtQty(p.minQty)}' : '${_fmtQty(p.minQty)} a ${_fmtQty(p.maxQty!)}');

                              final vigencia = (p.startsAt == null && p.endsAt == null)
                                  ? 'Sin vigencia'
                                  : 'Vig: ${p.startsAt != null ? _fmtDateTime(p.startsAt!) : "—"} → ${p.endsAt != null ? _fmtDateTime(p.endsAt!) : "—"}';

                              final activeNow = p.isActiveAt(now);
                              String status;
                              if (activeNow) {
                                status = 'Activa';
                              } else {
                                if (!p.enabled) {
                                  status = 'Inactiva';
                                } else if (p.startsAt != null && now.isBefore(p.startsAt!)) {
                                  status = 'Programada';
                                } else {
                                  status = 'Fuera de vigencia';
                                }
                              }

                              return Card(
                                margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                                child: ListTile(
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          p.name,
                                          style: const TextStyle(fontWeight: FontWeight.w700),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Chip(
                                        label: Text(status),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ],
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Producto: ${p.productName}'),
                                        Text(
                                          isBundle
                                              ? 'Rango: $rango  •  Precio paquete: \$${p.promoUnitPrice.toStringAsFixed(2)}'
                                              : 'Rango: $rango  •  Precio unitario promo: \$${p.promoUnitPrice.toStringAsFixed(2)}',
                                        ),
                                        Text('Código: ${p.productBarcode.isEmpty ? "-" : p.productBarcode}  •  $vigencia'),
                                      ],
                                    ),
                                  ),
                                  trailing: Wrap(
                                    spacing: 6,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      Switch(
                                        value: p.enabled,
                                        onChanged: (v) async {
                                          try {
                                            await promoCtrl.setEnabled(p.id, v);
                                          } catch (e) {
                                            if (!context.mounted) return;
                                            _clearSnack(); // ✅ Limpia antes
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('$e')),
                                            );
                                          }
                                        },
                                      ),
                                      PopupMenuButton<String>(
                                        onSelected: (value) async {
                                          if (value == 'edit') {
                                            await _createOrEditPromo(initial: p);
                                          } else if (value == 'delete') {
                                            final ok = await showDialog<bool>(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                title: const Text('Eliminar promoción'),
                                                content: Text('¿Eliminar "${p.name}"?'),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(ctx, false),
                                                    child: const Text('Cancelar'),
                                                  ),
                                                  ElevatedButton(
                                                    onPressed: () => Navigator.pop(ctx, true),
                                                    child: const Text('Eliminar'),
                                                  ),
                                                ],
                                              ),
                                            );
                                            if (ok == true) {
                                              await promoCtrl.remove(p.id);
                                              if (mounted) {
                                                _clearSnack(); // ✅ Limpia antes
                                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Eliminado.')));
                                              }
                                            }
                                          }
                                        },
                                        itemBuilder: (_) => const [
                                          PopupMenuItem(value: 'edit', child: Text('Editar')),
                                          PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                                        ],
                                      ),
                                    ],
                                  ),
                                  onTap: () => _createOrEditPromo(initial: p),
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),

              // =========================
              // TAB 1: DESCUENTOS
              // =========================
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    child: TextField(
                      controller: _discSearchCtrl,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: 'Buscar descuento / producto / departamento...',
                        border: const OutlineInputBorder(),
                        suffixIcon: _discQuery.trim().isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Limpiar',
                                icon: const Icon(Icons.clear),
                                onPressed: () => _discSearchCtrl.clear(),
                              ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ChoiceChip(
                          label: const Text('Todos'),
                          selected: _discFilter == _DiscountFilter.all,
                          onSelected: (_) => setState(() => _discFilter = _DiscountFilter.all),
                        ),
                        ChoiceChip(
                          label: const Text('Activos'),
                          selected: _discFilter == _DiscountFilter.active,
                          onSelected: (_) => setState(() => _discFilter = _DiscountFilter.active),
                        ),
                        ChoiceChip(
                          label: const Text('Inactivos'),
                          selected: _discFilter == _DiscountFilter.inactive,
                          onSelected: (_) => setState(() => _discFilter = _DiscountFilter.inactive),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: filteredDiscounts.isEmpty
                        ? const Center(child: Text('No hay descuentos.'))
                        : ListView.builder(
                            itemCount: filteredDiscounts.length,
                            itemBuilder: (_, i) {
                              final d = filteredDiscounts[i];

                              final vigencia = (d.startsAt == null && d.endsAt == null)
                                  ? 'Sin vigencia'
                                  : 'Vig: ${d.startsAt != null ? _fmtDateTime(d.startsAt!) : "—"} → ${d.endsAt != null ? _fmtDateTime(d.endsAt!) : "—"}';

                              final activeNow = d.isActiveAt(now);
                              String status;
                              if (activeNow) {
                                status = 'Activo';
                              } else {
                                if (!d.enabled) {
                                  status = 'Inactivo';
                                } else if (d.startsAt != null && now.isBefore(d.startsAt!)) {
                                  status = 'Programado';
                                } else {
                                  status = 'Fuera de vigencia';
                                }
                              }

                              final scope = d.productId.trim().isNotEmpty
                                  ? 'Producto: ${d.productName}'
                                  : 'Departamento: ${d.department.isEmpty ? "GENERAL" : d.department}';

                              return Card(
                                margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                                child: ListTile(
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          d.name,
                                          style: const TextStyle(fontWeight: FontWeight.w700),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Chip(
                                        label: Text(status),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ],
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(scope),
                                        Text('Descuento: ${d.percent.toStringAsFixed(2)}%'),
                                        Text(vigencia),
                                      ],
                                    ),
                                  ),
                                  trailing: Wrap(
                                    spacing: 6,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      Switch(
                                        value: d.enabled,
                                        onChanged: (v) async {
                                          try {
                                            await discCtrl.setEnabled(d.id, v);
                                          } catch (e) {
                                            if (!context.mounted) return;
                                            _clearSnack(); // ✅ Limpia antes
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('$e')),
                                            );
                                          }
                                        },
                                      ),
                                      PopupMenuButton<String>(
                                        onSelected: (value) async {
                                          if (value == 'edit') {
                                            await _createOrEditDiscount(initial: d);
                                          } else if (value == 'delete') {
                                            final ok = await showDialog<bool>(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                title: const Text('Eliminar descuento'),
                                                content: Text('¿Eliminar "${d.name}"?'),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(ctx, false),
                                                    child: const Text('Cancelar'),
                                                  ),
                                                  ElevatedButton(
                                                    onPressed: () => Navigator.pop(ctx, true),
                                                    child: const Text('Eliminar'),
                                                  ),
                                                ],
                                              ),
                                            );
                                            if (ok == true) {
                                              await discCtrl.remove(d.id);
                                              if (mounted) {
                                                _clearSnack(); // ✅ Limpia antes
                                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Eliminado.')));
                                              }
                                            }
                                          }
                                        },
                                        itemBuilder: (_) => const [
                                          PopupMenuItem(value: 'edit', child: Text('Editar')),
                                          PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                                        ],
                                      ),
                                    ],
                                  ),
                                  onTap: () => _createOrEditDiscount(initial: d),
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  static String _fmtQty(double v) {
    final nearInt = (v - v.roundToDouble()).abs() < 0.000001;
    return nearInt ? v.round().toString() : v.toStringAsFixed(3);
  }

  static String _fmtDateTime(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yy = d.year.toString();
    final hh = d.hour.toString().padLeft(2, '0');
    final mi = d.minute.toString().padLeft(2, '0');
    return '$dd/$mm/$yy $hh:$mi';
  }
}

// ======================================================
// Dialog Promoción (igual a tu versión)
// ======================================================
class _PromotionEditorDialog extends StatefulWidget {
  final List<Product> products;
  final PosPromotion? initial;

  const _PromotionEditorDialog({
    required this.products,
    this.initial,
  });

  @override
  State<_PromotionEditorDialog> createState() => _PromotionEditorDialogState();
}

class _PromotionEditorDialogState extends State<_PromotionEditorDialog> {
  final _nameCtrl = TextEditingController();
  final _minCtrl = TextEditingController(text: '2');
  final _maxCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();

  bool _enabled = true;
  DateTime? _startsAt;
  DateTime? _endsAt;

  Product? _selected;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    if (i != null) {
      _nameCtrl.text = i.name;
      _minCtrl.text = _fmtQty(i.minQty);
      _maxCtrl.text = i.maxQty == null ? '' : _fmtQty(i.maxQty!);
      _priceCtrl.text = i.promoUnitPrice.toStringAsFixed(2);
      _enabled = i.enabled;
      _startsAt = i.startsAt;
      _endsAt = i.endsAt;

      for (final p in widget.products) {
        if (p.id == i.productId) {
          _selected = p;
          break;
        }
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _minCtrl.dispose();
    _maxCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  // ✅ Helper para limpiar mensajes acumulados en el Dialog
  void _clearSnack() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
  }

  double _parseDouble(String s) => double.tryParse(s.replaceAll(',', '.').trim()) ?? 0.0;

  bool _isBundleNow() {
    final min = _parseDouble(_minCtrl.text);
    final maxTxt = _maxCtrl.text.trim();
    final max = maxTxt.isEmpty ? null : _parseDouble(maxTxt);
    if (max == null) return false;
    return (max - min).abs() < 0.000001;
  }

  Future<DateTime?> _pickDateTime({
    required DateTime? current,
    required bool isEnd,
  }) async {
    final now = DateTime.now();
    final initialDate = current ?? now;

    final d = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
    );
    if (d == null) return null;

    final fallbackTime = isEnd ? const TimeOfDay(hour: 23, minute: 59) : const TimeOfDay(hour: 0, minute: 0);

    final initialTime = current != null ? TimeOfDay.fromDateTime(current) : fallbackTime;

    final t = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    final picked = t ?? fallbackTime;

    return DateTime(
      d.year,
      d.month,
      d.day,
      picked.hour,
      picked.minute,
      isEnd ? 59 : 0,
    );
  }

  Future<void> _pickStart() async {
    final dt = await _pickDateTime(current: _startsAt, isEnd: false);
    if (dt == null) return;
    setState(() => _startsAt = dt);
  }

  Future<void> _pickEnd() async {
    final dt = await _pickDateTime(current: _endsAt, isEnd: true);
    if (dt == null) return;
    setState(() => _endsAt = dt);
  }

  Future<void> _selectProduct() async {
    final p = await Navigator.push<Product?>(
      context,
      MaterialPageRoute(
        builder: (_) => PosProductSearchScreen(products: widget.products),
      ),
    );
    if (p == null) return;

    setState(() {
      _selected = p;
      if (_priceCtrl.text.trim().isEmpty) {
        _priceCtrl.text = p.salePrice.toStringAsFixed(2);
      }
    });
  }

  void _save() {
    final sel = _selected;
    if (sel == null) {
      _clearSnack(); // ✅ Limpia
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un producto.'), duration: Duration(seconds: 2)),
      );
      return;
    }

    final name = _nameCtrl.text.trim();
    final min = _parseDouble(_minCtrl.text);
    final maxTxt = _maxCtrl.text.trim();
    final max = maxTxt.isEmpty ? null : _parseDouble(maxTxt);
    final price = _parseDouble(_priceCtrl.text);

    if (name.isEmpty) {
      _clearSnack(); // ✅ Limpia
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nombre requerido.'), duration: Duration(seconds: 2)),
      );
      return;
    }
    if (min <= 0) {
      _clearSnack(); // ✅ Limpia
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La cantidad mínima debe ser > 0.'), duration: Duration(seconds: 2)),
      );
      return;
    }
    if (max != null && max < min) {
      _clearSnack(); // ✅ Limpia
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La cantidad máxima no puede ser menor que la mínima.'), duration: Duration(seconds: 2)),
      );
      return;
    }
    if (price <= 0) {
      _clearSnack(); // ✅ Limpia
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El precio promo debe ser > 0.'), duration: Duration(seconds: 2)),
      );
      return;
    }
    if (_startsAt != null && _endsAt != null && _endsAt!.isBefore(_startsAt!)) {
      _clearSnack(); // ✅ Limpia
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fin no puede ser menor que inicio.'), duration: Duration(seconds: 2)),
      );
      return;
    }

    final id = widget.initial?.id ?? DateTime.now().millisecondsSinceEpoch.toString();

    var promo = PosPromotion(
      id: id,
      name: name,
      productId: sel.id,
      productName: sel.name,
      productBarcode: sel.barcode,
      minQty: min,
      maxQty: max,
      promoUnitPrice: price,
      enabled: _enabled,
      startsAt: _startsAt,
      endsAt: _endsAt,
      createdAt: widget.initial?.createdAt ?? DateTime.now(),
    );

    final now = DateTime.now();
    if (promo.enabled && promo.endsAt != null && now.isAfter(promo.endsAt!)) {
      promo = promo.copyWith(enabled: false);
    }

    Navigator.pop(context, promo);
  }

  static String _fmtQty(double v) {
    final nearInt = (v - v.roundToDouble()).abs() < 0.000001;
    return nearInt ? v.round().toString() : v.toStringAsFixed(3);
  }

  String _fmtDateTime(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yy = d.year.toString();
    final hh = d.hour.toString().padLeft(2, '0');
    final mi = d.minute.toString().padLeft(2, '0');
    return '$dd/$mm/$yy $hh:$mi';
  }

  @override
  Widget build(BuildContext context) {
    final sel = _selected;
    final isBundle = _isBundleNow();

    return AlertDialog(
      title: Text(widget.initial == null ? 'Nueva promoción' : 'Editar promoción'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la promoción',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Producto',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        sel == null ? 'Ninguno seleccionado' : sel.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: _selectProduct,
                    icon: const Icon(Icons.search),
                    label: const Text('Seleccionar'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (sel != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Precio normal: \$${sel.salePrice.toStringAsFixed(2)}  •  Código: ${sel.barcode.isEmpty ? "-" : sel.barcode}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _minCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Cantidad mínima',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _maxCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Cantidad máxima (opcional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  isBundle
                      ? 'Tip: Si Min = Max, el precio se interpreta como PRECIO DEL PAQUETE (ej. 2x1: Min=2, Max=2, Precio=20).'
                      : 'Si Max está vacío o es distinto a Min, el precio se interpreta como PRECIO UNITARIO promocional.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: isBundle ? 'Precio del paquete promocional' : 'Precio unitario promocional',
                  prefixText: '\$ ',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Promoción habilitada'),
                value: _enabled,
                onChanged: (v) => setState(() => _enabled = v),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: PromoDateTimePickerButton(
                      label: 'Inicio (fecha y hora)',
                      value: _startsAt,
                      valueFormatter: _fmtDateTime,
                      onPick: _pickStart,
                      onClear: () => setState(() => _startsAt = null),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: PromoDateTimePickerButton(
                      label: 'Fin (fecha y hora)',
                      value: _endsAt,
                      valueFormatter: _fmtDateTime,
                      onPick: _pickEnd,
                      onClear: () => setState(() => _endsAt = null),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class PromoDateTimePickerButton extends StatelessWidget {
  final String label;
  final DateTime? value;
  final String Function(DateTime) valueFormatter;
  final VoidCallback onPick;
  final VoidCallback onClear;

  const PromoDateTimePickerButton({
    super.key,
    required this.label,
    required this.value,
    required this.valueFormatter,
    required this.onPick,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      child: Row(
        children: [
          Expanded(child: Text(value == null ? '—' : valueFormatter(value!))),
          IconButton(
            tooltip: 'Elegir',
            onPressed: onPick,
            icon: const Icon(Icons.event),
          ),
          IconButton(
            tooltip: 'Quitar',
            onPressed: value == null ? null : onClear,
            icon: const Icon(Icons.clear),
          ),
        ],
      ),
    );
  }
}

class _DiscountEditorDialog extends StatefulWidget {
  final List<Product> products;
  final PosDiscount? initial;

  const _DiscountEditorDialog({
    required this.products,
    this.initial,
  });

  @override
  State<_DiscountEditorDialog> createState() => _DiscountEditorDialogState();
}

enum _DiscountTarget { product, department }

class _DiscountEditorDialogState extends State<_DiscountEditorDialog> {
  final _nameCtrl = TextEditingController();
  final _percentCtrl = TextEditingController(text: '10');

  bool _enabled = true;
  DateTime? _startsAt;
  DateTime? _endsAt;

  _DiscountTarget _target = _DiscountTarget.product;

  Product? _selectedProduct;
  String _selectedDepartment = 'GENERAL';

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    if (i != null) {
      _nameCtrl.text = i.name;
      _percentCtrl.text = i.percent.toStringAsFixed(2);
      _enabled = i.enabled;
      _startsAt = i.startsAt;
      _endsAt = i.endsAt;

      if (i.productId.trim().isNotEmpty) {
        _target = _DiscountTarget.product;
        for (final p in widget.products) {
          if (p.id == i.productId) {
            _selectedProduct = p;
            break;
          }
        }
      } else {
        _target = _DiscountTarget.department;
        _selectedDepartment = i.department.trim().isEmpty ? 'GENERAL' : i.department.trim();
      }
    } else {
      _selectedDepartment = _guessDepartments().first;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _percentCtrl.dispose();
    super.dispose();
  }

  // ✅ Helper para limpiar mensajes en este diálogo
  void _clearSnack() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
  }

  double _parseDouble(String s) => double.tryParse(s.replaceAll(',', '.').trim()) ?? 0.0;

  List<String> _guessDepartments() {
    final set = <String>{'GENERAL'};
    for (final p in widget.products) {
      final d = p.department.trim();
      if (d.isNotEmpty) set.add(d);
    }
    final list = set.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  Future<DateTime?> _pickDateTime({
    required DateTime? current,
    required bool isEnd,
  }) async {
    final now = DateTime.now();
    final initialDate = current ?? now;

    final d = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
    );
    if (d == null) return null;

    final fallbackTime = isEnd ? const TimeOfDay(hour: 23, minute: 59) : const TimeOfDay(hour: 0, minute: 0);

    final initialTime = current != null ? TimeOfDay.fromDateTime(current) : fallbackTime;

    final t = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    final picked = t ?? fallbackTime;

    return DateTime(
      d.year,
      d.month,
      d.day,
      picked.hour,
      picked.minute,
      isEnd ? 59 : 0,
    );
  }

  Future<void> _pickStart() async {
    final dt = await _pickDateTime(current: _startsAt, isEnd: false);
    if (dt == null) return;
    setState(() => _startsAt = dt);
  }

  Future<void> _pickEnd() async {
    final dt = await _pickDateTime(current: _endsAt, isEnd: true);
    if (dt == null) return;
    setState(() => _endsAt = dt);
  }

  Future<void> _selectProduct() async {
    final p = await Navigator.push<Product?>(
      context,
      MaterialPageRoute(
        builder: (_) => PosProductSearchScreen(products: widget.products),
      ),
    );
    if (p == null) return;
    setState(() => _selectedProduct = p);
  }

  String _fmtDateTime(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yy = d.year.toString();
    final hh = d.hour.toString().padLeft(2, '0');
    final mi = d.minute.toString().padLeft(2, '0');
    return '$dd/$mm/$yy $hh:$mi';
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    final percent = _parseDouble(_percentCtrl.text);

    if (name.isEmpty) {
      _clearSnack(); // ✅ Limpia
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nombre requerido.'), duration: Duration(seconds: 2)),
      );
      return;
    }

    if (percent <= 0 || percent >= 100) {
      _clearSnack(); // ✅ Limpia
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El descuento debe ser > 0 y < 100.'), duration: Duration(seconds: 2)),
      );
      return;
    }

    if (_startsAt != null && _endsAt != null && _endsAt!.isBefore(_startsAt!)) {
      _clearSnack(); // ✅ Limpia
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fin no puede ser menor que inicio.'), duration: Duration(seconds: 2)),
      );
      return;
    }

    String productId = '';
    String productName = '';
    String department = '';

    if (_target == _DiscountTarget.product) {
      final sel = _selectedProduct;
      if (sel == null) {
        _clearSnack(); // ✅ Limpia
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecciona un producto.'), duration: Duration(seconds: 2)),
        );
        return;
      }
      productId = sel.id;
      productName = sel.name;
      department = '';
    } else {
      final dep = _selectedDepartment.trim();
      if (dep.isEmpty) {
        _clearSnack(); // ✅ Limpia
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecciona un departamento.'), duration: Duration(seconds: 2)),
        );
        return;
      }
      department = dep;
      productId = '';
      productName = '';
    }

    final id = widget.initial?.id ?? DateTime.now().millisecondsSinceEpoch.toString();

    var d = PosDiscount(
      id: id,
      name: name,
      productId: productId,
      productName: productName,
      department: department,
      percent: percent,
      enabled: _enabled,
      startsAt: _startsAt,
      endsAt: _endsAt,
      createdAt: widget.initial?.createdAt ?? DateTime.now(),
    );

    final now = DateTime.now();
    if (d.enabled && d.endsAt != null && now.isAfter(d.endsAt!)) {
      d = d.copyWith(enabled: false);
    }

    Navigator.pop(context, d);
  }

  @override
  Widget build(BuildContext context) {
    final departments = _guessDepartments();

    return AlertDialog(
      title: Text(widget.initial == null ? 'Nuevo descuento' : 'Editar descuento'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre del descuento',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<_DiscountTarget>(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Por producto'),
                      value: _DiscountTarget.product,
                      groupValue: _target,
                      onChanged: (v) => setState(() => _target = v!),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<_DiscountTarget>(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Por departamento'),
                      value: _DiscountTarget.department,
                      groupValue: _target,
                      onChanged: (v) => setState(() => _target = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_target == _DiscountTarget.product) ...[
                Row(
                  children: [
                    Expanded(
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Producto',
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          _selectedProduct == null ? 'Ninguno seleccionado' : _selectedProduct!.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: _selectProduct,
                      icon: const Icon(Icons.search),
                      label: const Text('Seleccionar'),
                    ),
                  ],
                ),
              ] else ...[
                DropdownButtonFormField<String>(
                  value: departments.contains(_selectedDepartment) ? _selectedDepartment : departments.first,
                  decoration: const InputDecoration(
                    labelText: 'Departamento',
                    border: OutlineInputBorder(),
                  ),
                  items: departments.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _selectedDepartment = v);
                  },
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _percentCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Descuento (%)',
                  border: OutlineInputBorder(),
                  suffixText: '%',
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Descuento habilitado'),
                value: _enabled,
                onChanged: (v) => setState(() => _enabled = v),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: PromoDateTimePickerButton(
                      label: 'Inicio (fecha y hora)',
                      value: _startsAt,
                      valueFormatter: _fmtDateTime,
                      onPick: _pickStart,
                      onClear: () => setState(() => _startsAt = null),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: PromoDateTimePickerButton(
                      label: 'Fin (fecha y hora)',
                      value: _endsAt,
                      valueFormatter: _fmtDateTime,
                      onPick: _pickEnd,
                      onClear: () => setState(() => _endsAt = null),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}