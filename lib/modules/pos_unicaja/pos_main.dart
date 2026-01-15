import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';
import 'dart:io';

import 'package:framework_as/modules/pos_unicaja/controllers/pos_session.dart';
import 'package:framework_as/modules/pos_unicaja/controllers/pos_inventory_controller.dart';
import 'package:framework_as/modules/pos_unicaja/controllers/pos_cashiers_controller.dart';

import 'package:framework_as/modules/pos_unicaja/models/sale.dart';
import 'package:framework_as/modules/pos_unicaja/models/sale_item.dart';
import 'package:framework_as/modules/pos_unicaja/models/product.dart';

import 'pos_login.dart';
import 'pos_open_cash.dart';
import 'pos_close_cash.dart';
import 'pos_product_search.dart';

import 'package:framework_as/modules/pos_unicaja/widgets/pos_inventory_list.dart';
import 'package:framework_as/modules/pos_unicaja/widgets/pos_weighed_quantity_dialog.dart';
import 'package:framework_as/modules/pos_unicaja/widgets/pos_cashier_list.dart';
import 'package:framework_as/modules/pos_unicaja/widgets/pos_daily_close.dart';
import 'package:framework_as/modules/pos_unicaja/widgets/pos_sales_report.dart';
import 'package:framework_as/modules/pos_unicaja/widgets/pos_sales_summary.dart';
import 'package:framework_as/modules/pos_unicaja/widgets/pos_payment_dialog.dart';
import 'package:framework_as/modules/pos_unicaja/widgets/pos_receipt_preview.dart';
import 'package:framework_as/modules/pos_unicaja/widgets/pos_print_template_screen.dart';
import 'package:framework_as/core/branding/customer_branding_service.dart';


// ✅ Promociones
import 'package:framework_as/modules/pos_unicaja/widgets/pos_promotions_screen.dart';
import 'package:framework_as/modules/pos_unicaja/promotions/pos_promotions_controller.dart';
import 'package:framework_as/modules/pos_unicaja/promotions/pos_promotion_engine.dart';

// ✅ Periféricos
import 'package:framework_as/modules/pos_unicaja/peripherals/pos_peripherals_screen.dart';
import 'package:framework_as/modules/pos_unicaja/peripherals/pos_peripheral_actions.dart';

import 'package:framework_as/core/customers/customer_provider.dart';
import 'package:framework_as/core/customers/customer_asset_loader.dart';
import 'package:framework_as/core/i18n/app_strings.dart';
import 'package:framework_as/core/ui/settings_button.dart';



// ✅ Clientes / Créditos
import 'package:framework_as/modules/pos_unicaja/widgets/pos_customers_screen.dart';
import 'package:framework_as/modules/pos_unicaja/widgets/pos_credits_screen.dart';

import 'package:framework_as/modules/pos_unicaja/customers/pos_customers_controller.dart';
import 'package:framework_as/modules/pos_unicaja/customers/pos_customer.dart';
import 'package:framework_as/modules/pos_unicaja/credits/pos_credits_controller.dart';
import 'package:framework_as/modules/pos_unicaja/widgets/pos_quick_stock_adjust.dart';

import 'package:framework_as/modules/pos_unicaja/models/cashier.dart';
import 'package:framework_as/modules/pos_unicaja/promotions/pos_discount.dart';
import 'package:framework_as/modules/pos_unicaja/promotions/pos_discounts_controller.dart';
import 'package:framework_as/modules/pos_unicaja/controllers/pos_print_template_controller.dart';
import 'package:framework_as/modules/pos_unicaja/utils/pos_focus_guard.dart';
import 'package:framework_as/core/customers/customer_provider.dart';
import 'package:framework_as/modules/pos_unicaja/data/database/app_database.dart';




// ======================================================
// ROUTE NAMES (para jerarquía plana + F1 correcto)
// ======================================================
const String kPosModuleRouteName = 'module:pos';
const String kPosMainRouteName = kPosModuleRouteName;

const String kPosCustomersRouteName = '/pos_unicaja/customers';
const String kPosInventoryRouteName = '/pos_unicaja/inventory';
const String kPosCreditsRouteName = '/pos_unicaja/credits';
const String kPosPromosRouteName = '/pos_unicaja/promos';
const String kPosQuickStockRouteName = '/pos_unicaja/quick_stock';
const String kPosCloseCashRouteName = '/pos_unicaja/close_cash';
const String kPosDailyCloseRouteName = '/pos_unicaja/daily_close';
const String kPosSalesReportRouteName = '/pos_unicaja/sales_report';
const String kPosSalesSummaryRouteName = '/pos_unicaja/sales_summary';
const String kPosCashiersRouteName = '/pos_unicaja/cashiers';
const String kPosPeripheralsRouteName = '/pos_unicaja/peripherals';
const String kPosPrintTemplateRouteName = '/pos_unicaja/print_template';

const String kSettingsRouteName = '/settings';

// ======================================================
// PERMISSIONS HELPERS (legacy + nuevos)
// ======================================================
bool _isAdmin(Cashier c) => c.isAdmin;

bool _canEditSale(Cashier c) => _isAdmin(c) || c.canEditSale || c.canCancelSales; // legacy fallback
bool _canCharge(Cashier c) => _isAdmin(c) || c.canCharge;

bool _canOpenCash(Cashier c) => _isAdmin(c) || c.canOpenCash;
bool _canCloseCash(Cashier c) => _isAdmin(c) || c.canCloseCash;

bool _canViewInventory(Cashier c) =>
    _isAdmin(c) || c.canViewInventory || c.canManageInventory; // legacy fallback

bool _canEditInventory(Cashier c) =>
    _isAdmin(c) || c.canEditInventory || c.canAdjustStock || c.canManageInventory; // legacy fallback

bool _canAdjustStock(Cashier c) => _isAdmin(c) || c.canAdjustStock || c.canManageInventory;

bool _canManagePromos(Cashier c) => _isAdmin(c) || c.canManagePromotions || c.canManageInventory;

bool _canManageCustomers(Cashier c) => _isAdmin(c) || c.canManageCustomers || c.canManageInventory;

bool _canUseCredits(Cashier c) => _isAdmin(c) || c.canUseCredits || c.canManageCredits || c.canManageInventory;
bool _canManageCredits(Cashier c) => _isAdmin(c) || c.canManageCredits;

bool _canDailyClose(Cashier c) => _isAdmin(c) || c.canDailyClose || c.canViewReports; // legacy fallback
bool _canSalesReport(Cashier c) =>
    _isAdmin(c) || c.canSalesReport || c.canViewReports || c.canCancelSales; // legacy fallback
bool _canSalesSummary(Cashier c) => _isAdmin(c) || c.canSalesSummary || c.canViewReports; // legacy fallback

bool _canManageCashiers(Cashier c) => _isAdmin(c) || c.canManageCashiers;
bool _canManagePeripherals(Cashier c) => _isAdmin(c) || c.canManagePeripherals;
bool _canManagePrintTemplate(Cashier c) => _isAdmin(c) || c.canManagePrintTemplate;
bool _canManageSettings(Cashier c) => _isAdmin(c) || c.canManageSettings;



class PosMainScreen extends StatelessWidget {
  const PosMainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final customer = context.watch<CustomerProvider>().config;
    final language = customer.language;
    final t = (String key) => AppStrings.text(key, language);
    final ai = customer.ai;

    final session = context.watch<PosSessionController>();

    // ✅ Si no estamos en venta (login / abrir caja), limpiamos el draft (sin notificar)
    if (!session.isLoggedIn || !session.hasOpenSession) {
      _SaleDraft.instance.clear(silent: true);
    }

    Widget body;
    if (!session.isLoggedIn) {
      body = const PosLoginScreen();
    } else if (!session.hasOpenSession) {
      body = const PosOpenCashScreen();
    } else {
      body = _PosSaleLayout(t: t);
    }

