// lib/modules/pos_unicaja/widgets/pos_customers_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:framework_as/modules/pos_unicaja/customers/pos_customer.dart';
import 'package:framework_as/modules/pos_unicaja/customers/pos_customers_controller.dart';
import 'package:framework_as/modules/pos_unicaja/widgets/pos_credits_screen.dart';

import '../controllers/pos_session.dart';
import 'package:framework_as/modules/pos_unicaja/pos_main.dart';


enum _CustomerFilter { all, enabled, disabled }

class PosCustomersScreen extends StatefulWidget {
  const PosCustomersScreen({super.key});

  @override
  State<PosCustomersScreen> createState() => _PosCustomersScreenState();
}

class _PosCustomersScreenState extends State<PosCustomersScreen> {
  final _searchCtrl = TextEditingController();
  String _q = '';
  _CustomerFilter _filter = _CustomerFilter.all;

  @override
  void initState() {
    super.initState();
    PosCustomersController.instance.ensureLoaded();
    _searchCtrl.addListener(() => setState(() => _q = _searchCtrl.text));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _createOrEdit({PosCustomer? initial}) async {
    final res = await showDialog<PosCustomer>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CustomerEditorDialog(initial: initial),
    );
    if (res == null) return;

    try {
      await PosCustomersController.instance.upsert(res);
      if (!mounted) return;
      // ✅ FIX: Anti-stacking
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cliente guardado.')),
      );
    } catch (e) {
      if (!mounted) return;
      // ✅ FIX: Anti-stacking
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  String _money(double v) => '\$${v.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final session = context.watch<PosSessionController>();
    final cashier = session.currentCashier;

    // ✅ Permisos
    final canCustomers = cashier != null && (cashier.isAdmin || cashier.canManageCustomers);
    final canCreditsAdmin = cashier != null && (cashier.isAdmin || cashier.canManageCredits || cashier.canUseCredits);

    // ✅ Gate: si no tiene ninguno, no entra
    if (!canCustomers && !canCreditsAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Clientes')),
        body: const Center(
          child: Text('No tienes permiso para ver Clientes/Créditos.'),
        ),
      );
    }

