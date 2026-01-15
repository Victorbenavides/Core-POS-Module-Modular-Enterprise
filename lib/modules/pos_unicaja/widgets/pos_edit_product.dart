// lib/modules/pos_unicaja/widgets/pos_edit_product.dart
import 'package:flutter/material.dart';

import 'package:framework_as/modules/pos_unicaja/controllers/pos_inventory_controller.dart';
import 'package:framework_as/modules/pos_unicaja/models/product.dart';

class PosEditProductScreen extends StatefulWidget {
  final Product? initial;
  final PosInventoryController inventoryCtrl; // controlador de inventario

  const PosEditProductScreen({
    super.key,
    this.initial,
    required this.inventoryCtrl,
  });

  @override
  State<PosEditProductScreen> createState() => _PosEditProductScreenState();
}

class _PosEditProductScreenState extends State<PosEditProductScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _barcodeCtrl;
  late final TextEditingController _costCtrl;
  late final TextEditingController _gainCtrl;
  late final TextEditingController _saleCtrl;
  late final TextEditingController _wholesaleCtrl;
  late final TextEditingController _stockCtrl;
  late final TextEditingController _minStockCtrl;
  late final TextEditingController _maxStockCtrl;

  bool _isUpdatingPriceFields = false;
  bool _usesInventory = true;
  bool _isWeighed = false;
  String _unit = 'PZA';
  String _department = 'GENERAL';

  /// Lista base de departamentos sugeridos
  static const List<String> _departmentsPresets = [
    'GENERAL',
    'ABARROTES',
    'LÁCTEOS',
    'FRUTAS Y VERDURAS',
    'CARNES',
    'BEBIDAS',
    'SNACKS',
    'LIMPIEZA',
    'HIGIENE',
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.initial;

    _department = p?.department ?? 'GENERAL';

    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _barcodeCtrl = TextEditingController(text: p?.barcode ?? '');
    _costCtrl =
        TextEditingController(text: (p?.costPrice ?? 0).toStringAsFixed(2));
    _gainCtrl =
        TextEditingController(text: (p?.gainPercent ?? 0).toStringAsFixed(2));
    _saleCtrl =
        TextEditingController(text: (p?.salePrice ?? 0).toStringAsFixed(2));
    _wholesaleCtrl = TextEditingController(
        text: (p?.wholesalePrice ?? 0).toStringAsFixed(2));
    _stockCtrl =
        TextEditingController(text: (p?.stock ?? 0).toStringAsFixed(2));
    _minStockCtrl =
        TextEditingController(text: (p?.minStock ?? 0).toStringAsFixed(2));
    _maxStockCtrl =
        TextEditingController(text: (p?.maxStock ?? 0).toStringAsFixed(2));

    _usesInventory = p?.usesInventory ?? true;
    _isWeighed = p?.isWeighed ?? false;
    _unit = p?.unit ?? (_isWeighed ? 'KG' : 'PZA');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _barcodeCtrl.dispose();
    _costCtrl.dispose();
    _gainCtrl.dispose();
    _saleCtrl.dispose();
    _wholesaleCtrl.dispose();
    _stockCtrl.dispose();
    _minStockCtrl.dispose();
    _maxStockCtrl.dispose();
    super.dispose();
  }

  double _parse(String value) {
    return double.tryParse(value.replaceAll(',', '.')) ?? 0.0;
  }

  void _recalcSalePrice() {
    if (_isUpdatingPriceFields) return;

    _isUpdatingPriceFields = true;

    final cost = _parse(_costCtrl.text);
    final gain = _parse(_gainCtrl.text);

    final sale = cost + (cost * gain / 100);
    _saleCtrl.text = sale.toStringAsFixed(2);

    _isUpdatingPriceFields = false;
    setState(() {});
  }

  void _recalcGainFromSalePrice() {
    if (_isUpdatingPriceFields) return;

    _isUpdatingPriceFields = true;

    final cost = _parse(_costCtrl.text);
    final sale = _parse(_saleCtrl.text);

    double gain = 0.0;
    if (cost > 0) {
      gain = ((sale - cost) / cost) * 100;
    }

    _gainCtrl.text = gain.toStringAsFixed(2);

    _isUpdatingPriceFields = false;
    setState(() {});
  }

  /// Construye la lista de sugerencias de departamentos
  List<String> _getDepartmentSuggestions() {
    final set = <String>{};

    // presets base
    set.addAll(_departmentsPresets);

    // departamentos ya usados en productos existentes
    for (final p in widget.inventoryCtrl.products) {
      final d = p.department.trim();
      if (d.isNotEmpty) {
        set.add(d);
      }
    }

    final list = set.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final inventory = widget.inventoryCtrl;

    final id =
        widget.initial?.id ?? DateTime.now().millisecondsSinceEpoch.toString();

    final product = Product(
      id: id,
      name: _nameCtrl.text.trim(),
      barcode: _barcodeCtrl.text.trim(),
      costPrice: _parse(_costCtrl.text),
      gainPercent: _parse(_gainCtrl.text),
      salePrice: _parse(_saleCtrl.text),
      wholesalePrice: _parse(_wholesaleCtrl.text),
      usesInventory: _usesInventory,
      stock: _parse(_stockCtrl.text),
      minStock: _parse(_minStockCtrl.text),
      maxStock: _parse(_maxStockCtrl.text),
      isWeighed: _isWeighed,
      unit: _unit,
      department:
          _department.trim().isEmpty ? 'GENERAL' : _department.trim(),
    );

    inventory.upsert(product);

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;
    final departmentOptions = _getDepartmentSuggestions();

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Editar producto' : 'Nuevo producto'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Nombre
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre del producto',
                  hintText: 'Ej. Queso Oaxaca Económico',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Ingresa un nombre' : null,
              ),
              const SizedBox(height: 12),

              // Código de barras
              TextFormField(
                controller: _barcodeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Código de barras (o manual)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // 👉 Departamento con Autocomplete
              Autocomplete<String>(
                initialValue: TextEditingValue(text: _department),
                optionsBuilder: (TextEditingValue textEditingValue) {
                  final text = textEditingValue.text.trim().toLowerCase();
                  if (text.isEmpty) {
                    // si no hay texto, sugerimos todos
                    return departmentOptions;
                  }
                  return departmentOptions.where(
                    (d) => d.toLowerCase().contains(text),
                  );
                },
                onSelected: (String selection) {
                  setState(() {
                    _department = selection;
                  });
                },
                fieldViewBuilder: (context, textEditingController, focusNode,
                    onFieldSubmitted) {
                  // mantenemos sincronizado el valor inicial
                  if (textEditingController.text != _department) {
                    textEditingController.text = _department;
                    textEditingController.selection =
                        TextSelection.fromPosition(
                      TextPosition(
                          offset: textEditingController.text.length),
                    );
                  }

                  return TextFormField(
                    controller: textEditingController,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      labelText: 'Departamento',
                      hintText: 'Ej. Abarrotes, Lácteos, Dulcería...',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      _department = value;
                    },
                  );
                },
                optionsViewBuilder: (context, onSelected, options) {
                  if (options.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxHeight: 240,
                          maxWidth: 320,
                        ),
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          itemCount: options.length,
                          itemBuilder: (context, index) {
                            final option = options.elementAt(index);
                            return ListTile(
                              title: Text(option),
                              onTap: () => onSelected(option),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),

              // Tipo de venta
              Row(
                children: [
                  const Text('Se vende: '),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Por unidad / pza'),
                    selected: !_isWeighed,
                    onSelected: (_) => setState(() {
                      _isWeighed = false;
                      _unit = 'PZA';
                    }),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('A granel (usa decimales)'),
                    selected: _isWeighed,
                    onSelected: (_) => setState(() {
                      _isWeighed = true;
                      if (_unit == 'PZA') _unit = 'KG';
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (_isWeighed)
                DropdownButtonFormField<String>(
                  value: _unit,
                  decoration: const InputDecoration(
                    labelText: 'Unidad de medida',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'KG', child: Text('KG')),
                    DropdownMenuItem(value: 'G', child: Text('Gramos')),
                    DropdownMenuItem(value: 'L', child: Text('Litros')),
                    DropdownMenuItem(value: 'ML', child: Text('Mililitros')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      _unit = v;
                    });
                  },
                )
              else
                TextFormField(
                  enabled: false,
                  decoration: const InputDecoration(
                    labelText: 'Unidad',
                    border: OutlineInputBorder(),
                    helperText: 'Producto por pieza',
                  ),
                  initialValue: 'PZA',
                ),

              const SizedBox(height: 16),

              // Precios
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _costCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Precio costo',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => _recalcSalePrice(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _gainCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Ganancia %',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => _recalcSalePrice(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _saleCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Precio venta',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => _recalcGainFromSalePrice(),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _wholesaleCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Precio mayoreo (opcional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Inventario
              SwitchListTile(
                title: const Text('Este producto SÍ utiliza inventario'),
                value: _usesInventory,
                onChanged: (v) => setState(() => _usesInventory = v),
              ),
              if (_usesInventory) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _stockCtrl,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                                decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Hay',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _minStockCtrl,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                                decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Mínimo',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _maxStockCtrl,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                                decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Máximo',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save),
                  label: Text(isEdit ? 'Guardar cambios' : 'Crear producto'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
