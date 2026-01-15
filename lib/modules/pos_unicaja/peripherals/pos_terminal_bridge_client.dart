// lib/modules/pos_unicaja/peripherals/pos_terminal_bridge_client.dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class PosBridgeChargeResult {
  final String sessionId;
  final String status; // pending|approved|declined|error
  final String? message;

  PosBridgeChargeResult({required this.sessionId, required this.status, this.message});

  factory PosBridgeChargeResult.fromJson(Map<String, dynamic> j) {
    return PosBridgeChargeResult(
      sessionId: j['sessionId']?.toString() ?? '',
      status: j['status']?.toString() ?? 'error',
      message: j['message']?.toString(),
    );
  }
}

class PosBridgeStatusResult {
  final String status;
  final String? message;

  PosBridgeStatusResult({required this.status, this.message});

  factory PosBridgeStatusResult.fromJson(Map<String, dynamic> j) {
    return PosBridgeStatusResult(
      status: j['status']?.toString() ?? 'error',
      message: j['message']?.toString(),
    );
  }
}

class PosTerminalBridgeClient {
  final String baseUrl;
  const PosTerminalBridgeClient(this.baseUrl);

  Uri _u(String path) => Uri.parse('$baseUrl$path');

  Future<PosBridgeChargeResult> startCharge({
    required String provider, // mercadoPagoPointSmart|prosepago
    required double amount,
    required String reference,
  }) async {
    final res = await http.post(
      _u('/v1/terminal/charge'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'provider': provider,
        'amount': amount,
        'reference': reference,
      }),
    );

    if (res.statusCode >= 400) {
      throw Exception('Bridge error ${res.statusCode}: ${res.body}');
    }
    return PosBridgeChargeResult.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<PosBridgeStatusResult> getStatus(String sessionId) async {
    final res = await http.get(_u('/v1/terminal/status/$sessionId'));
    if (res.statusCode >= 400) {
      throw Exception('Bridge status error ${res.statusCode}: ${res.body}');
    }
    return PosBridgeStatusResult.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> cancel(String sessionId) async {
    await http.post(_u('/v1/terminal/cancel/$sessionId'));
  }

  Future<PosBridgeStatusResult> waitForFinalStatus(
    String sessionId, {
    Duration timeout = const Duration(minutes: 2),
    Duration interval = const Duration(milliseconds: 1200),
  }) async {
    final end = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(end)) {
      final st = await getStatus(sessionId);
      if (st.status == 'approved' || st.status == 'declined' || st.status == 'error') {
        return st;
      }
      await Future.delayed(interval);
    }

    return PosBridgeStatusResult(status: 'error', message: 'Timeout esperando respuesta de terminal.');
  }
}