    final ctrl = PosCustomersController.instance;

    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, _) {
        final list = ctrl.customers;

        final q = _q.trim().toLowerCase();
        final filtered = list.where((c) {
          if (_filter == _CustomerFilter.enabled && !c.enabled) return false;
          if (_filter == _CustomerFilter.disabled && c.enabled) return false;

          if (q.isEmpty) return true;

          final inName = c.name.toLowerCase().contains(q);
          final inPhone = c.phone.toLowerCase().contains(q);
          final inNotes = c.notes.toLowerCase().contains(q);
          return inName || inPhone || inNotes;
        }).toList();

        return Scaffold(
          appBar: AppBar(title: const Text('Clientes')),

          // ✅ Solo si puede administrar clientes
          floatingActionButton: canCustomers
              ? FloatingActionButton.extended(
                  onPressed: () => _createOrEdit(),
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Nuevo cliente'),
                )
              : null,

          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Buscar cliente (nombre / teléfono / notas)...',
                    border: const OutlineInputBorder(),
                    suffixIcon: _q.trim().isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Limpiar',
                            icon: const Icon(Icons.clear),
                            onPressed: () => _searchCtrl.clear(),
                          ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Todos'),
                      selected: _filter == _CustomerFilter.all,
                      onSelected: (_) => setState(() => _filter = _CustomerFilter.all),
                    ),
                    ChoiceChip(
                      label: const Text('Activos'),
                      selected: _filter == _CustomerFilter.enabled,
                      onSelected: (_) => setState(() => _filter = _CustomerFilter.enabled),
                    ),
                    ChoiceChip(
                      label: const Text('Inactivos'),
                      selected: _filter == _CustomerFilter.disabled,
                      onSelected: (_) => setState(() => _filter = _CustomerFilter.disabled),
                    ),
                    const SizedBox(width: 8),
                    Text('Total: ${list.length}'),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text('No hay clientes.'))
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final c = filtered[i];
                          final avail = c.creditAvailable;

                          return Card(
                            margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                            child: ListTile(
                              title: Text(
                                c.name,
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (c.phone.trim().isNotEmpty) Text('Tel: ${c.phone}'),
                                    Text(
                                      'Crédito: ${_money(c.creditLimit)}  •  Debe: ${_money(c.creditUsed)}  •  Disponible: ${_money(avail)}',
                                    ),
                                    if (!c.enabled)
                                      const Text(
                                        'INACTIVO',
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                  ],
                                ),
                              ),
                              trailing: Wrap(
                                spacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  // ✅ Ver créditos solo si tiene permiso de créditos (admin)
                                  IconButton(
                                    tooltip: canCreditsAdmin
                                        ? 'Ver créditos'
                                        : 'No tienes permiso para ver créditos',
                                    icon: const Icon(Icons.account_balance_wallet_outlined),
                                    onPressed: !canCreditsAdmin
    ? null
    : () {
        posPushWithCore(
          context,
          PosCreditsScreen(customerId: c.id),
          routeName: kPosCreditsRouteName,
        );
      },

                                  ),

                                  // ✅ Activar/Desactivar solo si puede administrar clientes
                                  Switch(
                                    value: c.enabled,
                                    onChanged: !canCustomers
                                        ? null
                                        : (v) async {
                                            try {
                                              await ctrl.setEnabled(c.id, v);
                                            } catch (e) {
                                              if (!context.mounted) return;
                                              // ✅ FIX: Anti-stacking
                                              ScaffoldMessenger.of(context).clearSnackBars();
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text('$e')),
                                              );
                                            }
                                          },
                                  ),

                                  PopupMenuButton<String>(
                                    enabled: canCustomers,
                                    tooltip: canCustomers
                                        ? 'Opciones'
                                        : 'No tienes permiso para administrar clientes',
                                    onSelected: (value) async {
                                      if (value == 'edit') {
                                        await _createOrEdit(initial: c);
                                      } else if (value == 'delete') {
                                        final ok = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text('Eliminar cliente'),
                                            content: Text('¿Eliminar "${c.name}"?'),
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
                                          await ctrl.remove(c.id);
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

                              // ✅ Tap para editar solo si puede administrar
                              onTap: !canCustomers ? null : () => _createOrEdit(initial: c),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

class _CustomerEditorDialog extends StatefulWidget {
  final PosCustomer? initial;
  const _CustomerEditorDialog({this.initial});

  @override
  State<_CustomerEditorDialog> createState() => _CustomerEditorDialogState();
}

class _CustomerEditorDialogState extends State<_CustomerEditorDialog> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _limitCtrl = TextEditingController(text: '0');

  bool _enabled = true;

  double _parse(String s) => double.tryParse(s.replaceAll(',', '.').trim()) ?? 0.0;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    if (i != null) {
      _nameCtrl.text = i.name;
      _phoneCtrl.text = i.phone;
      _notesCtrl.text = i.notes;
      _limitCtrl.text = i.creditLimit.toStringAsFixed(2);
      _enabled = i.enabled;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _notesCtrl.dispose();
    _limitCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final notes = _notesCtrl.text.trim();
    final limit = _parse(_limitCtrl.text);

    final now = DateTime.now();
    final id = widget.initial?.id ?? DateTime.now().millisecondsSinceEpoch.toString();

    final currentDebt = widget.initial?.creditUsed ?? 0.0;

    final c = PosCustomer(
      id: id,
      name: name,
      phone: phone,
      notes: notes,
      creditLimit: limit,
      creditUsed: currentDebt,
      enabled: _enabled,
      createdAt: widget.initial?.createdAt ?? now,
      updatedAt: now,
    );

    Navigator.pop(context, c);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Nuevo cliente' : 'Editar cliente'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(
                  labelText: 'Teléfono (opcional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _limitCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Límite de crédito (fiado)',
                  prefixText: '\$ ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _notesCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notas (opcional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text('Cliente activo'),
                value: _enabled,
                onChanged: (v) => setState(() => _enabled = v),
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