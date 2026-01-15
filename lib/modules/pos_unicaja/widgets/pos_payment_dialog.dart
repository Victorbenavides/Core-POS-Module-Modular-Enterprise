import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:framework_as/modules/pos_unicaja/peripherals/pos_peripherals_store.dart';
import 'package:framework_as/modules/pos_unicaja/peripherals/pos_peripherals_settings.dart';
import 'package:framework_as/modules/pos_unicaja/peripherals/pos_card_terminal.dart';

import 'package:framework_as/modules/pos_unicaja/customers/pos_customers_controller.dart';
import 'package:framework_as/modules/pos_unicaja/customers/pos_customer.dart';

enum PosPaymentMethod {
  cash,
  card,
  transfer,
  credit, // ✅ NUEVO
}

class PosPaymentResult {
  final PosPaymentMethod method;
  final double paidAmount;
  final double change;
  final bool printTicket;
  final String? transferAccount;
  final String? transferName;

  // ✅ NUEVO: crédito
  final String? creditCustomerId;
  final String? creditCustomerName;

  const PosPaymentResult({
    required this.method,
    required this.paidAmount,
    required this.change,
    required this.printTicket,
    this.transferAccount,
    this.transferName,
    this.creditCustomerId,
    this.creditCustomerName,
  });

  String get methodCode {
    switch (method) {
      case PosPaymentMethod.cash:
        return 'cash';
      case PosPaymentMethod.card:
        return 'card';
      case PosPaymentMethod.transfer:
        return 'transfer';
      case PosPaymentMethod.credit:
        return 'credit';
    }
  }
}

class PosPaymentDialog extends StatefulWidget {
  const PosPaymentDialog({
    super.key,
    required this.total,
  });

  final double total;

  static Future<PosPaymentResult?> show(
    BuildContext context, {
    required double total,
  }) {
    return showDialog<PosPaymentResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PosPaymentDialog(total: total),
    );
  }

  @override
  State<PosPaymentDialog> createState() => _PosPaymentDialogState();
}

class _PosPaymentDialogState extends State<PosPaymentDialog> {
  PosPaymentMethod _method = PosPaymentMethod.cash;

  final TextEditingController _cashController = TextEditingController();
  final TextEditingController _transferAccountController = TextEditingController();
  final TextEditingController _transferNameController = TextEditingController();

  // ✅ crédito
  final TextEditingController _creditSearchCtrl = TextEditingController();
  String? _creditCustomerId;

  bool _printTicket = true;

  PosPeripheralsSettings? _peripherals;
  bool _loadingPeripherals = true;

  // Card flow
  bool _cardCharging = false;
  String _cardStatus = '';

  @override
  void initState() {
    super.initState();
    _cashController.text = widget.total.toStringAsFixed(2);
    _cashController.addListener(() => setState(() {}));
    _creditSearchCtrl.addListener(() => setState(() {}));

    PosCustomersController.instance.ensureLoaded();
    _loadPeripherals();
  }

