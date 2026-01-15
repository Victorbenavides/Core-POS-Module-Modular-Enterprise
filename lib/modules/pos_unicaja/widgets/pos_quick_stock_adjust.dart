// lib/modules/pos_unicaja/widgets/pos_quick_stock_adjust.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:framework_as/modules/pos_unicaja/controllers/pos_inventory_controller.dart';
import 'package:framework_as/modules/pos_unicaja/models/product.dart';
import 'package:framework_as/modules/pos_unicaja/controllers/pos_session.dart';

enum _StockMode { add, remove }

class PosQuickStockAdjustScreen extends StatefulWidget {
  const PosQuickStockAdjustScreen({super.key});

  @override
  State<PosQuickStockAdjustScreen> createState() =>
      _PosQuickStockAdjustScreenState();
}

class _PosQuickStockAdjustScreenState extends State<PosQuickStockAdjustScreen> {
  final FocusNode _searchFocus = FocusNode(debugLabel: 'quick_stock_search');
  final FocusNode _qtyFocus = FocusNode(debugLabel: 'quick_stock_qty');

  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _qtyCtrl = TextEditingController(text: '1');

  Product? _selected;
  _StockMode _mode = _StockMode.add;

  bool _onlyInventoryProducts = true;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() {}));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusSearch(selectAll: true);
    });
  }

  @override
  void dispose() {
    _searchFocus.dispose();
    _qtyFocus.dispose();
    _searchCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  void _focusSearch({bool selectAll = false}) {
    FocusScope.of(context).requestFocus(_searchFocus);
    if (selectAll) {
      _searchCtrl.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _searchCtrl.text.length,
      );
    }
  }

  void _focusQty({bool selectAll = true}) {
    FocusScope.of(context).requestFocus(_qtyFocus);
    if (selectAll) {
      _qtyCtrl.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _qtyCtrl.text.length,
      );
    }
  }

  double get _qty {
    final txt = _qtyCtrl.text.trim().replaceAll(',', '.');
    return double.tryParse(txt) ?? 0.0;
  }

  bool get _qtyValid => _qty > 0.0;

  void _onSearchSubmitted(String raw) {
    final code = raw.trim();
    if (code.isEmpty) return;

    final inv = context.read<PosInventoryController>();

    Product? found;
    try {
      found = inv.products.firstWhere(
        (p) =>
            p.barcode.trim().isNotEmpty &&
            p.barcode.trim().toLowerCase() == code.toLowerCase(),
      );
    } catch (_) {
      found = null;
    }

    if (found == null) {
      // si parece código de barras, avisamos. Si era búsqueda por nombre, no estorbamos.
      final looksLikeBarcode = !code.contains(' ') && code.length >= 6;
      if (looksLikeBarcode) {
        // ✅ FIX: Anti-stacking
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No existe producto con código: $code')),
        );
      }
      return;
    }

    _selectProduct(found, fromScan: true);
  }

  void _selectProduct(Product p, {bool fromScan = false}) {
    setState(() {
      _selected = p;
      _searchCtrl.text = p.name; // solo visual
      _qtyCtrl.text = '1';
    });

    // ✅ FIX: Anti-stacking
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(fromScan ? 'Escaneado: ${p.name}' : 'Seleccionado: ${p.name}'),
      ),
    );

    _focusQty(selectAll: true);
  }

  List<Product> _filtered(PosInventoryController inv) {
    final q = _searchCtrl.text.trim().toLowerCase();
    Iterable<Product> it = inv.products;

    if (_onlyInventoryProducts) {
      it = it.where((p) => p.usesInventory);
    }

    if (q.isNotEmpty) {
      it = it.where((p) {
        final name = p.name.toLowerCase();
        final bc = p.barcode.toLowerCase();
        return name.contains(q) || (bc.isNotEmpty && bc.contains(q));
      });
    }

    final out = it.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return out.take(40).toList();
  }

  void _bumpQty(double delta) {
    final next = _qty + delta;
    final safe = next <= 0 ? 1.0 : next;

    setState(() {
      _qtyCtrl.text = safe
          .toStringAsFixed(3)
          .replaceAll(RegExp(r'\.?0+$'), '');
    });

    _focusQty(selectAll: true);
  }

  void _apply() {
    final inv = context.read<PosInventoryController>();
    final p = _selected;

    if (p == null) {
      // ✅ FIX: Anti-stacking
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un producto (busca o escanea).')),
      );
      _focusSearch(selectAll: true);
      return;
    }

    if (!p.usesInventory) {
      // ✅ FIX: Anti-stacking
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este producto no usa inventario.')),
      );
      return;
    }

    if (!_qtyValid) {
      // ✅ FIX: Anti-stacking
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cantidad inválida.')),
      );
      _focusQty(selectAll: true);
      return;
    }

    final qty = _qty;

    if (_mode == _StockMode.remove && qty > p.stock + 0.000001) {
      // ✅ FIX: Anti-stacking
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No puedes reducir más de lo disponible. Stock: ${p.stock.toStringAsFixed(2)} ${p.unit}',
          ),
        ),
      );
      _focusQty(selectAll: true);
      return;
    }

    if (_mode == _StockMode.add) {
      inv.restoreStock(p.id, qty);
    } else {
      inv.discountStock(p.id, qty);
    }

    Product updated = p;
    try {
      updated = inv.products.firstWhere((x) => x.id == p.id);
    } catch (_) {}

    setState(() {
      _selected = updated;
      _qtyCtrl.text = '1';
    });

    // ✅ FIX: Anti-stacking
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _mode == _StockMode.add
              ? 'Inventario agregado a "${updated.name}".'
              : 'Inventario reducido de "${updated.name}".',
        ),
      ),
    );

    _focusSearch(selectAll: true);
  }

  @override
