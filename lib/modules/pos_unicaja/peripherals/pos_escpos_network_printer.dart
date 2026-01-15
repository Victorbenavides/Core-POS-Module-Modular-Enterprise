// lib/modules/pos_unicaja/peripherals/pos_escpos_network_printer.dart
import 'dart:io';
import 'dart:typed_data';

class PosEscPosNetworkPrinter {
  static Future<void> send(
    String host,
    int port,
    Uint8List bytes,
  ) async {
    final socket = await Socket.connect(
      host,
      port,
      timeout: const Duration(seconds: 3),
    );

    socket.add(bytes);
    await socket.flush();
    await socket.close();
  }
}
