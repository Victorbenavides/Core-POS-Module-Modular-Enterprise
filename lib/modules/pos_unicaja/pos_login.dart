// lib/modules/pos_unicaja/widgets/pos_login.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:framework_as/modules/pos_unicaja/controllers/pos_session.dart';
import 'package:framework_as/modules/pos_unicaja/controllers/pos_cashiers_controller.dart';
import 'package:framework_as/modules/pos_unicaja/models/cashier.dart';

class PosLoginScreen extends StatefulWidget {
  const PosLoginScreen({super.key});

  @override
  State<PosLoginScreen> createState() => _PosLoginScreenState();
}

class _PosLoginScreenState extends State<PosLoginScreen> {
  final _pinCtrl = TextEditingController();

  Cashier? _selectedCashier;
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
  }

  // ✅ Helper para limpiar notificaciones acumuladas
  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars(); // <--- ESTA ES LA CLAVE
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : null,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _doLogin() async {
    final cashiersCtrl = context.read<PosCashiersController>();
    final sessionCtrl = context.read<PosSessionController>();

    final cashier = _selectedCashier;
    final pin = _pinCtrl.text.trim();

    setState(() {
      _loading = true;
      _error = null;
    });

    if (cashier == null) {
      setState(() {
        _loading = false;
        _error = 'Selecciona un cajero';
      });
      _showSnack('Selecciona un cajero', isError: true);
      return;
    }

    if (pin.isEmpty || pin != cashier.pin) {
      setState(() {
        _loading = false;
        _error = 'PIN incorrecto';
      });
      _showSnack('PIN incorrecto', isError: true);
      return;
    }

    // Login correcto (SIN AWAIT, como en tu original)
    try {
      sessionCtrl.login(cashier);
      
      // ✅ Feedback de bienvenida
      if (mounted) {
        _showSnack('Bienvenido, ${cashier.name}');
      }
    } catch (e) {
      // Por si acaso login lanzara una excepción síncrona
      setState(() => _error = e.toString());
    }

    setState(() {
      _loading = false;
      _error = null;
      _pinCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cashiers = context.watch<PosCashiersController>().cashiers;

    // Aseguramos que siempre haya uno seleccionado si la lista no está vacía
    if (_selectedCashier == null && cashiers.isNotEmpty) {
      _selectedCashier = cashiers.first;
    }

    return Center(
      child: SizedBox(
        width: 360,
        child: Card(
          elevation: 4,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Iniciar sesión en caja",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                // Selector de cajero
                DropdownButtonFormField<Cashier>(
                  value: _selectedCashier,
                  decoration: const InputDecoration(
                    labelText: 'Cajero',
                    border: OutlineInputBorder(),
                  ),
                  items: cashiers
                      .map(
                        (c) => DropdownMenuItem<Cashier>(
                          value: c,
                          child: Text(c.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCashier = value;
                    });
                  },
                ),
                const SizedBox(height: 12),

                // PIN
                TextField(
                  controller: _pinCtrl,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "PIN",
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) {
                    if (!_loading) _doLogin();
                  },
                ),

                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],

                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _doLogin,
                    child: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text("Entrar a la caja"),
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