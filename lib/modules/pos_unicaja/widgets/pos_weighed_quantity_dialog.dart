// lib/modules/pos_unicaja/widgets/pos_weighed_quantity_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/product.dart';

class PosWeighedQuantityDialog extends StatefulWidget {
  final Product product;

  const PosWeighedQuantityDialog({super.key, required this.product});

  @override
  State<PosWeighedQuantityDialog> createState() =>
      _PosWeighedQuantityDialogState();
}

class _PosWeighedQuantityDialogState extends State<PosWeighedQuantityDialog> {
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _priceCtrl;

  bool _updating = false;

  @override
  void initState() {
    super.initState();

    _qtyCtrl = TextEditingController(text: '0.250');
    _priceCtrl = TextEditingController(
      text: (0.250 * widget.product.salePrice).toStringAsFixed(2),
    );

    _qtyCtrl.addListener(_onQtyChanged);
    _priceCtrl.addListener(_onPriceChanged);
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  double get _qty =>
      double.tryParse(_qtyCtrl.text.replaceAll(',', '.')) ?? 0.0;

  double get _price =>
      double.tryParse(_priceCtrl.text.replaceAll(',', '.')) ?? 0.0;

  void _onQtyChanged() {
    if (_updating) return;

    final qty = _qty;
    if (qty <= 0) return;

    _updating = true;
    final total = qty * widget.product.salePrice;
    _priceCtrl.text = total.toStringAsFixed(2);
    _updating = false;

    setState(() {});
  }

  void _onPriceChanged() {
    if (_updating) return;

    final price = _price;
    if (price <= 0) return;

    _updating = true;
    final qty = price / widget.product.salePrice;
    _qtyCtrl.text = qty.toStringAsFixed(3);
    _updating = false;

    setState(() {});
  }

  void _accept() {
    if (_qty <= 0) return;
    Navigator.pop<double>(context, _qty);
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.enter): const _WeighedAcceptIntent(),
        LogicalKeySet(LogicalKeyboardKey.numpadEnter): const _WeighedAcceptIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _WeighedAcceptIntent: CallbackAction<_WeighedAcceptIntent>(
            onInvoke: (_) {
              _accept();
              return null;
            },
          ),
        },
        child: AlertDialog(
          title: Text(widget.product.name),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Cantidad
                const Text('Cantidad'),
                const SizedBox(height: 6),
                TextField(
                  controller: _qtyCtrl,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    suffixText: widget.product.unit,
                  ),
                  onSubmitted: (_) => _accept(), // ✅ Enter también aquí
                ),

                const SizedBox(height: 12),

                // Importe
                const Text('Importe'),
                const SizedBox(height: 6),
                TextField(
                  controller: _priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    prefixText: '\$ ',
                  ),
                  onSubmitted: (_) => _accept(), // ✅ Enter también aquí
                ),

                const SizedBox(height: 16),

                Text(
                  'Precio por ${widget.product.unit}: \$${widget.product.salePrice.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),

                const SizedBox(height: 12),

                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Báscula apagada (demo)',
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop<double?>(context, null),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: _qty <= 0 ? null : _accept,
              child: const Text('Aceptar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeighedAcceptIntent extends Intent {
  const _WeighedAcceptIntent();
}
