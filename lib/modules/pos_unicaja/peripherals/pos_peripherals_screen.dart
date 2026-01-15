// lib/modules/pos_unicaja/peripherals/pos_peripherals_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';

import 'package:framework_as/modules/pos_unicaja/controllers/pos_session.dart';
import 'package:framework_as/modules/pos_unicaja/peripherals/pos_peripherals_store.dart';
import 'package:framework_as/modules/pos_unicaja/peripherals/pos_peripherals_settings.dart';
import 'package:framework_as/modules/pos_unicaja/peripherals/pos_peripheral_actions.dart';

class PosPeripheralsScreen extends StatefulWidget {
  const PosPeripheralsScreen({super.key});

  @override
  State<PosPeripheralsScreen> createState() => _PosPeripheralsScreenState();
}

class _PosPeripheralsScreenState extends State<PosPeripheralsScreen> {
  PosPeripheralsSettings _settings = PosPeripheralsSettings.defaults();

  List<Printer> _printers = [];
  bool _loadingPrinters = false;

  final _hostCtrl = TextEditingController();
  final _portCtrl = TextEditingController();
  final _transferAccountCtrl = TextEditingController();
  final _bridgeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _transferAccountCtrl.dispose();
    _bridgeCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final s = await PosPeripheralsStore.load();
    if (!mounted) return;

    setState(() {
      _settings = s;
      _hostCtrl.text = s.networkHost;
      _portCtrl.text = s.networkPort.toString();
      _transferAccountCtrl.text = s.defaultTransferAccount;
      _bridgeCtrl.text = s.terminalBridgeBaseUrl;
    });

