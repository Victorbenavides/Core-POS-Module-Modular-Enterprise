// lib/core/auth/auth_service.dart
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:framework_as/local/framework_bootstrap_service.dart';
import 'package:framework_as/core/auth/local_auth_service.dart';
import 'package:framework_as/local/customer_local_paths.dart';

// (lo usas aquí)
import 'package:framework_as/core/licenses/license_status.dart';

class AuthResult {
  final String customer; // customerCode
  final List<String> modules;
  final String? defaultModule;

  const AuthResult({
    required this.customer,
    required this.modules,
    this.defaultModule,
  });

  Map<String, dynamic> toMap() => {
        "customer": customer,
        "modules": modules,
        "defaultModule": defaultModule,
      };

  factory AuthResult.fromMap(Map<String, dynamic> map) {
    return AuthResult(
      customer: (map["customer"] ?? "").toString(),
      modules: List<String>.from(map["modules"] ?? const []),
      defaultModule: map["defaultModule"] as String?,
    );
  }
}

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static const String _baseUrl =
    "https://legend-verticillastrate-tamatha.ngrok-free.dev";


  // storage keys
  static const String _keyAuthData = "auth_data";
  static const String _keyToken = "access_token";
  static const String _keyLastCustomer = "last_customer"; // ✅ NUEVO

  // ============================================================
  // LOGIN (ONLINE → BOOTSTRAP → OFFLINE)
  // ============================================================
  Future<AuthResult?> login(String username, String password) async {
    bool onlineSuccess = false;
    final u = username.trim();
    print("🧪 [AUTH] login start user=$u");

    // ---------------- ONLINE ----------------
    try {
      final res = await http
          .post(
            Uri.parse("$_baseUrl/auth/login"),
            headers: {
  "Content-Type": "application/json",
  "ngrok-skip-browser-warning": "true",
},

            body: jsonEncode({
              "username": u,
              "password": password,
            }),
          )
          .timeout(const Duration(seconds: 5));

      print("🧪 [AUTH] online status=${res.statusCode}");

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);

        final token = (data["accessToken"] ?? "").toString();
        final customerCode = (data["customerCode"] ?? "").toString().trim();

        if (token.isEmpty || customerCode.isEmpty) return null;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyToken, token);

        // Auth base (sin módulos aún) — pero ya guardamos customer para “last_customer”
        final base = AuthResult(
          customer: customerCode,
          modules: const [],
        );
        await saveAuthData(base);

        // Entitlements ONLINE
        final entitlements = await fetchEntitlementSnapshots();

        // Bootstrap local (usuarios + licencias)
        await FrameworkBootstrapService.instance.bootstrapAfterOnlineLogin(
          customerCode: customerCode,
          username: u,
          plainPassword: password,
          licenses: entitlements,
          role: 'admin',
        );

        final modules = entitlements.map((e) => e.module).toSet().toList();
        final def = modules.isNotEmpty ? modules.first : null;

        final result = AuthResult(
          customer: customerCode,
          modules: modules,
          defaultModule: def,
        );

        await saveAuthData(result);
        onlineSuccess = true;
        print("🧪 [AUTH] online OK customer=$customerCode");
        return result;
      }
    } catch (e) {
      print("🧪 [AUTH] online FAILED -> offline. error=$e");
    }

    // ---------------- OFFLINE ----------------
if (onlineSuccess) {
  return null; // ⛔ nunca caer a offline si el online funcionó
}