Widget build(BuildContext context) {
  final session = context.watch<PosSessionController>();
  final cashier = session.currentCashier;

  final canAdjust = cashier != null && (cashier.isAdmin || cashier.canAdjustStock);
  if (!canAdjust) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajuste rápido de inventario')),
      body: const Center(child: Text('No tienes permiso para ajustar existencias.')),
    );
  }
    final inv = context.watch<PosInventoryController>();
    final filtered = _filtered(inv);

    final p = _selected;
    final qty = _qtyValid ? _qty : 0.0;
    final projected = (p == null)
        ? null
        : (_mode == _StockMode.add ? p.stock + qty : p.stock - qty);

    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.escape): const _CloseIntent(),
        LogicalKeySet(LogicalKeyboardKey.f5): const _ApplyIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _CloseIntent: CallbackAction<_CloseIntent>(
            onInvoke: (_) {
              Navigator.of(context).pop();
              return null;
            },
          ),
          _ApplyIntent: CallbackAction<_ApplyIntent>(
            onInvoke: (_) {
              _apply();
              return null;
            },
          ),
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Ajuste rápido de inventario'),
            actions: [
              IconButton(
                tooltip: 'Enfocar escáner (buscador)',
                onPressed: () => _focusSearch(selectAll: true),
                icon: const Icon(Icons.qr_code_scanner),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Busca o escanea un producto',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Row(
                            children: [
                              Checkbox(
                                value: _onlyInventoryProducts,
                                onChanged: (v) =>
                                    setState(() => _onlyInventoryProducts = v ?? true),
                              ),
                              const Text('Solo inventario'),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        focusNode: _searchFocus,
                        controller: _searchCtrl,
                        textInputAction: TextInputAction.search,
                        onSubmitted: _onSearchSubmitted,
                        decoration: InputDecoration(
                          labelText: 'Buscar (nombre o código)',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchCtrl.text.trim().isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Limpiar',
                                  onPressed: () {
                                    setState(() => _searchCtrl.clear());
                                    _focusSearch(selectAll: true);
                                  },
                                  icon: const Icon(Icons.clear),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Card(
                          child: filtered.isEmpty
                              ? const Center(child: Text('Sin resultados.'))
                              : ListView.builder(
                                  itemCount: filtered.length,
                                  itemBuilder: (_, i) {
                                    final x = filtered[i];
                                    final sel = _selected?.id == x.id;

                                    return ListTile(
                                      selected: sel,
                                      title: Text(x.name),
                                      subtitle: Text(
                                        'Código: ${x.barcode.isEmpty ? '-' : x.barcode}  •  '
                                        'Stock: ${x.stock.toStringAsFixed(2)} ${x.unit}'
                                        '${x.usesInventory ? '' : '  •  (no usa inv)'}',
                                      ),
                                      trailing: sel ? const Icon(Icons.check_circle) : null,
                                      onTap: () => _selectProduct(x),
                                    );
                                  },
                                ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 16),

                SizedBox(
                  width: 380,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Ajustar inventario',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 10),

                          if (p == null) ...[
                            const Text('Selecciona un producto para continuar.'),
                          ] else ...[
                            Text(
                              p.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text('Stock actual: ${p.stock.toStringAsFixed(2)} ${p.unit}'),
                            if (p.barcode.trim().isNotEmpty) Text('Código: ${p.barcode}'),
                            if (!p.usesInventory)
                              const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text(
                                  '⚠️ Este producto no usa inventario.',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],

                          const SizedBox(height: 14),

                          SegmentedButton<_StockMode>(
                            segments: const [
                              ButtonSegment(
                                value: _StockMode.add,
                                label: Text('Agregar'),
                                icon: Icon(Icons.add),
                              ),
                              ButtonSegment(
                                value: _StockMode.remove,
                                label: Text('Reducir'),
                                icon: Icon(Icons.remove),
                              ),
                            ],
                            selected: {_mode},
                            onSelectionChanged: (s) {
                              setState(() => _mode = s.first);
                              _focusQty(selectAll: true);
                            },
                          ),

                          const SizedBox(height: 12),

                          // ✅ + / - aquí (sin FocusNode duplicado)
                          Shortcuts(
                            shortcuts: <LogicalKeySet, Intent>{
                              LogicalKeySet(LogicalKeyboardKey.numpadAdd): const _QtyUpIntent(),
                              LogicalKeySet(LogicalKeyboardKey.shift, LogicalKeyboardKey.equal):
                                  const _QtyUpIntent(),
                              LogicalKeySet(LogicalKeyboardKey.numpadSubtract):
                                  const _QtyDownIntent(),
                              LogicalKeySet(LogicalKeyboardKey.minus): const _QtyDownIntent(),
                            },
                            child: Actions(
                              actions: <Type, Action<Intent>>{
                                _QtyUpIntent: CallbackAction<_QtyUpIntent>(
                                  onInvoke: (_) {
                                    _bumpQty(1);
                                    return null;
                                  },
                                ),
                                _QtyDownIntent: CallbackAction<_QtyDownIntent>(
                                  onInvoke: (_) {
                                    _bumpQty(-1);
                                    return null;
                                  },
                                ),
                              },
                              child: TextField(
                                focusNode: _qtyFocus,
                                controller: _qtyCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [
                                  // evitamos que + o - se escriban (solo sirven de atajo)
                                  FilteringTextInputFormatter.allow(RegExp(r'[0-9\.,]')),
                                ],
                                decoration: const InputDecoration(
                                  labelText: 'Cantidad',
                                  border: OutlineInputBorder(),
                                  helperText:
                                      'Enter = aplicar • +/- = ajustar cantidad • F5 = aplicar • Esc = cerrar',
                                ),
                                onSubmitted: (_) => _apply(),
                              ),
                            ),
                          ),

                          const SizedBox(height: 10),

                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _bumpQty(-1),
                                  child: const Text('-1'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _bumpQty(1),
                                  child: const Text('+1'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _bumpQty(5),
                                  child: const Text('+5'),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          if (p != null && _qtyValid) ...[
                            Text(
                              'Después del ajuste: ${projected!.toStringAsFixed(2)} ${p.unit}',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: (_mode == _StockMode.remove && projected < -0.000001)
                                    ? Colors.red
                                    : null,
                              ),
                            ),
                          ],

                          const Spacer(),

                          ElevatedButton.icon(
                            onPressed: (p == null) ? null : _apply,
                            icon: const Icon(Icons.check),
                            label: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text('Aplicar ajuste'),
                            ),
                          ),

                          const SizedBox(height: 8),

                          Text(
                            'Tip: Escanea y presiona Enter; se selecciona el producto.\n'
                            'Luego cantidad y Enter para aplicar. (+/- funcionan en Cantidad).',
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CloseIntent extends Intent {
  const _CloseIntent();
}

class _ApplyIntent extends Intent {
  const _ApplyIntent();
}

class _QtyUpIntent extends Intent {
  const _QtyUpIntent();
}

class _QtyDownIntent extends Intent {
  const _QtyDownIntent();
}