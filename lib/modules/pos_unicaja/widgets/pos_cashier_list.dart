// lib/modules/pos_unicaja/widgets/pos_cashier_list.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:framework_as/modules/pos_unicaja/controllers/pos_cashiers_controller.dart';
import 'package:framework_as/modules/pos_unicaja/models/cashier.dart';
import '../controllers/pos_session.dart';

class PosCashierListScreen extends StatelessWidget {
  const PosCashierListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<PosSessionController>();
    final me = session.currentCashier;

    final canManage = me != null && (me.isAdmin || me.canManageCashiers);
    if (!canManage) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cajeros')),
        body: const Center(
          child: Text('No tienes permiso para administrar Cajeros.'),
        ),
      );
    }

    final cashiersCtrl = context.watch<PosCashiersController>();
    final cashiers = cashiersCtrl.cashiers;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cajeros / permisos'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // ✅ Reutilizamos la misma instancia del controller
          final ctrl = context.read<PosCashiersController>();

          final created = await showDialog<Cashier>(
            context: context,
            barrierDismissible: false,
            builder: (_) => ChangeNotifierProvider.value(
              value: ctrl,
              child: const _CashierEditorDialog(),
            ),
          );

          if (created != null) {
            ctrl.upsert(created);
            // ✅ FIX: Limpiar notificaciones previas
            if (context.mounted) {
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cajero creado exitosamente.')),
              );
            }
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Nuevo cajero'),
      ),
      body: cashiers.isEmpty
          ? const Center(child: Text('No hay cajeros registrados.'))
          : ListView.builder(
              itemCount: cashiers.length,
              itemBuilder: (_, index) {
                final c = cashiers[index];
                return ListTile(
                  title: Text(c.name),
                  subtitle: Text(
                    'PIN: ${c.pin}  •  ${c.isAdmin ? "ADMIN" : "Cajero"}',
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'edit') {
                        final ctrl = context.read<PosCashiersController>();

                        final updated = await showDialog<Cashier>(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) => ChangeNotifierProvider.value(
                            value: ctrl,
                            child: _CashierEditorDialog(initial: c),
                          ),
                        );

                        if (updated != null) {
                          ctrl.upsert(updated);
                          // ✅ FIX: Limpiar notificaciones previas
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).clearSnackBars();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Cajero actualizado.')),
                            );
                          }
                        }
                      } else if (value == 'delete') {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Eliminar cajero'),
                            content: Text('¿Eliminar a "${c.name}"?'),
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
                          // ✅ si estás borrando a tu usuario actual, mejor impedirlo
                          if (session.currentCashier?.id == c.id) {
                            if (!context.mounted) return;
                            // ✅ FIX: Limpiar notificaciones previas
                            ScaffoldMessenger.of(context).clearSnackBars();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('No puedes eliminar el cajero activo.'),
                              ),
                            );
                            return;
                          }
                          await context.read<PosCashiersController>().remove(c.id);
                          // ✅ FIX: Feedback de eliminado
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).clearSnackBars();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Cajero eliminado.')),
                            );
                          }
                        }
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'edit',
                        child: Text('Editar cajero'),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Eliminar cajero'),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

// ======================================================
// ✅ DIALOG editor con TODOS los permisos
// ======================================================

class _CashierEditorDialog extends StatefulWidget {
  final Cashier? initial;
  const _CashierEditorDialog({this.initial});

  @override
  State<_CashierEditorDialog> createState() => _CashierEditorDialogState();
}

class _CashierEditorDialogState extends State<_CashierEditorDialog> {
  final _nameCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();

  bool _isAdmin = false;

  // legacy
  bool _canManageInventory = false;
  bool _canViewReports = false;
  bool _canCancelSales = false;

  // operación
  bool _canOpenCash = false;
  bool _canCloseCash = false;
  bool _canCharge = false;
  bool _canEditSale = false;

  // inventario
  bool _canViewInventory = false;
  bool _canEditInventory = false;
  bool _canAdjustStock = false;

  // promos
  bool _canManagePromotions = false;

  // clientes / créditos
  bool _canManageCustomers = false;
  bool _canUseCredits = false;
  bool _canManageCredits = false;

  // reportes
  bool _canDailyClose = false;
  bool _canSalesReport = false;
  bool _canSalesSummary = false;

  // administración
  bool _canManageCashiers = false;
  bool _canManagePeripherals = false;
  bool _canManagePrintTemplate = false;
  bool _canManageSettings = false;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    if (i != null) {
      _nameCtrl.text = i.name;
      _pinCtrl.text = i.pin;

      _isAdmin = i.isAdmin;

      // legacy
      _canManageInventory = i.canManageInventory;
      _canViewReports = i.canViewReports;
      _canCancelSales = i.canCancelSales;

      // operación
      _canOpenCash = i.canOpenCash;
      _canCloseCash = i.canCloseCash;
      _canCharge = i.canCharge;
      _canEditSale = i.canEditSale;

      // inventario
      _canViewInventory = i.canViewInventory;
      _canEditInventory = i.canEditInventory;
      _canAdjustStock = i.canAdjustStock;

      // promos
      _canManagePromotions = i.canManagePromotions;

      // clientes / créditos
      _canManageCustomers = i.canManageCustomers;
      _canUseCredits = i.canUseCredits;
      _canManageCredits = i.canManageCredits;

      // reportes
      _canDailyClose = i.canDailyClose;
      _canSalesReport = i.canSalesReport;
      _canSalesSummary = i.canSalesSummary;

      // administración
      _canManageCashiers = i.canManageCashiers;
      _canManagePeripherals = i.canManagePeripherals;
      _canManagePrintTemplate = i.canManagePrintTemplate;
      _canManageSettings = i.canManageSettings;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  void _setAll(bool v) {
    // legacy
    _canManageInventory = v;
    _canViewReports = v;
    _canCancelSales = v;

    // operación
    _canOpenCash = v;
    _canCloseCash = v;
    _canCharge = v;
    _canEditSale = v;

    // inventario
    _canViewInventory = v;
    _canEditInventory = v;
    _canAdjustStock = v;

    // promos
    _canManagePromotions = v;

    // clientes / créditos
    _canManageCustomers = v;
    _canUseCredits = v;
    _canManageCredits = v;

    // reportes
    _canDailyClose = v;
    _canSalesReport = v;
    _canSalesSummary = v;

    // administración
    _canManageCashiers = v;
    _canManagePeripherals = v;
    _canManagePrintTemplate = v;
    _canManageSettings = v;
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    final pin = _pinCtrl.text.trim();

    if (name.isEmpty) {
      // ✅ FIX: Limpiar notificaciones previas
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nombre requerido.')),
      );
      return;
    }
    if (pin.isEmpty) {
      // ✅ FIX: Limpiar notificaciones previas
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN requerido.')),
      );
      return;
    }

