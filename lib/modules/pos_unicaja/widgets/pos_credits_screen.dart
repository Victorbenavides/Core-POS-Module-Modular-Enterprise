import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/pos_session.dart';
import '../customers/pos_customers_controller.dart';
import '../credits/pos_credits_controller.dart';
import '../credits/pos_credit_models.dart';
import 'package:framework_as/modules/pos_unicaja/controllers/pos_session.dart';


class PosCreditsScreen extends StatefulWidget {
  final String? customerId; // opcional (si entras desde un cliente)
  const PosCreditsScreen({super.key, this.customerId});

  @override
  State<PosCreditsScreen> createState() => _PosCreditsScreenState();
}

class _PosCreditsScreenState extends State<PosCreditsScreen> {
  final _searchCtrl = TextEditingController();
  String _q = '';

  @override
  void initState() {
    super.initState();
    PosCreditsController.instance.ensureLoaded();
    PosCustomersController.instance.ensureLoaded();
    _searchCtrl.addListener(() => setState(() => _q = _searchCtrl.text));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _money(double v) => '\$${v.toStringAsFixed(2)}';

  String _fmtTime(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  String _customerName(String id) {
    final c = PosCustomersController.instance.byId(id);
    return c?.name ?? 'Cliente $id';
  }

Future<void> _settle(PosCreditEntry e) async {
  final sessionCtrl = context.read<PosSessionController>();
  final cashier = sessionCtrl.currentCashier;

  if (cashier == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Primero inicia sesión.')),
    );
    return;
  }

  final canSettle = cashier.isAdmin || cashier.canManageCredits;
  if (!canSettle) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No tienes permiso para gestionar créditos.')),
    );
    return;
  }


    if (cashier == null || !sessionCtrl.hasOpenSession) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Abre caja y asegúrate de estar logueado para registrar el pago.')),
      );
      return;
    }

    String method = 'cash';

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Marcar como pagado'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Cliente: ${_customerName(e.customerId)}'),
            const SizedBox(height: 6),
            Text('Adeudo: ${_money(e.remainingAmount)}'),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: method,
              items: const [
                DropdownMenuItem(value: 'cash', child: Text('Efectivo')),
                DropdownMenuItem(value: 'card', child: Text('Tarjeta')),
                DropdownMenuItem(value: 'transfer', child: Text('Transferencia')),
              ],
              onChanged: (v) => method = v ?? method,
              decoration: const InputDecoration(
                labelText: 'Método de pago',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Esto afectará el corte de caja y el corte del día como “Cobro de crédito”.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirmar')),
        ],
      ),
    );

    if (ok != true) return;

    await PosCreditsController.instance.settleEntry(
      entryId: e.id,
      cashierId: cashier.id,
      method: method,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Crédito marcado como pagado.')),
    );
  }

  @override
  Widget build(BuildContext context) {

    final session = context.watch<PosSessionController>();
final cashier = session.currentCashier;

final canSeeCredits = cashier != null && (cashier.isAdmin || cashier.canManageCredits);

if (!canSeeCredits) {
  return Scaffold(
    appBar: AppBar(title: const Text('Créditos')),
    body: const Center(child: Text('No tienes permiso para ver Créditos.')),
  );
}

    final credits = PosCreditsController.instance;
    final customers = PosCustomersController.instance;

    return AnimatedBuilder(
      animation: Listenable.merge([credits, customers]),
      builder: (context, _) {
        final q = _q.trim().toLowerCase();

        final list = credits.openEntries(customerId: widget.customerId).where((e) {
          if (q.isEmpty) return true;
          final cname = _customerName(e.customerId).toLowerCase();
          final anyLine = e.lines.any((l) => l.name.toLowerCase().contains(q));
          return cname.contains(q) || anyLine;
        }).toList();

        final totalOpen = list.fold(0.0, (sum, e) => sum + e.remainingAmount);

        return Scaffold(
          appBar: AppBar(title: const Text('Créditos (fiados)')),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Buscar por cliente o producto...',
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
                child: Card(
                  child: ListTile(
                    title: const Text('Total pendiente'),
                    trailing: Text(
                      _money(totalOpen),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    subtitle: Text('Créditos abiertos: ${list.length}'),
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: list.isEmpty
                    ? const Center(child: Text('No hay créditos pendientes.'))
                    : ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (_, i) {
                          final e = list[i];
                          final cname = _customerName(e.customerId);

                          // resumen tipo: "Chetos x2, Coca x1 ..."
                          final summary = e.lines
                              .where((l) => l.qtyRemaining > 0.000001)
                              .take(3)
                              .map((l) => '${l.name} x${l.qtyRemaining.toStringAsFixed(2)}')
                              .join(', ');

                          return Card(
                            margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                            child: ExpansionTile(
                              title: Text(
                                cname,
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              subtitle: Text(
                                'Debe: ${_money(e.remainingAmount)}  •  ${_fmtTime(e.createdAt)}\n'
                                '${summary.isEmpty ? '—' : summary}',
                              ),
                              children: [
                                const Divider(height: 1),
                                ...e.lines.map((l) {
                                  final rem = l.qtyRemaining;
                                  final remSubtotal = l.remainingSubtotal;

                                  final promoTxt = (!l.hasPromo)
                                      ? ''
                                      : l.isBundle
                                          ? 'Promo: ${l.promoName} (bundle)'
                                          : 'Promo: ${l.promoName}';

                                  return ListTile(
                                    dense: true,
                                    title: Text(l.name),
                                    subtitle: Text(
                                      'Pendiente: ${rem.toStringAsFixed(3)} ${l.unit}  •  ${promoTxt.isEmpty ? 'Sin promo' : promoTxt}',
                                    ),
                                    trailing: Text(
                                      _money(remSubtotal),
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                  );
                                }).toList(),
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                                  child: Row(
                                    children: [
                                      Text('Venta: ${e.saleId}'),
                                      const Spacer(),
                                      TextButton.icon(
                                        onPressed: () => _settle(e),
                                        icon: const Icon(Icons.check_circle_outline),
                                        label: const Text('Marcar pagado'),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
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