    return _PosGlobalHotkeys(
      child: Scaffold(
        backgroundColor: customer.theme.background,
        appBar: AppBar(
  backgroundColor: customer.theme.primary,
  elevation: 4,
  centerTitle: true,

  // 🔹 más espacio para el logo
  leadingWidth: 82, // ⬅️ antes ~56, ahora un poco más grande

  // 🔹 LOGO A LA IZQUIERDA (un poco más grande)
  leading: ValueListenableBuilder<File?>(
    valueListenable: CustomerBrandingService.instance.logoFile,
    builder: (context, logo, _) {
      if (logo == null) return const SizedBox.shrink();

      return Padding(
        padding: const EdgeInsets.all(8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(
            customer.branding.roundedCorners ? 8 : 0,
          ),
          child: Image.file(
            logo,
            height: 80, // ⬅️ antes ~32 implícito, ahora un poco más grande
            fit: BoxFit.contain,
          ),
        ),
      );
    },
  ),

  // 🔹 nombre centrado real
  title: Text(
  customer.name.toUpperCase(),
  style: const TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.w600,
  ),
),


  actions: [
            Consumer<PosSessionController>(
              builder: (context, sessionCtrl, __) {
                if (!sessionCtrl.isLoggedIn) return const SizedBox.shrink();

                final cashier = sessionCtrl.currentCashier;
                if (cashier == null) return const SizedBox.shrink();

final canInventory = _canEditInventory(cashier);
final canReports = _canSalesReport(cashier) || _canSalesSummary(cashier) || _canDailyClose(cashier) || cashier.canViewReports;
final canViewInv = _canViewInventory(cashier);


                if (!canViewInv && !canInventory && !canReports) return const SizedBox.shrink();


                return IconButton(
                  tooltip: 'Inventario',
                  icon: const Icon(Icons.inventory_2_outlined),
                  onPressed: () {
                    posPushWithCore(
                      context,
                      PosInventoryListScreen(
                        canEditInventory: canInventory,
                        canViewInventoryReport: canReports,
                      ),
                      routeName: kPosInventoryRouteName,
                    );
                  },
                );
              },
            ),
            Consumer<PosSessionController>(
              builder: (context, sessionCtrl, __) {
                if (!sessionCtrl.isLoggedIn) return const SizedBox.shrink();
                final cashier = sessionCtrl.currentCashier;
if (cashier == null) return const SizedBox.shrink();

final ok = _canAdjustStock(cashier) || _canEditInventory(cashier);
if (!ok) return const SizedBox.shrink();


                return IconButton(
                  tooltip: 'Ajuste rápido de inventario',
                  icon: const Icon(Icons.playlist_add),
                  onPressed: () {
                    posPushWithCore(
                      context,
                      const PosQuickStockAdjustScreen(),
                      routeName: kPosQuickStockRouteName,
                    );
                  },
                );
              },
            ),
            Consumer<PosSessionController>(
              builder: (context, sessionCtrl, __) {
                final cashier = sessionCtrl.currentCashier;
                if (cashier == null) return const SizedBox.shrink();

                final canPromos = _canManagePromos(cashier);
                if (!canPromos) return const SizedBox.shrink();

                return IconButton(
                  tooltip: 'Promociones',
                  icon: const Icon(Icons.local_offer),
                  onPressed: () {
                    posPushWithCore(
                      context,
                      const PosPromotionsScreen(),
                      routeName: kPosPromosRouteName,
                    );
                  },
                );
              },
            ),
            Consumer<PosSessionController>(
              builder: (context, sessionCtrl, __) {
                final cashier = sessionCtrl.currentCashier;
                if (cashier == null) return const SizedBox.shrink();

                final canCustomers = _canManageCustomers(cashier);

                if (!canCustomers) return const SizedBox.shrink();

                return IconButton(
                  tooltip: 'Clientes',
                  icon: const Icon(Icons.people_alt_outlined),
                  onPressed: () {
                    posPushWithCore(
                      context,
                      const PosCustomersScreen(),
                      routeName: kPosCustomersRouteName,
                    );
                  },
                );
              },
            ),
            Consumer<PosSessionController>(
              builder: (context, sessionCtrl, __) {
                final cashier = sessionCtrl.currentCashier;
                if (cashier == null) return const SizedBox.shrink();

                final canCredits = _canUseCredits(cashier) || _canManageCredits(cashier);

                if (!canCredits) return const SizedBox.shrink();

                return IconButton(
                  tooltip: 'Créditos',
                  icon: const Icon(Icons.account_balance_wallet_outlined),
                  onPressed: () {
                    posPushWithCore(
                      context,
                      const PosCreditsScreen(),
                      routeName: kPosCreditsRouteName,
                    );
                  },
                );
              },
            ),
            Consumer<PosSessionController>(
              builder: (context, ctrl, __) {
                if (!ctrl.hasOpenSession) return const SizedBox.shrink();

final cashier = ctrl.currentCashier;
if (cashier == null) return const SizedBox.shrink();

final ok = _canCloseCash(cashier);
if (!ok) return const SizedBox.shrink();

                return IconButton(
                  tooltip: 'Cerrar caja',
                  icon: const Icon(Icons.point_of_sale),
                  onPressed: () {
                    posPushWithCore(
                      context,
                      PosCloseCashScreen(ctrl: ctrl),
                      routeName: kPosCloseCashRouteName,
                    );
                  },
                );
              },
            ),
            Consumer<PosSessionController>(
              builder: (context, sessionCtrl, __) {
                if (!sessionCtrl.isLoggedIn) return const SizedBox.shrink();

                final cashier = sessionCtrl.currentCashier;
                if (cashier == null) return const SizedBox.shrink();

                final canDailyClose = _canDailyClose(cashier);

                if (!canDailyClose) return const SizedBox.shrink();

                return IconButton(
                  tooltip: 'Corte del día',
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () {
                    posPushWithCore(
                      context,
                      const PosDailyCloseScreen(),
                      routeName: kPosDailyCloseRouteName,
                    );
                  },
                );
              },
            ),
            Consumer<PosSessionController>(
              builder: (context, sessionCtrl, __) {
                if (!sessionCtrl.isLoggedIn) return const SizedBox.shrink();

                final cashier = sessionCtrl.currentCashier;
                if (cashier == null) return const SizedBox.shrink();

                final canSalesReport = _canSalesReport(cashier);



                if (!canSalesReport) return const SizedBox.shrink();

                return IconButton(
                  tooltip: 'Reporte de ventas',
                  icon: const Icon(Icons.receipt_long),
                  onPressed: () {
                    posPushWithCore(
                      context,
                      const PosSalesReportScreen(),
                      routeName: kPosSalesReportRouteName,
                    );
                  },
                );
              },
            ),
            Consumer<PosSessionController>(
              builder: (context, sessionCtrl, __) {
                if (!sessionCtrl.isLoggedIn) return const SizedBox.shrink();

                final cashier = sessionCtrl.currentCashier;
                if (cashier == null) return const SizedBox.shrink();

                final canSummary = _canSalesSummary(cashier);

                if (!canSummary) return const SizedBox.shrink();

                return IconButton(
                  tooltip: 'Resumen de ventas',
                  icon: const Icon(Icons.bar_chart),
                  onPressed: () {
                    posPushWithCore(
                      context,
                      const PosSalesSummaryScreen(),
                      routeName: kPosSalesSummaryRouteName,
                    );
                  },
                );
              },
            ),
            Consumer<PosSessionController>(
              builder: (context, sessionCtrl, __) {
                if (!sessionCtrl.isLoggedIn) return const SizedBox.shrink();

                final cashier = sessionCtrl.currentCashier;
                if (cashier == null || !_canManageCashiers(cashier)) return const SizedBox.shrink();


                return IconButton(
                  tooltip: 'Cajeros / permisos',
                  icon: const Icon(Icons.group),
                  onPressed: () {
                    posPushWithCore(
                      context,
                      const PosCashierListScreen(),
                      routeName: kPosCashiersRouteName,
                    );
                  },
                );
              },
            ),
            Consumer<PosSessionController>(
              builder: (context, sessionCtrl, __) {
                final cashier = sessionCtrl.currentCashier;
                if (cashier == null || !_canManagePeripherals(cashier)) return const SizedBox.shrink();


                return IconButton(
                  tooltip: 'Periféricos POS',
                  icon: const Icon(Icons.usb),
                  onPressed: () {
                    posPushWithCore(
                      context,
                      const PosPeripheralsScreen(),
                      routeName: kPosPeripheralsRouteName,
                    );
                  },
                );
              },
            ),
            Consumer<PosSessionController>(
              builder: (context, sessionCtrl, __) {
                final cashier = sessionCtrl.currentCashier;
                if (cashier == null || !_canManagePrintTemplate(cashier)) return const SizedBox.shrink();


                return IconButton(
                  tooltip: 'Plantilla de impresión',
                  icon: const Icon(Icons.print),
                  onPressed: () {
                    posPushWithCore(
                      context,
                      const PosPrintTemplateScreen(),
                      routeName: kPosPrintTemplateRouteName,
                    );
                  },
                );
              },
            ),
            const SizedBox(width: 4),
            const SettingsButton(),
            const SizedBox(width: 8),
          ],
        ),
        body: body,
        ),
      );
    
  }
}

// =============================
// Layout base de ventas
// =============================
class _PosSaleLayout extends StatefulWidget {
  final String Function(String) t;
  const _PosSaleLayout({required this.t});

  @override
  State<_PosSaleLayout> createState() => _PosSaleLayoutState();

  
}

class _PosSaleLayoutState extends State<_PosSaleLayout> {

