// lib/main.dart
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'core/auth/auth_service.dart';
import 'package:framework_as/core/customers/customer_loader.dart';
import 'core/customers/customer_provider.dart';
import 'core/i18n/translation_service.dart';
import 'core/module_registry.dart';
import 'core/ui/home_menu.dart';

import 'package:framework_as/core/customers/customer_config.dart';
import 'package:framework_as/core/branding/customer_branding_service.dart';
import 'package:framework_as/modules/pos_unicaja/data/database/app_database.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }


  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: CustomerProvider.instance),
        ChangeNotifierProvider.value(value: TranslationService.instance),
      ],
      child: const FrameworkRoot(),
    ),
  );
}

// ================== ROOT ==================

class FrameworkRoot extends StatefulWidget {
  const FrameworkRoot({super.key});

  @override
  State<FrameworkRoot> createState() => _FrameworkRootState();
}

class _FrameworkRootState extends State<FrameworkRoot> {
  AuthResult? session;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
  try {
    final auth = await AuthService().getAuthData();

    if (auth != null) {
      final config = await CustomerLoader.load(auth.customer);
      final merged = config.copyWith(enabledModules: auth.modules);

      CustomerProvider.instance.setConfig(merged, auth.customer);
      TranslationService.instance.setLanguage(merged.language);

      // 🔑 INIT LOGO / BRANDING AQUÍ (cuando auth existe)
      await CustomerBrandingService.instance.initForCustomer(auth.customer);
      await AppDatabase.initForCustomer(auth.customer);

      if (!mounted) return;
      setState(() {
        session = auth;
        loading = false;
      });
      return;
    }
  } catch (e, st) {
    print("⛔ [RESTORE] failed: $e");
    print(st);
    // ❌ NO logout aquí
  }

  if (!mounted) return;
  setState(() => loading = false);
}


  Future<void> _onLoggedIn(AuthResult auth) async {
  setState(() => loading = true);

  try {
    session = auth;

      final config = await CustomerLoader.load(auth.customer);
      final merged = config.copyWith(enabledModules: auth.modules);

      CustomerProvider.instance.setConfig(merged, auth.customer);
      TranslationService.instance.setLanguage(merged.language);

    // 🔑 INIT LOGO / BRANDING
    await CustomerBrandingService.instance.initForCustomer(auth.customer);
    await AppDatabase.initForCustomer(auth.customer);

  } catch (e, st) {
    print("⛔ [POST-LOGIN] failed: $e");
    print(st);
    session = null; // solo memoria
    // ❌ NO logout
  }

  if (!mounted) return;
  setState(() => loading = false);
}


 Widget _redirectAfterLogin(AuthResult auth) {
  // ✅ siempre entra a HomeMenu
  // ahí activas licencia si no hay módulos
  if (auth.modules.length == 1) {
    return ModuleRegistry.load(auth.modules.first);
  }
  return const HomeMenu();
}


  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<CustomerProvider>(context);
    final t = Provider.of<TranslationService>(context);

    final theme = provider.initialized
        ? provider.config.theme
        : const CustomerTheme(
            primary: Colors.blue,
            secondary: Colors.blueAccent,
            background: Colors.white,
          );

    final themeData = ThemeData(
      primaryColor: theme.primary,
      scaffoldBackgroundColor: theme.background,
      appBarTheme: AppBarTheme(
        backgroundColor: theme.primary,
        foregroundColor: Colors.white,
      ),
      fontFamily: t.fontFamily,
      colorScheme: ColorScheme.fromSeed(
        seedColor: theme.primary,
        primary: theme.primary,
        secondary: theme.secondary,
      ),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: themeData,
      home: loading
          ? const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            )
          : session == null
              ? LoginScreen(onLogin: _onLoggedIn)
              : _redirectAfterLogin(session!),
    );
  }
}

// ================== LOGIN SCREEN ==================
// 🔒 DISEÑO ORIGINAL (BACKUP) — 100% ÍNTEGRO

class LoginScreen extends StatefulWidget {
  final Function(AuthResult) onLogin;
  const LoginScreen({super.key, required this.onLogin});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final user = TextEditingController();
  final pass = TextEditingController();

  String? error;
  bool loading = false;

  static const _gifLeft = 'assets/login/pc.gif';
  static const _iconUser = 'assets/login/icons/user.svg';
  static const _iconLock = 'assets/login/icons/lock.svg';

  static const _sinbad = Color(0xFFA4D5D0);
  static const _mandysPink = Color(0xFFF0B6A3);
  static const _sandwisp = Color(0xFFF4E1A4);
  static const _jaggedIce = Color(0xFFB7E1D8);
  static const _springRain = Color(0xFFA2C8B1);

  static const _leftBlue = Color(0xFF2E66C7);
  static const _btnDark = Color(0xFF1F1F1F);

  @override
  void dispose() {
    user.dispose();
    pass.dispose();
    super.dispose();
  }

  Future<void> _doLogin() async {
    setState(() {
      loading = true;
      error = null;
    });

    final result =
        await AuthService().login(user.text.trim(), pass.text.trim());

        print("🧪 [LOGIN] result is null? ${result == null}");
if (result != null) {
  print("🧪 [LOGIN] customer=${result.customer} modules=${result.modules}");
}

    if (!mounted) return;

    if (result == null) {
      final t = context.read<TranslationService>();
      setState(() {
        loading = false;
        error = t.t("login.error");
      });
    } else {
      widget.onLogin(result);
    }
  }