    await _refreshPrinters();
  }

  Future<void> _refreshPrinters() async {
    if (!mounted) return;
    setState(() => _loadingPrinters = true);

    try {
      final list = await Printing.listPrinters();
      if (!mounted) return;
      setState(() => _printers = list);
    } finally {
      if (mounted) setState(() => _loadingPrinters = false);
    }
  }

  Future<void> _save() async {
    final port = int.tryParse(_portCtrl.text.trim()) ?? 9100;

    final updated = _settings.copyWith(
      networkHost: _hostCtrl.text.trim(),
      networkPort: port,
      defaultTransferAccount: _transferAccountCtrl.text.trim(),
      terminalBridgeBaseUrl: _bridgeCtrl.text.trim().isEmpty
          ? 'http://127.0.0.1:9191'
          : _bridgeCtrl.text.trim(),
      cardTerminalProvider: _settings.cardTerminalProvider,
    );

    await PosPeripheralsStore.save(updated);

    if (!mounted) return;
    // ✅ FIX: Anti-stacking
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Configuración de periféricos guardada.')),
    );
  }

  Future<void> _testPrint() async {
    try {
      await PosPeripheralActions.testPrint();
      if (!mounted) return;
      // ✅ FIX: Anti-stacking
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prueba enviada.')),
      );
    } catch (e) {
      if (!mounted) return;
      // ✅ FIX: Anti-stacking
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error en prueba: $e')),
      );
    }
  }

  Future<void> _testDrawer() async {
    try {
      await PosPeripheralActions.openCashDrawerTest();
      if (!mounted) return;
      // ✅ FIX: Anti-stacking
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comando de cajón enviado.')),
      );
    } catch (e) {
      if (!mounted) return;
      // ✅ FIX: Anti-stacking
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir cajón: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Permiso: periféricos
    final session = context.watch<PosSessionController>();
    final me = session.currentCashier;
    final canPeripherals = me != null && (me.isAdmin || me.canManagePeripherals);

    if (!canPeripherals) {
      return Scaffold(
        appBar: AppBar(title: const Text('Periféricos del POS')),
        body: const Center(
          child: Text('No tienes permiso para configurar Periféricos.'),
        ),
      );
    }

    final isWindows = _settings.printerMode == PosPrinterMode.windowsDriver;

    // ✅ value seguro para el dropdown de impresora
    final printerNames = _printers.map((p) => p.name).toSet();
    final selectedPrinterValue = (_settings.windowsPrinterName.isEmpty ||
            !printerNames.contains(_settings.windowsPrinterName))
        ? null
        : _settings.windowsPrinterName;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Periféricos del POS'),
        actions: [
          IconButton(
            tooltip: 'Refrescar impresoras',
            onPressed: _loadingPrinters ? null : _refreshPrinters,
            icon: _loadingPrinters
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Impresora de tickets',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<PosPrinterMode>(
            value: _settings.printerMode,
            decoration: const InputDecoration(
              labelText: 'Modo de impresión',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: PosPrinterMode.windowsDriver,
                child: Text('Windows (USB o red por driver)'),
              ),
              DropdownMenuItem(
                value: PosPrinterMode.networkEscPos,
                child: Text('Red (RAW ESC/POS)'),
              ),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() => _settings = _settings.copyWith(printerMode: v));
            },
          ),
          const SizedBox(height: 12),

          if (isWindows) ...[
            DropdownButtonFormField<String>(
              value: selectedPrinterValue,
              decoration: const InputDecoration(
                labelText: 'Impresora (Windows)',
                border: OutlineInputBorder(),
              ),
              items: _printers
                  .map((p) => DropdownMenuItem(value: p.name, child: Text(p.name)))
                  .toList(),
              onChanged: (v) {
                setState(() {
                  _settings = _settings.copyWith(windowsPrinterName: v ?? '');
                });
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Detectadas: ${_printers.length}',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tip: si tu impresora USB o de red ya está instalada en Windows, aparecerá aquí.',
              style: TextStyle(color: Colors.grey),
            ),
          ] else ...[
            TextField(
              controller: _hostCtrl,
              decoration: const InputDecoration(
                labelText: 'IP / Host de impresora (Red)',
                border: OutlineInputBorder(),
                hintText: 'Ej: 192.168.1.50',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _portCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Puerto',
                border: OutlineInputBorder(),
                hintText: '9100',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'RAW ESC/POS suele ser 9100 (depende del modelo).',
              style: TextStyle(color: Colors.grey),
            ),
          ],

          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Abrir cajón al cobrar en efectivo'),
            subtitle: const Text('Requiere IP/Red (ESC/POS RAW) hacia la impresora.'),
            value: _settings.openDrawerOnCash,
            onChanged: (v) => setState(
              () => _settings = _settings.copyWith(openDrawerOnCash: v),
            ),
          ),

          const SizedBox(height: 16),
          const Text(
            'Transferencia',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _transferAccountCtrl,
            decoration: const InputDecoration(
              labelText: 'Cuenta destino (default)',
              border: OutlineInputBorder(),
              hintText: 'Ej: BBVA 0123 4567 8901 2345',
            ),
          ),

          const SizedBox(height: 16),
          const Text(
            'Terminal bancaria',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),

          DropdownButtonFormField<PosCardTerminalProvider>(
            value: _settings.cardTerminalProvider,
            decoration: const InputDecoration(
              labelText: 'Proveedor / modo',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: PosCardTerminalProvider.none,
                child: Text('Sin integración'),
              ),
              DropdownMenuItem(
                value: PosCardTerminalProvider.mercadoPagoPointSmart,
                child: Text('Mercado Pago Point Smart'),
              ),
              DropdownMenuItem(
                value: PosCardTerminalProvider.prosepago,
                child: Text('Prosepago'),
              ),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() => _settings = _settings.copyWith(cardTerminalProvider: v));
            },
          ),

          const SizedBox(height: 12),
          TextField(
            controller: _bridgeCtrl,
            decoration: const InputDecoration(
              labelText: 'Bridge local (URL)',
              border: OutlineInputBorder(),
              hintText: 'http://127.0.0.1:9191',
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'El POS habla con el Bridge por HTTP local. El Bridge se encarga de hablar con la terminal/proveedor.',
            style: TextStyle(color: Colors.grey),
          ),

          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('Guardar'),
          ),

          const SizedBox(height: 16),
          const Text(
            'Pruebas',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _testPrint,
                  icon: const Icon(Icons.receipt_long),
                  label: const Text('Imprimir prueba'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _testDrawer,
                  icon: const Icon(Icons.point_of_sale),
                  label: const Text('Probar cajón'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}