  Future<void> _cashMove({required bool isIn}) async {
  final session = context.read<PosSessionController>();
  final cashier = session.currentCashier;

  if (cashier == null || !session.hasOpenSession) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars(); // ✅ Limpia antes
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No hay caja abierta / cajero activo.')),
    );
    return;
  }

  // ✅ Permiso simple (ajústalo si tienes uno específico)
  final can = cashier.isAdmin || cashier.canOpenCash || cashier.canCloseCash;
  if (!can) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars(); // ✅ Limpia antes
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No tienes permiso para registrar movimientos de caja.')),
    );
    return;
  }

  final amountCtrl = TextEditingController();
  final noteCtrl = TextEditingController();

  // ✅ modal open: bloquea hotkeys/foco del main
  if (mounted) setState(() => _modalOpen = true);

  try {
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (ctx) => AlertDialog(
        title: Text(isIn ? 'Entrada de efectivo' : 'Salida de efectivo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Monto',
                prefixText: '\$ ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Nota (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              isIn
                  ? 'Ejemplo: “Cambio para caja”, “Depósito”, “Ajuste positivo”…'
                  : 'Ejemplo: “Pago proveedor”, “Gastos”, “Retiro”, “Ajuste negativo”…',
              style: TextStyle(color: Colors.grey[700]),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(isIn ? 'Registrar entrada' : 'Registrar salida'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final raw = amountCtrl.text.trim().replaceAll(',', '.');
    final amount = double.tryParse(raw) ?? 0.0;

    if (amount <= 0.0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars(); // ✅ Limpia antes
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Monto inválido.')),
      );
      return;
    }

    final note = noteCtrl.text.trim();

    // ✅ Esto lo implementas en el controller (abajo te dejo cómo)
    // Debe afectar la sesión actual y persistirse si aplica.
    if (isIn) {
      await session.registerCashIn(amount: amount, note: note);
    } else {
      await session.registerCashOut(amount: amount, note: note);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars(); // ✅ Limpia antes
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isIn
              ? 'Entrada registrada: \$${amount.toStringAsFixed(2)}'
              : 'Salida registrada: \$${amount.toStringAsFixed(2)}',
        ),
        duration: const Duration(seconds: 2), // ✅ Duración corta
      ),
    );
  } finally {
    if (mounted) setState(() => _modalOpen = false);
    _restoreFocus();
  }
}



  bool _modalOpen = false; // ✅ NUEVO: cuando hay dialog/route modal
  bool _pausedDialogOpen = false;
  bool _loadingOpen = false;
  bool _charging = false;
  bool _searching = false;

  // ✅ Draft persistente (NO depende del lifecycle del State)
  final _SaleDraft _draft = _SaleDraft.instance;

  // ✅ Focus node para hotkeys del main
  final FocusNode _saleFocusNode = FocusNode(debugLabel: 'pos-sale-hotkeys');

  // ✅ NUEVO: no “robes” foco cuando esta ruta NO es current
  void _syncSaleFocus() {
  if (_modalOpen) return; // ✅ NO pelear foco con dialogs

  final route = ModalRoute.of(context);
  final isCurrent = route != null && route.isCurrent;

  if (!isCurrent) {
    if (_saleFocusNode.hasFocus) _saleFocusNode.unfocus();
    return;
  }

  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    if (_modalOpen) return; // ✅
    final r = ModalRoute.of(context);
    final stillCurrent = r != null && r.isCurrent;
    if (!stillCurrent) return;
    if (!_saleFocusNode.hasFocus) _saleFocusNode.requestFocus();
  });
}



  void _restoreFocus() => _syncSaleFocus();

  Future<void> _pauseCurrentSale() async {
  if (_draft.isEmpty) return;

  // opcional: pedir nota rápida
  final note = await showDialog<String>(
    context: context,
    builder: (ctx) {
      final ctrl = TextEditingController();
      return AlertDialog(
        title: const Text('Pausar venta'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Nota (opcional)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Pausar')),
        ],
      );
    },
  );

  if (!mounted) return;
  if (note == null) return; // canceló

  final session = context.read<PosSessionController>();
  final cashier = session.currentCashier;
  if (cashier == null) return;

  final rawTotal = _total;
  final p = PausedSale(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
    createdAt: DateTime.now(),
    cashierId: cashier.id,
    items: _draft.snapshotFrozenPrices(), // congelamos el precio aplicado (normal/mayoreo)
    rawTotal: rawTotal,
    roundingEnabled: _draft.roundingEnabled,
    roundingStep: _draft.roundingStep,
    wholesaleProductIds: _draft.wholesaleIds(),
    note: note,
  );

  session.addPausedSale(p);

  _draft.clear(); // limpia venta actual + redondeo
  if (mounted) {
    ScaffoldMessenger.of(context).clearSnackBars(); // ✅ Limpia antes
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Venta pausada. (Ctrl+P)'), duration: Duration(seconds: 2)),
    );
  }
}


