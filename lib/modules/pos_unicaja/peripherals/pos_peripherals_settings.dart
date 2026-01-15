// lib/modules/pos_unicaja/peripherals/pos_peripherals_settings.dart

enum PosPrinterMode {
  windowsDriver,
  networkEscPos,
}

enum PosCardTerminalProvider {
  none, // Sin integración (confirmación manual o deshabilitado)
  mercadoPagoPointSmart,
  prosepago,
}

String _terminalToCode(PosCardTerminalProvider p) => p.name;

PosCardTerminalProvider _terminalFromCode(String? code) {
  switch (code) {
    case 'mercadoPagoPointSmart':
      return PosCardTerminalProvider.mercadoPagoPointSmart;
    case 'prosepago':
      return PosCardTerminalProvider.prosepago;
    default:
      return PosCardTerminalProvider.none;
  }
}

class PosPeripheralsSettings {
  final PosPrinterMode printerMode;

  // Windows printing (USB o red por driver)
  final String windowsPrinterName;

  // Network RAW ESC/POS (típico: 9100)
  final String networkHost;
  final int networkPort;

  // Caja registradora
  final bool openDrawerOnCash;

  // Transferencia
  final String defaultTransferAccount;

  // Terminal
  final PosCardTerminalProvider cardTerminalProvider;

  // Bridge local (Windows)
  final String terminalBridgeBaseUrl; // ej: http://127.0.0.1:9191

  const PosPeripheralsSettings({
    required this.printerMode,
    required this.windowsPrinterName,
    required this.networkHost,
    required this.networkPort,
    required this.openDrawerOnCash,
    required this.defaultTransferAccount,
    required this.cardTerminalProvider,
    required this.terminalBridgeBaseUrl,
  });

  factory PosPeripheralsSettings.defaults() => const PosPeripheralsSettings(
        printerMode: PosPrinterMode.windowsDriver,
        windowsPrinterName: '',
        networkHost: '',
        networkPort: 9100,
        openDrawerOnCash: true,
        defaultTransferAccount: '',
        cardTerminalProvider: PosCardTerminalProvider.none,
        terminalBridgeBaseUrl: 'http://127.0.0.1:9191',
      );

  PosPeripheralsSettings copyWith({
    PosPrinterMode? printerMode,
    String? windowsPrinterName,
    String? networkHost,
    int? networkPort,
    bool? openDrawerOnCash,
    String? defaultTransferAccount,
    PosCardTerminalProvider? cardTerminalProvider,
    String? terminalBridgeBaseUrl,
  }) {
    return PosPeripheralsSettings(
      printerMode: printerMode ?? this.printerMode,
      windowsPrinterName: windowsPrinterName ?? this.windowsPrinterName,
      networkHost: networkHost ?? this.networkHost,
      networkPort: networkPort ?? this.networkPort,
      openDrawerOnCash: openDrawerOnCash ?? this.openDrawerOnCash,
      defaultTransferAccount: defaultTransferAccount ?? this.defaultTransferAccount,
      cardTerminalProvider: cardTerminalProvider ?? this.cardTerminalProvider,
      terminalBridgeBaseUrl: terminalBridgeBaseUrl ?? this.terminalBridgeBaseUrl,
    );
  }

  factory PosPeripheralsSettings.fromJson(Map<String, dynamic> json) {
    final modeRaw = (json['printerMode'] ?? 'windows').toString();
    final mode = modeRaw == 'network'
        ? PosPrinterMode.networkEscPos
        : PosPrinterMode.windowsDriver;

    return PosPeripheralsSettings(
      printerMode: mode,
      windowsPrinterName: (json['windowsPrinterName'] ?? '').toString(),
      networkHost: (json['networkHost'] ?? '').toString(),
      networkPort: (json['networkPort'] ?? 9100) is int
          ? (json['networkPort'] ?? 9100) as int
          : int.tryParse((json['networkPort'] ?? '9100').toString()) ?? 9100,
      openDrawerOnCash: json['openDrawerOnCash'] ?? true,
      defaultTransferAccount: (json['defaultTransferAccount'] ?? '').toString(),
      cardTerminalProvider: _terminalFromCode(json['cardTerminalProvider']?.toString()),
      terminalBridgeBaseUrl: (json['terminalBridgeBaseUrl'] ?? 'http://127.0.0.1:9191').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'printerMode': printerMode == PosPrinterMode.networkEscPos ? 'network' : 'windows',
      'windowsPrinterName': windowsPrinterName,
      'networkHost': networkHost,
      'networkPort': networkPort,
      'openDrawerOnCash': openDrawerOnCash,
      'defaultTransferAccount': defaultTransferAccount,
      'cardTerminalProvider': _terminalToCode(cardTerminalProvider),
      'terminalBridgeBaseUrl': terminalBridgeBaseUrl,
    };
  }
}