  Future<void> _loadPeripherals() async {
    try {
      final s = await PosPeripheralsStore.load();
      if (!mounted) return;
      setState(() {
        _peripherals = s;
        _loadingPeripherals = false;

        if (_transferAccountController.text.trim().isEmpty) {
          _transferAccountController.text = s.defaultTransferAccount;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingPeripherals = false);
    }
  }

  @override
  void dispose() {
    _cashController.dispose();
    _transferAccountController.dispose();
    _transferNameController.dispose();
    _creditSearchCtrl.dispose();
    super.dispose();
  }

  double get _cashPaid {
    final txt = _cashController.text.replaceAll(',', '.');
    return double.tryParse(txt) ?? 0.0;
  }

  double get _change {
    final diff = _cashPaid - widget.total;
    if (diff <= 0) return 0.0;
    return diff;
  }

  bool get _cashIsEnough => _cashPaid + 0.009 >= widget.total;

  bool get _transferIsValid =>
      _transferAccountController.text.trim().isNotEmpty &&
      _transferNameController.text.trim().isNotEmpty;

  bool get _cardIsConfigured {
    if (_loadingPeripherals) return false;
    final provider = _peripherals?.cardTerminalProvider ?? PosCardTerminalProvider.none;
    return provider != PosCardTerminalProvider.none;
  }

  PosCustomer? get _selectedCustomer {
    final id = _creditCustomerId;
    if (id == null || id.isEmpty) return null;
    return PosCustomersController.instance.byId(id);
  }

  bool get _creditIsValid {
    final c = _selectedCustomer;
    if (c == null) return false;
    if (!c.enabled) return false;
    return (c.creditAvailable + 0.009) >= widget.total;
  }

  bool get _canPrimary {
    if (_cardCharging) return false;

    switch (_method) {
      case PosPaymentMethod.cash:
        return _cashIsEnough;
      case PosPaymentMethod.transfer:
        return _transferIsValid;
      case PosPaymentMethod.card:
        return _cardIsConfigured;
      case PosPaymentMethod.credit:
        return _creditIsValid;
    }
  }

  String get _primaryLabel {
    if (_method == PosPaymentMethod.card) {
      return _cardCharging ? 'Esperando...' : 'Iniciar cobro';
    }
    return 'Cobrar';
  }

  Future<void> _onPrimaryPressed() async {
    switch (_method) {
      case PosPaymentMethod.cash:
        if (!_cashIsEnough) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('El efectivo recibido es menor al total a cobrar.')),
          );
          return;
        }
        Navigator.of(context).pop(
          PosPaymentResult(
            method: PosPaymentMethod.cash,
            paidAmount: _cashPaid,
            change: _change,
            printTicket: _printTicket,
          ),
        );
        return;

      case PosPaymentMethod.transfer:
        if (!_transferIsValid) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Completa la cuenta/banco destino y el nombre de quien transfiere.')),
          );
          return;
        }
        Navigator.of(context).pop(
          PosPaymentResult(
            method: PosPaymentMethod.transfer,
            paidAmount: widget.total,
            change: 0.0,
            printTicket: _printTicket,
            transferAccount: _transferAccountController.text.trim(),
            transferName: _transferNameController.text.trim(),
          ),
        );
        return;

      case PosPaymentMethod.card:
        if (!_cardIsConfigured) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No hay terminal integrada. Ve a Ajustes > Periféricos y configura Mercado Pago Point Smart o Prosepago.'),
            ),
          );
          return;
        }
        await _startCardCharge();
        return;

      case PosPaymentMethod.credit:
        if (!_creditIsValid) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Selecciona un cliente con crédito suficiente.')),
          );
          return;
        }
        final c = _selectedCustomer!;
        Navigator.of(context).pop(
          PosPaymentResult(
            method: PosPaymentMethod.credit,
            paidAmount: widget.total,
            change: 0.0,
            printTicket: _printTicket,
            creditCustomerId: c.id,
            creditCustomerName: c.name,
          ),
        );
        return;
    }
  }

  Future<void> _startCardCharge() async {
    setState(() {
      _cardCharging = true;
      _cardStatus = 'Iniciando cobro en terminal...';
    });

    try {
      final ref = 'sale_${DateTime.now().millisecondsSinceEpoch}';

      setState(() => _cardStatus = 'Esperando confirmación de la terminal...');
      final result = await PosCardTerminal.charge(
        amount: widget.total,
        reference: ref,
      );

      if (!mounted) return;

      if (!result.approved) {
        setState(() {
          _cardCharging = false;
          _cardStatus = '';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message)),
        );
        return;
      }

      final wantsTicket = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogCtx) => AlertDialog(
          title: const Text('Pago aprobado'),
          content: const Text('¿Quieres generar / imprimir ticket?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('No'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('Sí'),
            ),
          ],
        ),
      );

      if (!mounted) return;

      Navigator.of(context).pop(
        PosPaymentResult(
          method: PosPaymentMethod.card,
          paidAmount: widget.total,
          change: 0.0,
          printTicket: wantsTicket ?? true,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cardCharging = false;
        _cardStatus = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error terminal: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalText = widget.total.toStringAsFixed(2);

    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.f1): PayWithTicketIntent(),
        LogicalKeySet(LogicalKeyboardKey.f2): PayWithoutTicketIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          PayWithTicketIntent: CallbackAction<PayWithTicketIntent>(
            onInvoke: (intent) {
              if (_method == PosPaymentMethod.card) return null;
              if (!_canPrimary) return null;
              if (!_printTicket) setState(() => _printTicket = true);
              _onPrimaryPressed();
              return null;
            },
          ),
          PayWithoutTicketIntent: CallbackAction<PayWithoutTicketIntent>(
            onInvoke: (intent) {
              if (_method == PosPaymentMethod.card) return null;
              if (!_canPrimary) return null;
              if (_printTicket) setState(() => _printTicket = false);
              _onPrimaryPressed();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Cobrar venta',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Total a cobrar',
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\$ $totalText',
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    _buildMethodSelector(),
                    const SizedBox(height: 16),
                    _buildMethodFields(theme),
                    const SizedBox(height: 12),

                    if (_method != PosPaymentMethod.card)
                      SwitchListTile(
                        title: const Text('Imprimir ticket'),
                        value: _printTicket,
                        onChanged: (v) => setState(() => _printTicket = v),
                      ),

                    if (_cardCharging || _cardStatus.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (_cardCharging)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(_cardStatus)),
                        ],
                      ),
                    ],

                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _cardCharging ? null : () => Navigator.of(context).pop(null),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: _canPrimary ? _onPrimaryPressed : null,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            child: Text(_primaryLabel, style: const TextStyle(fontSize: 16)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMethodSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _methodCard(PosPaymentMethod.cash, Icons.payments, 'Efectivo'),
        _methodCard(PosPaymentMethod.card, Icons.credit_card, 'Tarjeta'),
        _methodCard(PosPaymentMethod.transfer, Icons.swap_horiz, 'Transferencia'),
        _methodCard(PosPaymentMethod.credit, Icons.account_balance_wallet_outlined, 'Crédito'),
      ],
    );
  }

  Widget _methodCard(PosPaymentMethod method, IconData icon, String label) {
    final isSelected = _method == method;
    return Expanded(
      child: GestureDetector(
        onTap: _cardCharging
            ? null
            : () {
                setState(() {
                  _method = method;
                  _cardStatus = '';
                });
              },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue.shade50 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Colors.blue : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 26, color: isSelected ? Colors.blue : Colors.grey[700]),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.blue : Colors.grey[800],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMethodFields(ThemeData theme) {
    switch (_method) {
      case PosPaymentMethod.cash:
        final falta = widget.total - _cashPaid;
        final hayFalta = falta > 0.01;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pago en efectivo', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _cashController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Pagó con',
                prefixText: '\$ ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            if (hayFalta)
              Text(
                'Faltan \$${falta.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              )
            else
              Row(
                children: [
                  const Text('Su cambio:', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Text(
                    '\$${_change.toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
          ],
        );

      case PosPaymentMethod.card:
        final provider = _peripherals?.cardTerminalProvider ?? PosCardTerminalProvider.none;
        final configured = !_loadingPeripherals && provider != PosCardTerminalProvider.none;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pago con tarjeta', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              configured
                  ? 'Pulsa "Iniciar cobro". El POS esperará la aprobación de la terminal.'
                  : 'No hay terminal integrada. Ve a Ajustes > Periféricos y configura Mercado Pago Point Smart o Prosepago.',
            ),
          ],
        );

      case PosPaymentMethod.transfer:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pago por transferencia', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _transferAccountController,
              decoration: const InputDecoration(
                labelText: 'Cuenta / banco destino',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _transferNameController,
              decoration: const InputDecoration(
                labelText: 'Nombre de quien transfiere',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text('Importe a transferir: \$${widget.total.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        );

      case PosPaymentMethod.credit:
        final c = _selectedCustomer;
        final q = _creditSearchCtrl.text.trim().toLowerCase();

        return AnimatedBuilder(
          animation: PosCustomersController.instance,
          builder: (context, _) {
            final all = PosCustomersController.instance.customers;
            final filtered = all.where((x) {
              if (!x.enabled) return false;
              if (q.isEmpty) return true;
              return x.name.toLowerCase().contains(q) ||
                  x.phone.toLowerCase().contains(q) ||
                  x.notes.toLowerCase().contains(q);
            }).toList()
              ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

            final enough = _creditIsValid;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pago con crédito (fiado)', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),

                TextField(
                  controller: _creditSearchCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Buscar cliente',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 10),

                if (c != null)
                  Card(
                    child: ListTile(
                      title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(
                        'Disponible: \$${c.creditAvailable.toStringAsFixed(2)}  •  Debe: \$${c.creditUsed.toStringAsFixed(2)}  •  Límite: \$${c.creditLimit.toStringAsFixed(2)}',
                      ),
                      trailing: Icon(enough ? Icons.check_circle : Icons.error_outline,
                          color: enough ? Colors.green : Colors.red),
                    ),
                  ),

                const SizedBox(height: 8),

                SizedBox(
                  height: 180,
                  child: Card(
                    child: filtered.isEmpty
                        ? const Center(child: Text('No hay clientes que coincidan.'))
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (_, i) {
                              final x = filtered[i];
                              final selected = x.id == _creditCustomerId;
                              final ok = (x.creditAvailable + 0.009) >= widget.total;

                              return ListTile(
                                selected: selected,
                                title: Text(x.name),
                                subtitle: Text('Disponible: \$${x.creditAvailable.toStringAsFixed(2)}'),
                                trailing: Icon(ok ? Icons.check : Icons.close, color: ok ? Colors.green : Colors.red),
                                onTap: () => setState(() => _creditCustomerId = x.id),
                              );
                            },
                          ),
                  ),
                ),

                const SizedBox(height: 8),
                if (!enough)
                  const Text(
                    '⚠️ El cliente seleccionado no tiene crédito suficiente para esta venta.',
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                  ),
              ],
            );
          },
        );
    }
  }
}

class PayWithTicketIntent extends Intent {
  const PayWithTicketIntent();
}

class PayWithoutTicketIntent extends Intent {
  const PayWithoutTicketIntent();
}