Future<void> _showPausedSalesDialog() async {
  debugPrint('A: entered _showPausedSalesDialog');

  final session = context.read<PosSessionController>();
  debugPrint('B: pausedSales length=${session.pausedSales.length}');

  if (session.pausedSales.isEmpty) {
    debugPrint('B2: empty, return');
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars(); // ✅ Limpia antes
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay ventas en pausa.')),
      );
    }
    return;
  }

  debugPrint('C: using local context (NOT root navigator)');

  // ✅ modal open: bloquea hotkeys/foco del main
  if (mounted) setState(() => _modalOpen = true);

  try {
    debugPrint('D: before unfocus');
    FocusManager.instance.primaryFocus?.unfocus();
    debugPrint('E: after unfocus');

    // ✅ deja terminar el frame/tecla actual
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;

    debugPrint('F: BEFORE showDialog');

    // ✅ snapshot inicial para evitar rebuild loops con Provider dentro del dialog
    List<PausedSale> list = session.pausedSales.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    await showDialog<void>(
      context: context,
      useRootNavigator: false, // ✅ CLAVE: NO root
      barrierDismissible: true,
      builder: (dlgCtx) {
        debugPrint('G: builder CALLED ✅');

        // ✅ roba el foco para el dialog (Windows friendly)
        return FocusTraversalGroup(
          child: StatefulBuilder(
            builder: (dlgCtx, setDlgState) {
              return AlertDialog(
                title: const Text('Ventas en pausa'),
                content: SizedBox(
                  width: 520,
                  height: 320,
                  child: list.isEmpty
                      ? const Center(child: Text('No hay ventas en pausa.'))
                      : ListView.separated(
                          itemCount: list.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final p = list[i];
                            final time =
                                '${p.createdAt.hour.toString().padLeft(2, '0')}:${p.createdAt.minute.toString().padLeft(2, '0')}';

                            return ListTile(
                              title: Text(
                                '[$time] ${p.items.length} item(s)  •  \$${p.rawTotal.toStringAsFixed(2)}',
                              ),
                              subtitle: p.note.trim().isEmpty ? null : Text(p.note),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Eliminar',
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () {
                                      // 🔸 borra en controller
                                      session.deletePausedSale(p.id);

                                      // 🔸 refresca la lista del dialog SIN depender de Consumer
                                      setDlgState(() {
                                        list = session.pausedSales.toList()
                                          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 4),
                                  ElevatedButton(
                                    onPressed: () {
                                      final popped = session.popPausedSale(p.id);
                                      if (popped == null) return;

                                      _draft.loadPaused(
                                        items: popped.items,
                                        wholesaleProductIds: popped.wholesaleProductIds,
                                        roundingEnabled: popped.roundingEnabled,
                                        roundingStep: popped.roundingStep,
                                      );

                                      Navigator.of(dlgCtx).pop();
                                    },
                                    child: const Text('Reanudar'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dlgCtx).pop(),
                    child: const Text('Cerrar'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );

    debugPrint('H: AFTER showDialog (closed)');
  } finally {
    if (mounted) setState(() => _modalOpen = false);
    _restoreFocus();
  }
}



  @override
void initState() {
  super.initState();
  PosPromotionsController.instance.ensureLoaded();
  PosDiscountsController.instance.ensureLoaded(); // ✅ AGREGAR
  PosCustomersController.instance.ensureLoaded();
  PosCreditsController.instance.ensureLoaded();

  WidgetsBinding.instance.addPostFrameCallback((_) => _syncSaleFocus());
}


  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncSaleFocus(); // ✅ al cambiar la ruta (cubierta por otra screen), suelta/pide foco
  }

  @override
  void dispose() {
    _saleFocusNode.dispose();
    super.dispose();
  }

  String? _hoveredProductId;

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  List<_AggregatedLine> get _aggregatedLines {
    final Map<String, _AggregatedLine> map = {};

    for (final item in _draft.items) {
      final id = item.product.id;
      if (!map.containsKey(id)) {
        map[id] = _AggregatedLine(product: item.product, quantity: 0.0);
      }
      map[id] = map[id]!.copyWith(quantity: map[id]!.quantity + item.quantity);
    }

    return map.values.toList();
  }

  double get _total {
    final promoCtrl = PosPromotionsController.instance;
    final now = DateTime.now();

    double sum = 0.0;
    for (final line in _aggregatedLines) {
      final discCtrl = PosDiscountsController.instance;

final pricing = PosPromotionEngine.bestLinePricing(
  promotions: promoCtrl.promotions,
  discounts: discCtrl.discounts,
  productId: line.product.id,
  department: line.product.department,
  qty: line.quantity,
  baseUnitPrice: _draft.unitPriceFor(line.product), // ✅ importante
  now: now,
);



      sum += pricing.subtotal;
    }
    return sum;
  }

  bool _canCancelSales() {
  final session = context.read<PosSessionController>();
  final cashier = session.currentCashier;
  if (cashier == null) return false;
  return _canEditSale(cashier);
}


  void _warnNoCancelPermission() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No tienes permiso para cancelar ventas.'), duration: Duration(seconds: 2)),
    );
  }

  bool _canEditCurrentSale() {
  final session = context.read<PosSessionController>();
  final cashier = session.currentCashier;
  if (cashier == null) return false;
  return _canEditSale(cashier);
}

void _warnNoEditPermission() {
  if (!mounted) return;
  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('No tienes permiso para modificar la venta.'), duration: Duration(seconds: 2)),
  );
}

void _applyWholesaleToHovered() {
  final pid = _hoveredProductId;
  if (pid == null) return;

  if (!_canEditCurrentSale()) {
    _warnNoEditPermission();
    return;
  }

  // buscamos el producto actual en la venta
  final line = _aggregatedLines.where((l) => l.product.id == pid).toList();
  if (line.isEmpty) return;

  final p = line.first.product;

  // si no tiene mayoreo, no se puede aplicar
  if (p.wholesalePrice <= 0) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('El producto "${p.name}" no tiene precio de mayoreo configurado.'), duration: const Duration(seconds: 2)),
    );
    return;
  }

  // ✅ TOGGLE
  final nowWholesale = _draft.isWholesale(pid);
  _draft.setWholesale(pid, !nowWholesale);

  if (mounted) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          !nowWholesale
              ? 'Mayoreo aplicado a "${p.name}". (Ctrl+M)'
              : 'Mayoreo quitado de "${p.name}". (Ctrl+M)',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}


void _applyWholesaleToAll() {
  if (!_canEditCurrentSale()) {
    _warnNoEditPermission();
    return;
  }

  if (_draft.isEmpty) return;

  // productos únicos presentes en la venta
  final lines = _aggregatedLines;

  // ✅ si TODOS los que tienen mayoreo están marcados -> quitamos a todos
  bool allWholesaleApplied = true;
  int canWholesaleCount = 0;

  for (final line in lines) {
    final p = line.product;
    if (p.wholesalePrice > 0) {
      canWholesaleCount++;
      if (!_draft.isWholesale(p.id)) {
        allWholesaleApplied = false;
      }
    }
  }

  if (canWholesaleCount == 0) {
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ningún producto tiene precio de mayoreo configurado.'), duration: Duration(seconds: 2)),
      );
    }
    return;
  }

  final bool apply = !allWholesaleApplied;

  int affected = 0;
  for (final line in lines) {
    final p = line.product;
    if (p.wholesalePrice > 0) {
      _draft.setWholesale(p.id, apply, notify: false);
      affected++;
    }
  }
  _draft.notify(); // un solo notify

  if (mounted) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          apply
              ? 'Mayoreo aplicado a $affected producto(s). (Ctrl+N)'
              : 'Mayoreo quitado de $affected producto(s). (Ctrl+N)',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}



  void _removeOneFromHovered() {
    final pid = _hoveredProductId;
    if (pid == null) return;

    if (!_canCancelSales()) {
      _warnNoCancelPermission();
      return;
    }

    _draft.removeOne(pid);
  }

  void _removeAllFromHovered() {
    final pid = _hoveredProductId;
    if (pid == null) return;

    if (!_canCancelSales()) {
      _warnNoCancelPermission();
      return;
    }

    _draft.removeAll(pid);
  }

  Future<void> _addOneToHovered() async {
    final pid = _hoveredProductId;
    if (pid == null) return;

    final line = _aggregatedLines.where((l) => l.product.id == pid).toList();
    if (line.isEmpty) return;

    final product = line.first.product;

    if (product.isWeighed) {
      if (!mounted) return;
      final result = await showDialog<double>(
        context: context,
        builder: (_) => PosWeighedQuantityDialog(product: product),
      );
      if (!mounted) return;
      if (result == null || result <= 0) return;
      _tryAddProduct(product, qty: result, showFeedback: true);
      return;
    }

    _tryAddProduct(product, qty: 1.0, showFeedback: mounted);
  }

  // ==========================================================
  // LECTOR DE CÓDIGO DE BARRAS (Windows - scanner tipo teclado)
  // ==========================================================
  String _scanBuffer = '';
  DateTime _lastKeyAt = DateTime.fromMillisecondsSinceEpoch(0);

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isAltPressed ||
        HardwareKeyboard.instance.isMetaPressed) {
      return KeyEventResult.ignored;
    }

    if (event is KeyRepeatEvent) {
      return KeyEventResult.handled;
    }

    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // ✅ F10 solo existe aquí (main venta). El resto de pantallas lo consumen.
    if (event.logicalKey == LogicalKeyboardKey.f10) {
      _searchProduct();
      return KeyEventResult.handled;
    }

    final now = DateTime.now();
    final diff = now.difference(_lastKeyAt);
    _lastKeyAt = now;

    if (diff > const Duration(milliseconds: 250)) {
      _scanBuffer = '';
    }

    if (event.logicalKey == LogicalKeyboardKey.enter) {
      final code = _scanBuffer.trim();
      _scanBuffer = '';
      if (code.isNotEmpty) {
        _handleBarcodeScan(code);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    final ch = event.character;
    if (ch == null || ch.isEmpty) return KeyEventResult.ignored;

    if (_scanBuffer.isEmpty && (ch == '-' || ch == '+')) {
      return KeyEventResult.ignored;
    }

    final isValid = RegExp(r'^[0-9A-Za-z\-\_\.]+$').hasMatch(ch);
    if (!isValid) return KeyEventResult.ignored;

    _scanBuffer += ch;
    return KeyEventResult.handled;
  }

  Future<void> _handleBarcodeScan(String code) async {
    final inventory = context.read<PosInventoryController>();
    await inventory.ready; // ✅ asegura inventario listo


    Product? found;
    try {
      found = inventory.products.firstWhere(
        (p) => p.barcode.trim().toLowerCase() == code.toLowerCase(),
      );
    } catch (_) {
      found = null;
    }

    if (found == null) {
      if (!mounted) return;
      await _askRegisterProduct(code);
      return;
    }

    if (found.usesInventory && found.stock <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Producto sin existencias: "${found.name}".'), duration: const Duration(seconds: 2)),
        );
      }
      return;
    }

    double qty = 1.0;
    if (found.isWeighed) {
      if (!mounted) {
        _tryAddProduct(found, qty: 1.0, showFeedback: false);
        return;
      }
      final result = await showDialog<double>(
        context: context,
        builder: (_) => PosWeighedQuantityDialog(product: found!),
      );
      if (!mounted) return;
      if (result == null || result <= 0) return;
      qty = result;
    }

    _tryAddProduct(found, qty: qty, showFeedback: mounted);
  }

  Future<void> _askRegisterProduct(String barcode) async {
    final session = context.read<PosSessionController>();
    final cashier = session.currentCashier;
    final canCreate = cashier != null && (cashier.isAdmin || cashier.canManageInventory);

    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Producto no encontrado'),
        content: Text(
          'No existe un producto con el código:\n\n$barcode\n\n'
          '${canCreate ? '¿Quieres registrarlo?' : 'Pídele a un admin que lo registre.'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
          if (canCreate)
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();

                final inventory = context.read<PosInventoryController>();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChangeNotifierProvider.value(
                      value: inventory,
                      child: const PosInventoryListScreen(
                        canEditInventory: true,
                        canViewInventoryReport: true,
                      ),
                    ),
                  ),
                );

                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Registra el producto y asígnale el código: $barcode'), duration: const Duration(seconds: 3)),
                );
              },
              child: const Text('Registrar'),
            ),
        ],
      ),
    );
  }

  void _tryAddProduct(Product selected, {required double qty, required bool showFeedback}) {
    final alreadyInSale = _draft.qtyInSale(selected.id);
    final available = selected.stock;

    if (selected.usesInventory && alreadyInSale + qty > available) {
      if (showFeedback && mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Stock insuficiente de "${selected.name}". '
              'Disponible: ${available - alreadyInSale <= 0 ? 0 : (available - alreadyInSale).toStringAsFixed(2)} ${selected.unit}',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    _draft.add(selected, qty);
  }

void _showLoading() {
  if (!mounted || _loadingOpen) return;
  _loadingOpen = true;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );
}

void _hideLoading() {
  if (!mounted || !_loadingOpen) return;
  _loadingOpen = false;

  final nav = Navigator.of(context, rootNavigator: true);
  if (nav.canPop()) nav.pop();
}




Future<void> _searchProduct() async {
  if (_searching) return;
  _searching = true;

  try {
    final inventory = context.read<PosInventoryController>();

    // ✅ Loading blindado mientras termina la carga inicial del inventario
    _showLoading();
    await inventory.ready;
    _hideLoading();

    final products = inventory.products;

    if (products.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay productos en inventario.'), duration: Duration(seconds: 2)),
        );
      }
      return;
    }

    final Product? selected = await Navigator.of(context).push<Product?>(
      MaterialPageRoute(
        builder: (_) => PosProductSearchScreen(products: products),
      ),
    );

    if (selected == null) return;

    double qty = 1.0;

    if (selected.isWeighed) {
      if (!mounted) {
        _tryAddProduct(selected, qty: 1.0, showFeedback: false);
        return;
      }
      final result = await showDialog<double>(
        context: context,
        builder: (_) => PosWeighedQuantityDialog(product: selected),
      );
      if (!mounted) return;
      if (result == null || result <= 0) return;
      qty = result;
    }

    _tryAddProduct(selected, qty: qty, showFeedback: mounted);
  } finally {
    _hideLoading(); // ✅ por si hubo error / return temprano
    _searching = false;
  }

  _restoreFocus();
}


  void _undoLast() {
    final session = context.read<PosSessionController>();
    final cashier = session.currentCashier;
    final canCancelSales = cashier != null && _canEditSale(cashier);


    if (!canCancelSales) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No tienes permiso para cancelar ventas.'), duration: Duration(seconds: 2)),
        );
      }
      return;
    }

    if (_draft.isEmpty) return;

    _draft.removeLast();

    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Último producto eliminado (Ctrl+Z).'), duration: Duration(seconds: 2)),
      );
    }
  }

    Sale? _lastSale(PosSessionController s) {
    if (s.allSales.isEmpty) return null;
    // por si no está ordenado:
    final list = s.allSales.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list.first;
  }

  // ✅ FUNCIÓN DE REIMPRESIÓN (Con Promos y Anti-Spam)
  Future<void> _reprintSale(Sale sale) async {
    final customer = context.read<CustomerProvider>().config;
    final logoFile = CustomerBrandingService.instance.logoFile.value;
    
    // ✅ BUSCAMOS EL NOMBRE REAL
    String cashierName = sale.cashierId;
    try {
      final c = context.read<PosCashiersController>().findById(sale.cashierId);
      if (c != null) cashierName = c.name;
    } catch (_) {}

    try {
      final template = await PosPrintTemplateController.loadOnce();
      if (!mounted) return;

      final pm = sale.paymentMethod.toLowerCase();
      final PosPaymentMethod method = switch (pm) {
        'cash' => PosPaymentMethod.cash,
        'card' => PosPaymentMethod.card,
        'transfer' => PosPaymentMethod.transfer,
        'credit' => PosPaymentMethod.credit,
        _ => PosPaymentMethod.cash,
      };

      final payment = PosPaymentResult(
        method: method,
        paidAmount: sale.paidAmount,
        change: sale.change,
        creditCustomerId: sale.customerId.trim().isEmpty ? null : sale.customerId.trim(),
        creditCustomerName: sale.customerId.trim().isEmpty ? null : sale.customerId.trim(),
        printTicket: true,
      );

      // 3. Pasar datos explícitos al preview
      if (template.showPreviewOnPrint) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PosReceiptPreviewScreen(
              sale: sale, 
              payment: payment,
              customerName: customer.name,
              logoFile: logoFile,
              cashierNameOverride: cashierName,
            ),
          ),
        );
        _restoreFocus();
        return;
      }

      // Impresión directa
      Uint8List? logoBytes;
      if (template.showLogo && logoFile != null && await logoFile.exists()) {
        logoBytes = await logoFile.readAsBytes();
      }

      final pdfBytes = await PosReceiptPreviewScreen.buildPdf(
        customerName: customer.name,
        template: template,
        sale: sale,
        payment: payment,
        logoBytes: logoBytes,
        cashierDisplayName: cashierName,
      );

      await PosFocusGuard.suspend(() async {
        await PosPeripheralActions.printTicketAuto(
          customerName: customer.name,
          template: template,
          sale: sale,
          payment: payment,
          pdfBytes: pdfBytes,
          jobName: 'reprint_ticket_${sale.id}.pdf',
        );
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars(); // ✅
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ticket reenviado a imprimir.'), duration: Duration(seconds: 2)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars(); // ✅
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error reimprimiendo: $e'), duration: const Duration(seconds: 2)),
      );
    }
  }

  Future<void> _reprintLastTicket() async {
    final session = context.read<PosSessionController>();

    final sale = _lastSale(session);
    if (sale == null) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay ventas para reimprimir.'), duration: Duration(seconds: 2)),
      );
      return;
    }

    await _reprintSale(sale);
  }


  // ✅ FUNCIÓN DE COBRO (Con Promos y Anti-Spam)
  Future<void> _charge() async {
    if (_charging) return;
    if (_draft.isEmpty) return;

    _charging = true;

    final sessionCtrl = context.read<PosSessionController>();
    final inventory = context.read<PosInventoryController>();
    final cashier = sessionCtrl.currentCashier;

    // 1. Obtener datos SEGUROS
    final customerConfig = context.read<CustomerProvider>().config;
    final logoFile = CustomerBrandingService.instance.logoFile.value;

    // -------------------------------------------------------------------------
    // ✅ LÓGICA DE PROMOS (Conservada)
    // -------------------------------------------------------------------------
    final promoCtrl = PosPromotionsController.instance;
    final discCtrl = PosDiscountsController.instance;
    final now = DateTime.now();
    final aggregated = _aggregatedLines; 
    final List<SaleItem> finalSaleItems = [];

    for (final line in aggregated) {
      final pricing = PosPromotionEngine.bestLinePricing(
        promotions: promoCtrl.promotions,
        discounts: discCtrl.discounts,
        productId: line.product.id,
        department: line.product.department,
        qty: line.quantity,
        baseUnitPrice: _draft.unitPriceFor(line.product),
        now: now,
      );

      final effectiveUnitPrice = pricing.subtotal / line.quantity;
      String? promoLabel;
      if (pricing.promo != null) promoLabel = pricing.promo!.name;
      else if (pricing.discountRule != null) promoLabel = "Desc. ${pricing.discountPercent}%";

      finalSaleItems.add(SaleItem(
        product: line.product,
        quantity: line.quantity,
        finalUnitPrice: effectiveUnitPrice,
        promoName: promoLabel,
      ));
    }

    final rawTotal = finalSaleItems.fold(0.0, (sum, i) => sum + i.subtotal);
    final round = _draft.applyRounding(rawTotal);
    final total = round.total;
    final roundingAdj = round.adjustment;

    bool saleCommitted = false;

    try {
      if (cashier == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No hay cajero logueado.'), duration: Duration(seconds: 2)));
        }
        return;
      }

      if (!_canCharge(cashier)) {
        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No tienes permiso para cobrar.'), duration: Duration(seconds: 2)));
        }
        return;
      }

      if (mounted) setState(() => _modalOpen = true);
      FocusManager.instance.primaryFocus?.unfocus();
      await Future<void>.delayed(Duration.zero);

      final paymentResult = await PosFocusGuard.suspend(() async {
        return await PosPaymentDialog.show(context, total: total);
      });

      if (mounted) setState(() => _modalOpen = false);
      _restoreFocus();

      if (paymentResult == null) return;

      final bool isCredit = paymentResult.method == PosPaymentMethod.credit;
      String customerId = '';
      
      if (isCredit) {
        customerId = (paymentResult.creditCustomerId ?? '').trim();
        if (customerId.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona un cliente para cobrar con crédito.'), duration: Duration(seconds: 2)));
          }
          return;
        }
        final PosCustomer? c = PosCustomersController.instance.byId(customerId);
        if (c == null || !c.enabled) {
          if (mounted) {
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cliente inválido o deshabilitado.'), duration: Duration(seconds: 2)));
          }
          return;
        }
        if (c.creditAvailable + 0.009 < total) {
          if (mounted) {
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Crédito insuficiente. Disponible: \$${c.creditAvailable.toStringAsFixed(2)}'), duration: const Duration(seconds: 2)));
          }
          return;
        }
      }

      final sale = Sale(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        createdAt: DateTime.now(),
        cashierId: cashier.id,
        items: finalSaleItems, // ✅ Usamos la lista calculada con promos
        total: total,
        rawTotal: rawTotal,
        roundingAdjustment: roundingAdj,
        paymentMethod: paymentResult.methodCode,
        customerId: customerId,
        paidAmount: paymentResult.paidAmount,
        change: paymentResult.change,
      );

      sessionCtrl.registerSale(sale);

      if (isCredit) {
        await PosCreditsController.instance.createCreditFromSale(sale);
      }

      if (paymentResult.method == PosPaymentMethod.cash) {
        try { await PosPeripheralActions.openCashDrawerIfConfigured(); } catch (_) {
           if (mounted) {
             ScaffoldMessenger.of(context).clearSnackBars();
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error abriendo caja.'), duration: Duration(seconds: 2)));
           }
        }
      }

      for (final item in finalSaleItems) {
        inventory.discountStock(item.product.id, item.quantity);
      }

      saleCommitted = true;

      // 2. Ticket Blindado
      if (paymentResult.printTicket) {
        final template = await PosPrintTemplateController.loadOnce();
        if (!mounted) return;

        if (template.showPreviewOnPrint) {
          // ✅ Pasamos datos explícitos y el nombre REAL del cajero
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PosReceiptPreviewScreen(
                sale: sale,
                payment: paymentResult,
                customerName: customerConfig.name,
                logoFile: logoFile,
                cashierNameOverride: cashier.name, 
              ),
            ),
          );
          _restoreFocus();
        } else {
          try {
            Uint8List? logoBytes;
            if (template.showLogo && logoFile != null && await logoFile.exists()) {
              logoBytes = await logoFile.readAsBytes();
            }

            final pdfBytes = await PosReceiptPreviewScreen.buildPdf(
              customerName: customerConfig.name,
              template: template,
              sale: sale,
              payment: paymentResult,
              logoBytes: logoBytes,
              cashierDisplayName: cashier.name,
            );

            await PosFocusGuard.suspend(() async {
              await PosPeripheralActions.printTicketAuto(
                customerName: customerConfig.name,
                template: template,
                sale: sale,
                payment: paymentResult,
                pdfBytes: pdfBytes,
                jobName: 'ticket_${sale.id}.pdf',
              );
            });

            if (mounted) {
              ScaffoldMessenger.of(context).clearSnackBars(); // ✅
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ticket enviado a imprimir.'), duration: Duration(seconds: 2)));
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al imprimir: $e'), duration: const Duration(seconds: 2)));
            }
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars(); // ✅
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Venta registrada.'), duration: Duration(seconds: 2)));
        }
      }
    } finally {
      if (saleCommitted) _draft.clear();
      _charging = false;
    }
  }


  String _fmtQty(Product p, double v) {
    if (p.isWeighed) return v.toStringAsFixed(3);
    final nearInt = (v - v.roundToDouble()).abs() < 0.000001;
    return nearInt ? v.round().toString() : v.toStringAsFixed(3);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCurrent = ModalRoute.of(context)?.isCurrent ?? true;

    final session = context.watch<PosSessionController>();
    final cashier = session.currentCashier;
    final canCancelSales = cashier != null && (cashier.isAdmin || cashier.canCancelSales);

    final promoCtrl = PosPromotionsController.instance;

    // ✅ Rebuild cuando cambian promos O el draft de la venta
    final listenable = Listenable.merge([promoCtrl, _draft]);

    return AnimatedBuilder(
      animation: listenable,
      builder: (context, _) {
        final now = DateTime.now();
        final rawTotal = _total;
final round = _draft.applyRounding(rawTotal);
final totalToShow = round.total;
final adj = round.adjustment;


        return Shortcuts(
          shortcuts: (isCurrent && !_modalOpen)
              ? <LogicalKeySet, Intent>{

                LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyB): const ToggleRoundingIntent(),
                LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyP): const PauseSaleIntent(),
                LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyL): const ResumePausedSaleIntent(),

                
                  LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyZ): const UndoIntent(),
                  LogicalKeySet(LogicalKeyboardKey.f12): const ChargeIntent(),
                  LogicalKeySet(LogicalKeyboardKey.minus): const RemoveOneHoveredIntent(),
                  LogicalKeySet(LogicalKeyboardKey.numpadSubtract): const RemoveOneHoveredIntent(),
                  LogicalKeySet(LogicalKeyboardKey.delete): const RemoveAllHoveredIntent(),
                  LogicalKeySet(LogicalKeyboardKey.numpadAdd): const AddOneHoveredIntent(),
                  LogicalKeySet(LogicalKeyboardKey.shift, LogicalKeyboardKey.equal): const AddOneHoveredIntent(),

                  LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyM): const ApplyWholesaleHoveredIntent(),
                  LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyN): const ApplyWholesaleAllIntent(),

                }
              : const <LogicalKeySet, Intent>{},
          child: Actions(
            actions: (isCurrent && !_modalOpen)
                ? <Type, Action<Intent>>{

                  ToggleRoundingIntent: CallbackAction<ToggleRoundingIntent>(
  onInvoke: (_) {
    // redondeo a ENTERO
    _draft.toggleRounding(step: 1.0);

    if (mounted) {
      final st = _draft.roundingEnabled ? 'activado' : 'desactivado';
      ScaffoldMessenger.of(context).clearSnackBars(); // ✅
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Redondeo $st (Ctrl+B).'), duration: const Duration(seconds: 2)),
      );
    }
    return null;
  },
),

PauseSaleIntent: CallbackAction<PauseSaleIntent>(
  onInvoke: (_) {
    _pauseCurrentSale();
    return null;
  },
),

ResumePausedSaleIntent: CallbackAction<ResumePausedSaleIntent>(
  onInvoke: (_) async {
    debugPrint('⌨️ Ctrl+L pressed: mounted=$mounted pausedDialogOpen=$_pausedDialogOpen');
    if (!mounted) return null;
    if (_pausedDialogOpen) return null;

    _pausedDialogOpen = true;
    try {
      await _showPausedSalesDialog();
    } finally {
      _pausedDialogOpen = false;
      _restoreFocus();
    }
    return null;
  },
),



ApplyWholesaleHoveredIntent: CallbackAction<ApplyWholesaleHoveredIntent>(
  onInvoke: (_) {
    _applyWholesaleToHovered();
    return null;
  },
),
ApplyWholesaleAllIntent: CallbackAction<ApplyWholesaleAllIntent>(
  onInvoke: (_) {
    _applyWholesaleToAll();
    return null;
  },
),



                    UndoIntent: CallbackAction<UndoIntent>(onInvoke: (_) => _undoLast()),
                    ChargeIntent: CallbackAction<ChargeIntent>(
                      onInvoke: (_) {
                        _charge();
                        return null;
                      },
                    ),
                    RemoveOneHoveredIntent: CallbackAction<RemoveOneHoveredIntent>(
                      onInvoke: (_) {
                        _removeOneFromHovered();
                        return null;
                      },
                    ),
                    RemoveAllHoveredIntent: CallbackAction<RemoveAllHoveredIntent>(
                      onInvoke: (_) {
                        _removeAllFromHovered();
                        return null;
                      },
                    ),
                    AddOneHoveredIntent: CallbackAction<AddOneHoveredIntent>(
                      onInvoke: (_) {
                        _addOneToHovered();
                        return null;
                      },
                    ),
                  }
                : const <Type, Action<Intent>>{},
            child: Focus(
              focusNode: _saleFocusNode,

              // ✅ importante: no dejes autofocus “pegado” en background
              autofocus: false,
              canRequestFocus: isCurrent && !_modalOpen,

              onFocusChange: (hasFocus) {
  debugPrint('FOCUS CHANGE: hasFocus=$hasFocus modalOpen=$_modalOpen suspended=${PosFocusGuard.suspended.value}');
  if (hasFocus) return;
  if (_modalOpen) return;
  if (PosFocusGuard.suspended.value) return;

  WidgetsBinding.instance.addPostFrameCallback((_) {
    debugPrint('FOCUS postFrame: trying requestFocus, mounted=$mounted');
    if (!mounted) return;
    if (_modalOpen) return;
    final route = ModalRoute.of(context);
    final current = route != null && route.isCurrent;
    debugPrint('FOCUS postFrame: routeCurrent=$current');
    if (current && !PosFocusGuard.suspended.value) {
      _saleFocusNode.requestFocus();
      debugPrint('FOCUS postFrame: requestFocus DONE');
    }
  });
},




              onKeyEvent: (isCurrent && !_modalOpen) ? _onKeyEvent : null,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Venta actual',
                                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    tooltip: 'Buscar producto (F10)',
                                    icon: const Icon(Icons.search),
                                    onPressed: _searchProduct,
                                  ),
                                ],
                              ),
                              const Divider(),
                              Expanded(
                                child: _aggregatedLines.isEmpty
                                    ? Center(
                                        child: Text(
                                          'No hay productos en la venta.\nPulsa en buscar producto.',
                                          textAlign: TextAlign.center,
                                          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                                        ),
                                      )
                                    : ListView.builder(
                                        itemCount: _aggregatedLines.length,
                                        itemBuilder: (_, index) {
                                          final line = _aggregatedLines[index];
                                          final isHovered = _hoveredProductId == line.product.id;

                                          final discCtrl = PosDiscountsController.instance;
                                          

final pricing = PosPromotionEngine.bestLinePricing(
  promotions: promoCtrl.promotions,
  discounts: discCtrl.discounts,
  productId: line.product.id,
  department: line.product.department,
  qty: line.quantity,
  baseUnitPrice: _draft.unitPriceFor(line.product), // ✅ importante
  now: now,
);


                                         final hasPromo = pricing.promo != null;
final hasDiscount = pricing.discountAmount > 0.000001;
final hasBenefit = hasPromo || hasDiscount;

                                          final isWholesale = _draft.isWholesale(line.product.id);


                                          return MouseRegion(
                                            onEnter: (_) {
                                              if (!mounted) return;
                                              _safeSetState(() => _hoveredProductId = line.product.id);
                                            },
                                            onExit: (_) {
                                              if (!mounted) return;
                                              _safeSetState(() {
                                                if (_hoveredProductId == line.product.id) _hoveredProductId = null;
                                              });
                                            },
                                            child: ListTile(
                                              selected: isHovered,
                                              title: Text(line.product.name),
                                              subtitle: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [

                                                  if (isWholesale)
  const Text(
    'MAYOREO aplicado',
    style: TextStyle(fontWeight: FontWeight.w600),
  ),

                                                  Text(
                                                    'Cant: ${_fmtQty(line.product, line.quantity)}  •  Subtotal: \$${pricing.subtotal.toStringAsFixed(2)}',
                                                  ),
                                                  if (hasBenefit)
  Text(
    hasPromo
        ? (pricing.isBundle
            ? 'Promo: ${pricing.promo!.name} — '
                '${pricing.bundleGroups}x(${_fmtQty(line.product, pricing.bundleSize)} por \$${pricing.bundlePrice.toStringAsFixed(2)})'
                '${pricing.normalQty > 0 ? ' + ${_fmtQty(line.product, pricing.normalQty)} normal' : ''}'
            : 'Promo: ${pricing.promo!.name} — \$${pricing.promo!.promoUnitPrice.toStringAsFixed(2)} c/u')
        : 'Descuento aplicado: -\$${pricing.discountAmount.toStringAsFixed(2)}',
    style: const TextStyle(fontWeight: FontWeight.w600),
  ),

                                                ],
                                              ),
                                              trailing: IconButton(
                                                icon: const Icon(Icons.delete),
                                                tooltip: 'Quitar producto de la venta',
                                                onPressed: canCancelSales
                                                    ? () => _draft.removeAll(line.product.id)
                                                    : null,
                                              ),
                                              onLongPress: canCancelSales
                                                  ? () => _draft.removeAll(line.product.id)
                                                  : null,
                                            ),
                                          );
                                        },
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 260,
                      child: Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.max,
                            children: [

                              
                              Text(
                                'Total',
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text(
  '\$${totalToShow.toStringAsFixed(2)}',
  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
),
if (_draft.roundingEnabled) ...[
  const SizedBox(height: 6),
  Text(
    'Redondeo: ${adj >= 0 ? '+' : ''}\$${adj.toStringAsFixed(2)}  (Ctrl+B)',
    style: const TextStyle(fontWeight: FontWeight.w600),
  ),
  Text(
    'Original: \$${rawTotal.toStringAsFixed(2)}',
    style: TextStyle(color: Colors.grey[700]),
  ),
],

                              
                              const Spacer(),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _draft.isEmpty ? null : () => _charge(),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    child: Text('Cobrar', style: TextStyle(fontSize: 16)),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 12),
SizedBox(
  width: double.infinity,
  child: OutlinedButton.icon(
    onPressed: () => _reprintLastTicket(),
    icon: const Icon(Icons.print),
    label: const Padding(
      padding: EdgeInsets.symmetric(vertical: 10),
      child: Text('Reimprimir último ticket'),
    ),
  ),
),

const SizedBox(height: 12),

Row(
  children: [
    Expanded(
      child: OutlinedButton.icon(
        onPressed: () => _cashMove(isIn: true),
        icon: const Icon(Icons.add_circle_outline),
        label: const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Text('Entrada'),
        ),
      ),
    ),
    const SizedBox(width: 10),
    Expanded(
      child: OutlinedButton.icon(
        onPressed: () => _cashMove(isIn: false),
        icon: const Icon(Icons.remove_circle_outline),
        label: const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Text('Salida'),
        ),
      ),
    ),
  ],
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
      },
    );
  }
}

