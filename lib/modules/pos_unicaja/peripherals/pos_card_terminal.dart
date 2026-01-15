// lib/modules/pos_unicaja/peripherals/pos_card_terminal.dart
import 'package:framework_as/modules/pos_unicaja/peripherals/pos_peripherals_store.dart';
import 'package:framework_as/modules/pos_unicaja/peripherals/pos_peripherals_settings.dart';
import 'package:framework_as/modules/pos_unicaja/peripherals/pos_terminal_bridge_client.dart';

class PosTerminalPayment {
  final bool approved;
  final String message;

  const PosTerminalPayment({required this.approved, required this.message});
}

class PosCardTerminal {
  static Future<PosTerminalPayment> charge({
    required double amount,
    required String reference,
  }) async {
    final s = await PosPeripheralsStore.load();

    if (s.cardTerminalProvider == PosCardTerminalProvider.none) {
      throw Exception('Terminal no configurada.');
    }

    final providerCode = s.cardTerminalProvider.name; // mercadoPagoPointSmart | prosepago
    final client = PosTerminalBridgeClient(s.terminalBridgeBaseUrl);

    final started = await client.startCharge(
      provider: providerCode,
      amount: amount,
      reference: reference,
    );

    final finalStatus = await client.waitForFinalStatus(started.sessionId);

    if (finalStatus.status == 'approved') {
      return PosTerminalPayment(approved: true, message: finalStatus.message ?? 'Pago aprobado.');
    }
    if (finalStatus.status == 'declined') {
      return PosTerminalPayment(approved: false, message: finalStatus.message ?? 'Pago rechazado.');
    }

    return PosTerminalPayment(approved: false, message: finalStatus.message ?? 'Error en cobro.');
  }
}