  Widget _pillField({
    required TextEditingController controller,
    required String hint,
    required String iconAsset,
    bool obscure = false,
    TextInputAction action = TextInputAction.next,
    void Function(String)? onSubmitted,
  }) {
    return Material(
      color: Colors.white.withOpacity(0.70),
      elevation: 10,
      shadowColor: Colors.black.withOpacity(0.22),
      borderRadius: BorderRadius.circular(30),
      child: SizedBox(
        height: 58,
        child: TextField(
          controller: controller,
          obscureText: obscure,
          textInputAction: action,
          onSubmitted: onSubmitted,
          style: const TextStyle(
            fontFamily: 'Share',
            fontSize: 18,
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: hint,
            hintStyle: TextStyle(
              fontFamily: 'Share',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _mandysPink,
              shadows: [
                Shadow(
                  offset: const Offset(2, 2),
                  blurRadius: 1.8,
                  color: Colors.black.withOpacity(0.25),
                ),
              ],
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 18, right: 10),
              child: SvgPicture.asset(
                iconAsset,
                width: 50,
                height: 50,
                fit: BoxFit.scaleDown,
              ),
            ),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 64, minHeight: 58),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Provider.of<TranslationService>(context);

    final leftPane = Stack(
      fit: StackFit.expand,
      children: [
        Container(color: _leftBlue),
        Image.asset(
          _gifLeft,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        ),
      ],
    );

    final rightPane = LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final h = c.maxHeight;

        double px(double v) => v.roundToDouble();
        final uiScale = (w / 900.0).clamp(0.72, 1.10);
        double fs(double v) => v * uiScale;
        double sp(double v) => v * uiScale;

        const designW = 654.0;
        const designH = 1144.0;
        final s = (w / designW) < (h / designH) ? (w / designW) : (h / designH);

        final dx = (w - designW * s);
        double sx(double v) => (dx + v * s).roundToDouble();
        double sw(double v) => (v * s).roundToDouble();
        double sh(double v) => (v * s).roundToDouble();

        const reduceH = 0.74;

        return Container(
          color: _springRain,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                left: sx(345),
                bottom: 0,
                width: sw(309),
                height: sh(1144 * (reduceH + .02)),
                child: const ColoredBox(color: _sandwisp),
              ),
              Positioned(
                left: sx(178),
                bottom: 0,
                width: sw(403),
                height: sh(992 * reduceH),
                child: const ColoredBox(color: _mandysPink),
              ),
              Positioned(
                left: sx(0),
                bottom: 0,
                width: sw(403),
                height: sh(752 * reduceH),
                child: const ColoredBox(color: _jaggedIce),
              ),
              SafeArea(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    px((w * 0.12).clamp(44.0, 120.0)),
                    sp(52),
                    sp(24),
                    sp(40),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Inicia',
                        style: TextStyle(
                          fontFamily: 'Sora',
                          fontSize: fs(60),
                          fontWeight: FontWeight.w800,
                          color: _sandwisp,
                          shadows: [
                            Shadow(
                              offset: const Offset(4, 4),
                              color: Colors.black.withOpacity(0.25),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'Sesion',
                        style: TextStyle(
                          fontFamily: 'Sora',
                          fontSize: fs(60),
                          fontWeight: FontWeight.w800,
                          color: _sandwisp,
                          shadows: [
                            Shadow(
                              offset: const Offset(4, 4),
                              color: Colors.black.withOpacity(0.25),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: sp(44)),
                      _pillField(
                        controller: user,
                        hint: t.t("login.username"),
                        iconAsset: _iconUser,
                      ),
                      SizedBox(height: sp(24)),
                      _pillField(
                        controller: pass,
                        hint: t.t("login.password"),
                        iconAsset: _iconLock,
                        obscure: true,
                        onSubmitted: (_) => loading ? null : _doLogin(),
                      ),
                      if (error != null) ...[
                        SizedBox(height: sp(12)),
                        Text(
                          error!,
                          style: TextStyle(
                            color: Colors.red,
                            fontFamily: 'Share',
                            fontSize: fs(16),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      SizedBox(height: sp(28)),
                      Center(
                        child: SizedBox(
                          width: px((240 * uiScale).clamp(200.0, 240.0)),
                          height: px((64 * uiScale).clamp(56.0, 64.0)),
                          child: ElevatedButton(
                            onPressed: loading ? null : _doLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _btnDark,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: loading
                                ? const CircularProgressIndicator(
                                    strokeWidth: 2,
                                  )
                                : Text(
                                    'INICIAR',
                                    style: TextStyle(
                                      fontFamily: 'Share',
                                      fontSize: fs(28),
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.2,
                                      color: _sinbad,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    return Scaffold(
      backgroundColor: _springRain,
      body: LayoutBuilder(
        builder: (context, c) {
          final narrow = c.maxWidth < 900;
          if (narrow) {
            return Stack(
              fit: StackFit.expand,
              children: [
                leftPane,
                Container(color: Colors.black.withOpacity(0.18)),
                rightPane,
              ],
            );
          }
          return Row(
            children: [
              Flexible(flex: 4, child: leftPane),
              Flexible(flex: 6, child: rightPane),
            ],
          );
        },
      ),
    );
  }
}