// ----- clases auxiliares -----

class _AggregatedLine {
  final Product product;
  final double quantity;

  _AggregatedLine({
    required this.product,
    required this.quantity,
  });

  _AggregatedLine copyWith({Product? product, double? quantity}) {
    return _AggregatedLine(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
    );
  }
}

class UndoIntent extends Intent {
  const UndoIntent();
}

class ChargeIntent extends Intent {
  const ChargeIntent();
}

class RemoveOneHoveredIntent extends Intent {
  const RemoveOneHoveredIntent();
}

class RemoveAllHoveredIntent extends Intent {
  const RemoveAllHoveredIntent();
}

class AddOneHoveredIntent extends Intent {
  const AddOneHoveredIntent();
}

class ApplyWholesaleHoveredIntent extends Intent {
  const ApplyWholesaleHoveredIntent();
}

class ApplyWholesaleAllIntent extends Intent {
  const ApplyWholesaleAllIntent();
}

class ToggleRoundingIntent extends Intent {
  const ToggleRoundingIntent();
}

class PauseSaleIntent extends Intent {
  const PauseSaleIntent();
}

class ResumePausedSaleIntent extends Intent {
  const ResumePausedSaleIntent();
}



// =============================
// HOTKEYS GLOBALES DE NAVEGACIÓN
// =============================