final offline = await _loginOfflineAnyCustomer(
  username: u,
  password: password,
);


    print("🧪 [AUTH] offline result is null? ${offline == null}");

    if (offline != null) {
      await saveAuthData(offline);
    }

    return offline;
  }

  // ============================================================
  // ACTIVAR LICENSE KEY (ONLINE)
  // ============================================================
  Future<bool> activateLicenseKey({required String key}) async {
    final token = await _getToken();
    if (token == null) return false;

    final res = await http.post(
      Uri.parse("$_baseUrl/licenses/activate"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({"key": key}),
    );

    if (res.statusCode != 200 && res.statusCode != 201) {
      return false;
    }

    // Refrescamos entitlements
    final entitlements = await fetchEntitlementSnapshots();
    final auth = await getAuthData();
    if (auth == null) return false;

    await FrameworkBootstrapService.instance.bootstrapAfterOnlineLogin(
      customerCode: auth.customer,
      username: '',
      plainPassword: '',
      licenses: entitlements,
    );

    final modules = entitlements.map((e) => e.module).toSet().toList();
    final def = modules.isNotEmpty ? modules.first : null;

    final updated = AuthResult(
      customer: auth.customer,
      modules: modules,
      defaultModule: def,
    );

    await saveAuthData(updated);
    return true;
  }

  // ============================================================
  // OFFLINE: LOGIN “SIN ELEGIR CUSTOMER”
  // - intenta con last_customer primero
  // - si falla, intenta con los demás customers
  // - ordena por “DB más reciente” para una mejor heurística
  // ============================================================
  Future<AuthResult?> _loginOfflineAnyCustomer({
    required String username,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final last = (prefs.getString(_keyLastCustomer) ?? "").trim();

    final candidates = await _listCustomersWithLocalDb();

    if (candidates.isEmpty) {
      print("⛔ [AUTH] offline blocked: no valid customers on disk");
      return null;
    }

    // ✅ orden “mejor posible”:
    // 1) last_customer primero (si existe)
    // 2) resto por DB modificada más reciente
    candidates.sort((a, b) => b.dbLastModified.compareTo(a.dbLastModified));

    final ordered = <_CustomerCandidate>[];
    if (last.isNotEmpty) {
      final idx = candidates.indexWhere((c) => c.code == last);
      if (idx != -1) {
        ordered.add(candidates[idx]);
        candidates.removeAt(idx);
      }
    }
    ordered.addAll(candidates);

    print("🧪 [AUTH] offline candidates=${ordered.map((e) => e.code).toList()}");

    for (final c in ordered) {
      try {
        print("🧪 [AUTH] offline trying customer='${c.code}'");
        final result = await LocalAuthService.instance.loginOffline(
          customerCode: c.code,
          username: username,
          password: password,
        );

        if (result != null) {
          print("✅ [AUTH] offline OK customer='${c.code}'");
          return result;
        }
      } catch (e) {
        // si una DB está dañada, no tumbes el login: solo sigue
        print("⚠️ [AUTH] offline failed for customer='${c.code}': $e");
      }
    }

    print("⛔ [AUTH] offline: no match for user='$username' in any customer");
    return null;
  }

  // ============================================================
  // LISTAR customers que tienen framework.db
  // ============================================================
  Future<List<_CustomerCandidate>> _listCustomersWithLocalDb() async {
    final baseDir = await CustomerLocalPaths.instance.baseCustomersDir();

    if (!await baseDir.exists()) {
      print("⛔ [AUTH] customers dir does not exist: ${baseDir.path}");
      return const [];
    }

    final dirs = baseDir.listSync().whereType<Directory>().toList();

    final out = <_CustomerCandidate>[];
    for (final dir in dirs) {
      final code = dir.path.split(Platform.pathSeparator).last;

      final fwDb = File(
        '${dir.path}${Platform.pathSeparator}framework'
        '${Platform.pathSeparator}framework.db',
      );

      if (await fwDb.exists()) {
        DateTime lastMod;
        try {
          lastMod = await fwDb.lastModified();
        } catch (_) {
          lastMod = DateTime.fromMillisecondsSinceEpoch(0);
        }
        out.add(_CustomerCandidate(code: code, dbFile: fwDb, dbLastModified: lastMod));
      }
    }

    return out;
  }

  // ============================================================
  // ENTITLEMENTS
  // ============================================================
  Future<List<LicenseSnapshot>> fetchEntitlementSnapshots() async {
    final token = await _getToken();
    if (token == null) return const [];

    final res = await http.get(
      Uri.parse("$_baseUrl/licenses/entitlements"),
      headers: {"Authorization": "Bearer $token"},
    );

    if (res.statusCode != 200) return const [];

    final decoded = jsonDecode(res.body);
    if (decoded is! List) return const [];

    return decoded
        .whereType<Map>()
        .where((e) => e["module"] != null && e["expiresAt"] != null)
        .map(
          (e) => LicenseSnapshot(
            module: e["module"].toString(),
            expiresAt: DateTime.parse(e["expiresAt"].toString()),
          ),
        )
        .toList();
  }

  // ============================================================
  // HELPERS
  // ============================================================
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
  }

  // ============================================================
  // STORAGE
  // ============================================================
  Future<void> saveAuthData(AuthResult data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAuthData, jsonEncode(data.toMap()));

    // ✅ guarda el último customer usado (sirve para offline auto)
    await prefs.setString(_keyLastCustomer, data.customer);

    print("💾 [AUTH] saved customer='${data.customer}'");
  }

  Future<AuthResult?> getAuthData() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyAuthData);
    if (raw == null) return null;
    return AuthResult.fromMap(jsonDecode(raw));
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();

    // ✅ no borres TODO (te conviene conservar last_customer)
    await prefs.remove(_keyAuthData);
    await prefs.remove(_keyToken);

    // si tú quieres “logout total”, descomenta:
    // await prefs.remove(_keyLastCustomer);
  }

  Future<bool> isLogged() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_keyAuthData);
  }
}

class _CustomerCandidate {
  final String code;
  final File dbFile;
  final DateTime dbLastModified;

  _CustomerCandidate({
    required this.code,
    required this.dbFile,
    required this.dbLastModified,
  });
}