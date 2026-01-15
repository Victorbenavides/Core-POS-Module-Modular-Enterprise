// lib/modules/pos_unicaja/widgets/pos_open_cash.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:framework_as/modules/pos_unicaja/controllers/pos_session.dart';
import 'package:framework_as/modules/pos_unicaja/models/cashier.dart';

bool _canOpenCashLocal(Cashier c) => c.isAdmin || c.canOpenCash;

class PosOpenCashScreen extends StatefulWidget {
  const PosOpenCashScreen({super.key});

  @override
  State<PosOpenCashScreen> createState() => _PosOpenCashScreenState();
}

class _PosOpenCashScreenState extends State<PosOpenCashScreen> {
  final _amountCtrl = TextEditingController(text: "0");
  String? _error;
  bool _opening = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  void _open() {
    if (_opening) return;
    _opening = true;

    // ✅ Primero: permiso
    final ctrl = context.read<PosSessionController>();
    final cashier = ctrl.currentCashier;

    if (cashier == null) {
      _opening = false;
      return;
    }

    if (!_canOpenCashLocal(cashier)) {
      _opening = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No tienes permiso para abrir caja.')),
        );
      }
      return;
    }

    // ✅ Luego: validación de monto
    final raw = _amountCtrl.text.replaceAll(",", ".").trim();
    final value = double.tryParse(raw);

    if (value == null || value < 0) {
      _opening = false;
      setState(() => _error = "Ingresa un monto válido (>= 0).");
      return;
    }

    // ✅ Abrir sesión
    ctrl.openSession(value);

    _opening = false;
    if (mounted) {
      setState(() => _error = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<PosSessionController>();
    final cashier = ctrl.currentCashier;

    final canOpen = cashier != null && _canOpenCashLocal(cashier);

    return Center(
      child: SizedBox(
        width: 360,
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Apertura de caja",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: "Fondo inicial (efectivo)",
                    prefixText: "\$",
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: canOpen ? _open : null,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text("Abrir caja"),
                    ),
                  ),
                ),
                if (cashier != null && !canOpen) ...[
                  const SizedBox(height: 10),
                  const Text(
                    "No tienes permiso para abrir caja.",
                    style: TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