class _GoMainIntent extends Intent {
  const _GoMainIntent();
}

class _OpenCustomersIntent extends Intent {
  const _OpenCustomersIntent();
}

class _OpenInventoryIntent extends Intent {
  const _OpenInventoryIntent();
}

class _OpenCreditsIntent extends Intent {
  const _OpenCreditsIntent();
}

class _OpenPromosIntent extends Intent {
  const _OpenPromosIntent();
}

class _OpenQuickStockIntent extends Intent {
  const _OpenQuickStockIntent();
}

class _OpenCloseCashIntent extends Intent {
  const _OpenCloseCashIntent();
}

class _OpenDailyCloseIntent extends Intent {
  const _OpenDailyCloseIntent();
}

class _OpenSalesReportIntent extends Intent {
  const _OpenSalesReportIntent();
}

class _OpenSalesSummaryIntent extends Intent {
  const _OpenSalesSummaryIntent();
}

class _OpenCashiersIntent extends Intent {
  const _OpenCashiersIntent();
}

class _OpenPeripheralsIntent extends Intent {
  const _OpenPeripheralsIntent();
}

class _OpenPrintTemplateIntent extends Intent {
  const _OpenPrintTemplateIntent();
}

class _OpenSettingsIntent extends Intent {
  const _OpenSettingsIntent();
}