    final nowId = DateTime.now().millisecondsSinceEpoch.toString();
    final id = widget.initial?.id ?? nowId;

    // ✅ Si es admin, fuerza todo a true
    if (_isAdmin) {
      _setAll(true);
    }

    final c = Cashier(
      id: id,
      name: name,
      pin: pin,

      isAdmin: _isAdmin,

      // legacy
      canManageInventory: _canManageInventory,
      canViewReports: _canViewReports,
      canCancelSales: _canCancelSales,

      // operación
      canOpenCash: _canOpenCash,
      canCloseCash: _canCloseCash,
      canCharge: _canCharge,
      canEditSale: _canEditSale,

      // inventario
      canViewInventory: _canViewInventory,
      canEditInventory: _canEditInventory,
      canAdjustStock: _canAdjustStock,

      // promos
      canManagePromotions: _canManagePromotions,

      // clientes / créditos
      canManageCustomers: _canManageCustomers,
      canUseCredits: _canUseCredits,
      canManageCredits: _canManageCredits,

      // reportes
      canDailyClose: _canDailyClose,
      canSalesReport: _canSalesReport,
      canSalesSummary: _canSalesSummary,

      // administración
      canManageCashiers: _canManageCashiers,
      canManagePeripherals: _canManagePeripherals,
      canManagePrintTemplate: _canManagePrintTemplate,
      canManageSettings: _canManageSettings,
    );

    Navigator.pop(context, c);
  }

  Widget _sec(String title) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 6),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );

  Widget _sw(String label, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      dense: true,
      title: Text(label),
      value: value,
      onChanged: _isAdmin ? null : onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Nuevo cajero' : 'Editar cajero'),
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
                controller: _pinCtrl,
                decoration: const InputDecoration(
                  labelText: 'PIN',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),

              SwitchListTile(
                title: const Text('Es administrador'),
                subtitle: const Text('Si está activo, tendrá TODOS los permisos.'),
                value: _isAdmin,
                onChanged: (v) => setState(() => _isAdmin = v),
              ),

              _sec('Caja / Venta'),
              _sw('Abrir caja', _canOpenCash, (v) => setState(() => _canOpenCash = v)),
              _sw('Cerrar caja', _canCloseCash, (v) => setState(() => _canCloseCash = v)),
              _sw('Cobrar', _canCharge, (v) => setState(() => _canCharge = v)),
              _sw('Editar venta', _canEditSale, (v) => setState(() => _canEditSale = v)),
              _sw('Cancelar ventas', _canCancelSales, (v) => setState(() => _canCancelSales = v)),

              _sec('Inventario'),
              _sw('Ver inventario', _canViewInventory, (v) => setState(() => _canViewInventory = v)),
              _sw('Editar inventario', _canEditInventory, (v) => setState(() => _canEditInventory = v)),
              _sw('Ajustar stock', _canAdjustStock, (v) => setState(() => _canAdjustStock = v)),
              _sw('Legacy: Manage Inventory', _canManageInventory,
                  (v) => setState(() => _canManageInventory = v)),

              _sec('Promociones'),
              _sw('Administrar promociones', _canManagePromotions,
                  (v) => setState(() => _canManagePromotions = v)),

              _sec('Clientes / Créditos'),
              _sw('Administrar clientes', _canManageCustomers,
                  (v) => setState(() => _canManageCustomers = v)),
              _sw('Usar créditos (fiado en cobro)', _canUseCredits,
                  (v) => setState(() => _canUseCredits = v)),
              _sw('Administrar créditos (pagos/deuda)', _canManageCredits,
                  (v) => setState(() => _canManageCredits = v)),

              _sec('Reportes'),
              _sw('Ver reportes (legacy)', _canViewReports,
                  (v) => setState(() => _canViewReports = v)),
              _sw('Corte diario', _canDailyClose, (v) => setState(() => _canDailyClose = v)),
              _sw('Reporte de ventas', _canSalesReport, (v) => setState(() => _canSalesReport = v)),
              _sw('Resumen de ventas', _canSalesSummary, (v) => setState(() => _canSalesSummary = v)),

              _sec('Administración'),
              _sw('Administrar cajeros', _canManageCashiers,
                  (v) => setState(() => _canManageCashiers = v)),
              _sw('Periféricos', _canManagePeripherals,
                  (v) => setState(() => _canManagePeripherals = v)),
              _sw('Plantilla de impresión', _canManagePrintTemplate,
                  (v) => setState(() => _canManagePrintTemplate = v)),
              _sw('Ajustes', _canManageSettings, (v) => setState(() => _canManageSettings = v)),
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