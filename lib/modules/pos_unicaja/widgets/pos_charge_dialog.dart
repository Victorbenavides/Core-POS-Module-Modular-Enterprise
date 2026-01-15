import 'package:flutter/material.dart';

class PosChargeResult {
  final String paymentMethod; // 'cash' | 'card' | 'transfer'
  final double? cashReceived;
  final double? change;
  final String? transferAccount; // placeholder (settings después)
  final String? transferFromName;
  final bool printTicket;

  const PosChargeResult({
    required this.paymentMethod,
    this.cashReceived,
    this.change,
    this.transferAccount,
    this.transferFromName,
    required this.printTicket,
  });
}

class PosChargeDialog extends StatefulWidget {
  final double total;

  const PosChargeDialog({
    super.key,
    required this.total,
  });

  @override
  State<PosChargeDialog> createState() => _PosChargeDialogState();
}

class _PosChargeDialogState extends State<PosChargeDialog> {
  String _method = 'cash';
  bool _printTicket = true;

  // Efectivo
  final TextEditingController _cashCtrl = TextEditingController(text: '');
  double _cashReceived = 0;

  // Transferencia (placeholder)
  final List<String> _accounts = const ['Cuenta 1 (demo)', 'Cuenta 2 (demo)'];
  String _selectedAccount = 'Cuenta 1 (demo)';
  final TextEditingController _transferNameCtrl = TextEditingController(text: '');

  @override
  void dispose() {
    _cashCtrl.dispose();
    _transferNameCtrl.dispose();
    super.dispose();
  }

  double get _change {
    final change = _cashReceived - widget.total;
    return change < 0 ? 0 : change;
  }

  void _submit() {
    if (_method == 'cash') {
      if (_cashReceived < widget.total) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El efectivo recibido es menor al total.')),
        );
        return;
      }
      Navigator.of(context).pop(
        PosChargeResult(
          paymentMethod: 'cash',
          cashReceived: _cashReceived,
          change: _change,
          printTicket: _printTicket,
        ),
      );
      return;
    }

    if (_method == 'transfer') {
      Navigator.of(context).pop(
        PosChargeResult(
          paymentMethod: 'transfer',
          transferAccount: _selectedAccount,
          transferFromName: _transferNameCtrl.text.trim(),
          printTicket: _printTicket,
        ),
      );
      return;
    }

    // Tarjeta (demo funcional: registra venta como 'card')
    Navigator.of(context).pop(
      PosChargeResult(
        paymentMethod: 'card',
        printTicket: _printTicket,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    'Cobrar',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(context).pop(null),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Total grande
              Card(
                elevation: 0,
                color: theme.colorScheme.surfaceVariant.withOpacity(0.6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      const Icon(Icons.attach_money),
                      const SizedBox(width: 8),
                      Text(
                        'Total:',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      Text(
                        '\$${widget.total.toStringAsFixed(2)}',
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Métodos
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ChoiceChip(
                    label: const Text('Efectivo'),
                    selected: _method == 'cash',
                    onSelected: (_) => setState(() => _method = 'cash'),
                  ),
                  ChoiceChip(
                    label: const Text('Tarjeta'),
                    selected: _method == 'card',
                    onSelected: (_) => setState(() => _method = 'card'),
                  ),
                  ChoiceChip(
                    label: const Text('Transferencia'),
                    selected: _method == 'transfer',
                    onSelected: (_) => setState(() => _method = 'transfer'),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              if (_method == 'cash') ...[
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _cashCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Pagó con',
                          prefixText: '\$',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) {
                          final parsed = double.tryParse(v.replaceAll(',', '.')) ?? 0;
                          setState(() => _cashReceived = parsed);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Card(
                        elevation: 0,
                        color: theme.colorScheme.surfaceVariant.withOpacity(0.6),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Cambio',
                                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '\$${_change.toStringAsFixed(2)}',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: _cashReceived >= widget.total
                                      ? Colors.green.shade700
                                      : Colors.red.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              if (_method == 'card') ...[
                const SizedBox(height: 6),
                const Text(
                  'Tarjeta (demo): por ahora solo registra la venta como “tarjeta”.\n'
                  'Luego conectamos terminales reales según el proveedor.',
                  textAlign: TextAlign.left,
                ),
              ],

              if (_method == 'transfer') ...[
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _selectedAccount,
                  items: _accounts
                      .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedAccount = v ?? _selectedAccount),
                  decoration: const InputDecoration(
                    labelText: 'Cuenta destino',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _transferNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de quien transfiere',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],

              const SizedBox(height: 8),

              SwitchListTile(
                value: _printTicket,
                onChanged: (v) => setState(() => _printTicket = v),
                title: const Text('Imprimir ticket'),
              ),

              const SizedBox(height: 10),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.check),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Confirmar cobro', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