class _ConsumeF10Intent extends Intent {
  const _ConsumeF10Intent();
}


class _ConsumeF10Action extends Action<_ConsumeF10Intent> {
  @override
  Object? invoke(_ConsumeF10Intent intent) => null;

  @override
  bool consumesKey(_ConsumeF10Intent intent) => true;
}


// ======================================================
// Navegación PRO (jerarquía plana) + sin animación
// ======================================================

PageRoute _noAnimRoute(Widget child, {required String name}) {
  return PageRouteBuilder(
    settings: RouteSettings(name: name),
    pageBuilder: (_, __, ___) => child,
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
  );
}

void posPushWithCore(
  BuildContext context,
  Widget screen, {
  required String routeName,
}) {
  final nav = Navigator.of(context);

  // ✅ PRIMERO: si ya estás en esa ruta, NO toques el foco
  final currentName = ModalRoute.of(context)?.settings.name;
  if (currentName == routeName) return;

  // ✅ SOLO si vas a navegar: suelta el foco actual
  FocusManager.instance.primaryFocus?.unfocus();

  final session = context.read<PosSessionController>();
  final inventory = context.read<PosInventoryController>();
  final cashiers = context.read<PosCashiersController>();

  nav.popUntil((r) => r.settings.name == kPosModuleRouteName || r.isFirst);

  nav.push(
    _noAnimRoute(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: session),
          ChangeNotifierProvider.value(value: inventory),
          ChangeNotifierProvider.value(value: cashiers),
        ],
        child: _PosGlobalHotkeys(
          child: Focus(
            autofocus: true,
            child: screen,
          ),
        ),
      ),
      name: routeName,
    ),
  );
}

class _PosGlobalHotkeys extends StatelessWidget {
  final Widget child;
  const _PosGlobalHotkeys({required this.child});

  // ✅ HELPER "LIMPIAR MESA" (Stateless)
  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).clearSnackBars(); // 🧹
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

    @override
  Widget build(BuildContext context) {
    // ✅ Rebuild automático cuando se suspenden hotkeys (dialogs, impresión, etc.)
    return ValueListenableBuilder<bool>(
      valueListenable: PosFocusGuard.suspended,
      builder: (context, suspended, _) {
        final routeName = ModalRoute.of(context)?.settings.name;

        // ✅ Solo habilitar hotkeys si:
        // - esta ruta es current
        // - NO estamos suspendidos por un modal/guard
        final enabled = (ModalRoute.of(context)?.isCurrent ?? true) && !suspended;

        final session = context.read<PosSessionController>();

        // ✅ Solo permitimos F10 “real” en la venta (pantalla F1 con caja abierta)
        final isSaleMain =
            routeName == kPosModuleRouteName &&
            session.isLoggedIn &&
            session.hasOpenSession;

        bool loggedIn() => session.isLoggedIn && session.currentCashier != null;

        final shortcuts = enabled
            ? <LogicalKeySet, Intent>{
                LogicalKeySet(LogicalKeyboardKey.f1): const _GoMainIntent(),
                LogicalKeySet(LogicalKeyboardKey.f2): const _OpenCustomersIntent(),
                LogicalKeySet(LogicalKeyboardKey.f3): const _OpenInventoryIntent(),
                LogicalKeySet(LogicalKeyboardKey.f4): const _OpenCreditsIntent(),
                LogicalKeySet(LogicalKeyboardKey.f5): const _OpenPromosIntent(),
                LogicalKeySet(LogicalKeyboardKey.f6): const _OpenQuickStockIntent(),
                LogicalKeySet(LogicalKeyboardKey.f7): const _OpenCloseCashIntent(),
                LogicalKeySet(LogicalKeyboardKey.f8): const _OpenDailyCloseIntent(),
                LogicalKeySet(LogicalKeyboardKey.f9): const _OpenSalesReportIntent(),
                LogicalKeySet(LogicalKeyboardKey.f11): const _OpenSalesSummaryIntent(),
                LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyI): const _OpenCashiersIntent(),
                LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyU): const _OpenPeripheralsIntent(),
                LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyY): const _OpenPrintTemplateIntent(),
                LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyO): const _OpenSettingsIntent(),

                // ✅ F10 se “consume” en pantallas que NO son el main
                if (!isSaleMain) LogicalKeySet(LogicalKeyboardKey.f10): const _ConsumeF10Intent(),
              }
            : const <LogicalKeySet, Intent>{};

        final actions = enabled
            ? <Type, Action<Intent>>{
                _ConsumeF10Intent: _ConsumeF10Action(),

                _GoMainIntent: CallbackAction<_GoMainIntent>(
                  onInvoke: (_) {
                    Navigator.of(context).popUntil(
                      (r) => r.settings.name == kPosModuleRouteName || r.isFirst,
                    );
                    return null;
                  },
                ),

                _OpenCustomersIntent: CallbackAction<_OpenCustomersIntent>(
                  onInvoke: (_) {
                    if (!loggedIn()) {
                      _snack(context, 'Primero inicia sesión.');
                      return null;
                    }
                    final c = session.currentCashier!;
                    final ok = _canManageCustomers(c) || _canUseCredits(c) || _canManageCredits(c);
                    if (!ok) {
                      _snack(context, 'No tienes permiso para Clientes.');
                      return null;
                    }
                    posPushWithCore(context, const PosCustomersScreen(),
                        routeName: kPosCustomersRouteName);
                    return null;
                  },
                ),

                _OpenInventoryIntent: CallbackAction<_OpenInventoryIntent>(
                  onInvoke: (_) {
                    if (!loggedIn()) {
                      _snack(context, 'Primero inicia sesión.');
                      return null;
                    }
                    final c = session.currentCashier!;
                    final canInventory = _canEditInventory(c) || _canViewInventory(c);
                    final canReports = _canDailyClose(c) || _canSalesReport(c) || _canSalesSummary(c) || c.canViewReports;
                    if (!canInventory && !canReports) {
                      _snack(context, 'No tienes permiso para Inventario.');
                      return null;
                    }
                    posPushWithCore(
                      context,
                      PosInventoryListScreen(
                        canEditInventory: canInventory,
                        canViewInventoryReport: canReports,
                      ),
                      routeName: kPosInventoryRouteName,
                    );
                    return null;
                  },
                ),

                _OpenCreditsIntent: CallbackAction<_OpenCreditsIntent>(
                  onInvoke: (_) {
                    if (!loggedIn()) {
                      _snack(context, 'Primero inicia sesión.');
                      return null;
                    }
                    final c = session.currentCashier!;
                    final ok = _canUseCredits(c) || _canManageCredits(c);
                    if (!ok) {
                      _snack(context, 'No tienes permiso para Créditos.');
                      return null;
                    }
                    posPushWithCore(context, const PosCreditsScreen(),
                        routeName: kPosCreditsRouteName);
                    return null;
                  },
                ),

                _OpenPromosIntent: CallbackAction<_OpenPromosIntent>(
                  onInvoke: (_) {
                    if (!loggedIn()) {
                      _snack(context, 'Primero inicia sesión.');
                      return null;
                    }
                    final c = session.currentCashier!;
                    final ok = _canManagePromos(c);
                    if (!ok) {
                      _snack(context, 'No tienes permiso para Promociones.');
                      return null;
                    }
                    posPushWithCore(context, const PosPromotionsScreen(),
                        routeName: kPosPromosRouteName);
                    return null;
                  },
                ),

                _OpenQuickStockIntent: CallbackAction<_OpenQuickStockIntent>(
                  onInvoke: (_) {
                    if (!loggedIn()) {
                      _snack(context, 'Primero inicia sesión.');
                      return null;
                    }
                    posPushWithCore(context, const PosQuickStockAdjustScreen(),
                        routeName: kPosQuickStockRouteName);
                    return null;
                  },
                ),

                _OpenCloseCashIntent: CallbackAction<_OpenCloseCashIntent>(
                  onInvoke: (_) {
                    final cashier = session.currentCashier;
                    if (cashier == null || !_canCloseCash(cashier)) {
                      _snack(context, 'No tienes permiso para cerrar caja.');
                      return null;
                    }
                    if (!session.hasOpenSession) {
                      _snack(context, 'No hay caja abierta.');
                      return null;
                    }
                    posPushWithCore(context, PosCloseCashScreen(ctrl: session),
                        routeName: kPosCloseCashRouteName);
                    return null;
                  },
                ),

                _OpenDailyCloseIntent: CallbackAction<_OpenDailyCloseIntent>(
                  onInvoke: (_) {
                    if (!loggedIn()) {
                      _snack(context, 'Primero inicia sesión.');
                      return null;
                    }
                    final c = session.currentCashier!;
                    final ok = _canDailyClose(c);
                    if (!ok) {
                      _snack(context, 'No tienes permiso para Corte del día.');
                      return null;
                    }
                    posPushWithCore(context, const PosDailyCloseScreen(),
                        routeName: kPosDailyCloseRouteName);
                    return null;
                  },
                ),

                _OpenSalesReportIntent: CallbackAction<_OpenSalesReportIntent>(
                  onInvoke: (_) {
                    if (!loggedIn()) {
                      _snack(context, 'Primero inicia sesión.');
                      return null;
                    }
                    final c = session.currentCashier!;
                    final ok = _canSalesReport(c);
                    if (!ok) {
                      _snack(context, 'No tienes permiso para Reporte de ventas.');
                      return null;
                    }
                    posPushWithCore(context, const PosSalesReportScreen(),
                        routeName: kPosSalesReportRouteName);
                    return null;
                  },
                ),

                _OpenSalesSummaryIntent: CallbackAction<_OpenSalesSummaryIntent>(
                  onInvoke: (_) {
                    if (!loggedIn()) {
                      _snack(context, 'Primero inicia sesión.');
                      return null;
                    }
                    final c = session.currentCashier!;
                    final ok = _canSalesSummary(c);
                    if (!ok) {
                      _snack(context, 'No tienes permiso para Resumen de ventas.');
                      return null;
                    }
                    posPushWithCore(context, const PosSalesSummaryScreen(),
                        routeName: kPosSalesSummaryRouteName);
                    return null;
                  },
                ),

                _OpenCashiersIntent: CallbackAction<_OpenCashiersIntent>(
                  onInvoke: (_) {
                    if (!loggedIn()) {
                      _snack(context, 'Primero inicia sesión.');
                      return null;
                    }
                    final c = session.currentCashier!;
                    if (!_canManageCashiers(c)) {
                      _snack(context, 'Solo admin: Cajeros/Permisos.');
                      return null;
                    }
                    posPushWithCore(context, const PosCashierListScreen(),
                        routeName: kPosCashiersRouteName);
                    return null;
                  },
                ),

                _OpenPeripheralsIntent: CallbackAction<_OpenPeripheralsIntent>(
                  onInvoke: (_) {
                    if (!loggedIn()) {
                      _snack(context, 'Primero inicia sesión.');
                      return null;
                    }
                    final c = session.currentCashier!;
                    if (!_canManagePeripherals(c)) {
                      _snack(context, 'Solo admin: Periféricos POS.');
                      return null;
                    }
                    posPushWithCore(context, const PosPeripheralsScreen(),
                        routeName: kPosPeripheralsRouteName);
                    return null;
                  },
                ),

                _OpenPrintTemplateIntent: CallbackAction<_OpenPrintTemplateIntent>(
                  onInvoke: (_) {
                    if (!loggedIn()) {
                      _snack(context, 'Primero inicia sesión.');
                      return null;
                    }
                    final c = session.currentCashier!;
                    if (!_canManagePrintTemplate(c)) {
                      _snack(context, 'Solo admin: Plantilla de impresión.');
                      return null;
                    }
                    posPushWithCore(context, const PosPrintTemplateScreen(),
                        routeName: kPosPrintTemplateRouteName);
                    return null;
                  },
                ),

                _OpenSettingsIntent: CallbackAction<_OpenSettingsIntent>(
                  onInvoke: (_) {
                    if (loggedIn()) {
                      final c = session.currentCashier!;
                      if (!_canManageSettings(c)) {
                        _snack(context, 'No tienes permiso para Configuración.');
                        return null;
                      }
                    }

                    Navigator.of(context).popUntil(
                      (r) => r.settings.name == kPosModuleRouteName || r.isFirst,
                    );
                    try {
                      Navigator.of(context).pushNamed(kSettingsRouteName);
                    } catch (_) {
                      _snack(context, 'Settings: usa el botón ⚙️ (ruta /settings no configurada).');
                    }
                    return null;
                  },
                ),
              }
            : const <Type, Action<Intent>>{};

        return Shortcuts(
          shortcuts: shortcuts,
          child: Actions(
            actions: actions,
            child: child,
          ),
        );
      },
    );
  }

}

// ======================================================
// ✅ Draft persistente de la venta
// ======================================================
class _SaleDraft extends ChangeNotifier {
  _SaleDraft._();
  static final _SaleDraft instance = _SaleDraft._();

  final List<SaleItem> _items = [];

  bool _roundingEnabled = false;

  /// Por defecto redondeo a entero (1.00)
  double _roundingStep = 1.0;

    double _roundToStep(double value, double step) {
    if (step <= 0) return value;
    final rounded = (value / step).roundToDouble() * step;
    // evita basura tipo 12.999999
    return double.parse(rounded.toStringAsFixed(2));
  }

  /// retorna (totalCobrar, ajuste)
  ({double total, double adjustment}) applyRounding(double rawTotal) {
    if (!_roundingEnabled) {
      return (total: rawTotal, adjustment: 0.0);
    }
    final rounded = _roundToStep(rawTotal, _roundingStep);
    final adj = double.parse((rounded - rawTotal).toStringAsFixed(2));
    return (total: rounded, adjustment: adj);
  }

  void toggleRounding({double? step}) {
    _roundingEnabled = !_roundingEnabled;
    if (step != null && step > 0) _roundingStep = step;
    notifyListeners();
  }

  void clearRounding({bool notify = true}) {
    _roundingEnabled = false;
    // _roundingStep se mantiene
    if (notify) notifyListeners();
  }


  List<String> wholesaleIds() => _wholesale.entries.where((e) => e.value).map((e) => e.key).toList();

  void loadPaused({
    required List<SaleItem> items,
    required List<String> wholesaleProductIds,
    required bool roundingEnabled,
    required double roundingStep,
  }) {
    _items
      ..clear()
      ..addAll(items);

    _wholesale.clear();
    for (final id in wholesaleProductIds) {
      _wholesale[id] = true;
    }

    _roundingEnabled = roundingEnabled;
    _roundingStep = roundingStep;

    notifyListeners();
  }


  bool get roundingEnabled => _roundingEnabled;
  double get roundingStep => _roundingStep;


  // ✅ Marca de mayoreo por producto
  final Map<String, bool> _wholesale = {};

  List<SaleItem> get items => _items;
  bool get isEmpty => _items.isEmpty;

  bool isWholesale(String productId) => _wholesale[productId] == true;

  double unitPriceFor(Product p) {
    final useWholesale = isWholesale(p.id);
    if (useWholesale && p.wholesalePrice > 0) return p.wholesalePrice;
    return p.salePrice;
  }

  void setWholesale(String productId, bool value, {bool notify = true}) {
    if (value) {
      _wholesale[productId] = true;
    } else {
      _wholesale.remove(productId);
    }
    if (notify) notifyListeners();
  }

  void notify() => notifyListeners();

  double qtyInSale(String productId) {
    double sum = 0.0;
    for (final i in _items) {
      if (i.product.id == productId) sum += i.quantity;
    }
    return sum;
  }

  // ✅ Snapshot normal (si lo ocupas en otros lados)
  List<SaleItem> snapshot() => List<SaleItem>.from(_items);

  // ✅ Snapshot para guardar venta: congela precio base (normal/mayoreo)
  List<SaleItem> snapshotFrozenPrices() {
    return _items.map((it) {
      final p = it.product;
      final price = unitPriceFor(p);
      final frozenProduct = p.copyWith(salePrice: price);
      return SaleItem(product: frozenProduct, quantity: it.quantity);
    }).toList();
  }

  void add(Product product, double qty) {
    _items.add(SaleItem(product: product, quantity: qty));
    notifyListeners();
  }

  void removeLast() {
    if (_items.isEmpty) return;
    final removed = _items.removeLast();
    // si ya no quedan items de ese producto, limpia su flag
    final pid = removed.product.id;
    if (!_items.any((x) => x.product.id == pid)) {
      _wholesale.remove(pid);
    }
    notifyListeners();
  }

  void removeOne(String productId) {
    for (int i = _items.length - 1; i >= 0; i--) {
      if (_items[i].product.id == productId) {
        _items.removeAt(i);
        if (!_items.any((x) => x.product.id == productId)) {
          _wholesale.remove(productId);
        }
        notifyListeners();
        return;
      }
    }
  }

  void removeAll(String productId) {
    if (_items.isEmpty) return;
    _items.removeWhere((i) => i.product.id == productId);
    _wholesale.remove(productId);
    notifyListeners();
  }

    void clear({bool silent = false}) {
    if (_items.isEmpty) return;
    _items.clear();
    _wholesale.clear();
    _roundingEnabled = false;
    if (!silent) notifyListeners();
  }

}