// PREMIUM INTRODUCCION LOGO UNICO V8 - AuthGate con logo BBS CLUB dorado, fondo 0A0A0A. FIX 429 + SESION 8H intactos.
import 'screens/tips_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'services/database_service.dart';
import 'services/settings_service.dart';
import 'services/theme_service.dart';
import 'screens/login_screen.dart';
import 'screens/public_booking_screen.dart';
import 'screens/appointments_screen.dart';
import 'screens/pos_screen.dart';
import 'widgets/inactivity_wrapper.dart'; // <-- 1. IMPORTAR EL WRAPPER

String currentUserRole = 'cashier'; 
String currentUserName = '';
String currentUserEmail = '';

// 2. CREAR LA LLAVE GLOBAL
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es', null);
  await DatabaseService.init();
  
  await Supabase.initialize(
    url: 'https://kshpmivwtconponuxevx.supabase.co',
    anonKey: 'sb_publishable_Vg3CpOZkRDJbTD-Mw_F3nw_S2Wmajf3',
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
      autoRefreshToken: true,
    ),
  );
  
  // FIX 429: NO llamar refreshSession() aquí. getSession() ya refresca solo si hace falta.
  // El refresh extra + el de AuthGate duplicaba llamadas a /token?grant_type=refresh_token
  // y Supabase respondía 429 over_request_rate_limit.
  try {
    await Supabase.instance.client.auth.getSession();
  } catch (_) {}
  
  await SettingsService.loadSettings();
  runApp(BarberFlowApp());
}

class BarberFlowApp extends StatefulWidget {
  @override
  State<BarberFlowApp> createState() => _BarberFlowAppState();
}

class _BarberFlowAppState extends State<BarberFlowApp> {
  @override
  Widget build(BuildContext context) {
    // 3. ENVOLVER EL MATERIALAPP
    return InactivityWrapper(
      navigatorKey: navigatorKey,
      timeout: const Duration(hours: 8), // FIX F5/SESION: turno completo del salón, no 10 min
      child: MaterialApp(
        navigatorKey: navigatorKey, // <-- 4. ASIGNAR LA LLAVE AQUÍ
        title: SettingsService.shopName,
        debugShowCheckedModeBanner: false,
        theme: ThemeService.lightTheme,
        darkTheme: ThemeService.darkTheme,
        themeMode: ThemeMode.dark,
        locale: const Locale('es'),
        supportedLocales: const [Locale('es'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        initialRoute: (Uri.base.path == '/reservar' || Uri.base.path == '/reservar/') ? '/reservar' : '/',
        routes: {
          '/': (context) => const AuthGate(),
          '/login': (context) => LoginScreen(),
          '/reservar': (context) => PublicBookingScreen(),
          '/agenda': (context) => AppointmentsScreen(),
          '/pos': (context) => PosScreen(),
          '/propinas': (context) => TipsScreen(),
        },
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isLoading = true;
  bool _isIniting = false; // FIX 429: evita _init() concurrentes
  bool _isRefreshing = false; // FIX 429: un solo refresh a la vez

  @override
  void initState() {
    super.initState();
    _init();

    // FIX 429: este listener era el loop.
    // Antes: CADA onAuthStateChange -> _init() -> getSession() -> otro onAuthStateChange -> _init()...
    // Eso bombardeaba /token?grant_type=refresh_token hasta 429.
    // Ahora: ignora INITIAL_SESSION (ya hicimos _init) y solo reacciona a cambios reales,
    // y _init() tiene guarda para no correrse 2 veces a la vez.
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (!mounted) return;
      final event = data.event;
      if (event == AuthChangeEvent.initialSession) return;
      if (event == AuthChangeEvent.tokenRefreshed) {
        // Token ya refrescado por Supabase (autoRefreshToken), no hay que hacer nada
        if (mounted) setState(() {});
        return;
      }
      if (event == AuthChangeEvent.signedIn || event == AuthChangeEvent.signedOut) {
        _init();
      }
    });
  }

  Future<void> _init() async {
    if (_isIniting) return; // FIX 429: si ya hay un _init en curso, no lanzar otro
    _isIniting = true;
    if (mounted) setState(() => _isLoading = true);

    try {
      await Supabase.instance.client.auth.getSession();
      var session = Supabase.instance.client.auth.currentSession;
      // FIX 429: solo refrescar si de verdad está por vencer Y no estamos ya refrescando.
      // getSession() ya intentó refrescar. Este es solo un último intento, una sola vez.
      final ahora2 = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      if (session != null && session.expiresAt != null && ahora2 > (session.expiresAt! - 60) && !_isRefreshing) {
        _isRefreshing = true;
        try {
          final r = await Supabase.instance.client.auth.refreshSession();
          session = r.session;
        } catch (e) {
          // Si es 429, NO reintentar de inmediato. Esperar a que Supabase libere el límite.
          debugPrint('Refresh falló (puede ser 429, espera 60s sin F5): $e');
        } finally {
          _isRefreshing = false;
        }
      }
      
      if (session != null) {
        final user = session.user;
        currentUserEmail = user.email ?? '';
        
        try {
          final profile = await Supabase.instance.client
              .from('profiles')
              .select('role, full_name')
              .eq('id', user.id)
              .maybeSingle();

          if (profile != null) {
            currentUserRole = profile['role'] ?? 'cashier';
            currentUserName = profile['full_name'] ?? user.email?.split('@').first ?? 'Usuario';
          } else {
            currentUserRole = 'cashier';
            currentUserName = user.email?.split('@').first ?? 'Usuario'; 
          }
        } catch (e) {
          debugPrint('Error obteniendo perfil: $e');
          currentUserRole = 'cashier';
          currentUserName = user.email?.split('@').first ?? 'Usuario';
        }
      }
    } catch (e) {
      debugPrint('Error recuperando sesión: $e');
    }
    
    await Future.delayed(const Duration(milliseconds: 1800)); // PREMIUM: 1.8s para que se vea la animación completa

    _isIniting = false;
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uriPath = Uri.base.path;
    if (uriPath == '/reservar' || uriPath == '/reservar/') {
      return PublicBookingScreen();
    }
    if (_isLoading) {
      return const _PremiumIntro();
    }

    final session = Supabase.instance.client.auth.currentSession;

    if (session != null) {
      return PosScreen();
    }

    return LoginScreen();
  }
}

// INTRO PREMIUM ANIMADA - efecto al iniciar:
// logo entra con zoom suave, brillo dorado que respira, linea dorada que se abre,
// textos aparecen con fade, 3 puntitos dorados cargando.
class _PremiumIntro extends StatefulWidget {
  const _PremiumIntro();
  @override
  State<_PremiumIntro> createState() => _PremiumIntroState();
}

class _PremiumIntroState extends State<_PremiumIntro> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;
  late Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..forward();
    _scale = Tween<double>(begin: 0.72, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.65, curve: Curves.easeOutBack)));
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.15, 0.7, curve: Curves.easeIn)));
    _glow = Tween<double>(begin: 0.12, end: 0.34).animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 1.0, curve: Curves.easeInOut)));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
    Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final double t = _ctrl.value;
          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 0.85,
                colors: [
                  const Color(0xFFD4AF37).withOpacity(0.10),
                  const Color(0xFF0A0A0A),
                  const Color(0xFF0A0A0A),
                ],
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                                // 1. LOGO - UN SOLO LOGO, grande, sin circulo extra ni texto duplicado
                Align(
                  alignment: Alignment.center,
                  child: ScaleTransition(
                    scale: _scale,
                    child: FadeTransition(
                      opacity: _fade,
                      child: Container(
                        width: 230,
                        height: 230,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: const Color(0xFFD4AF37).withOpacity(_glow.value), blurRadius: 48, spreadRadius: 8),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/logo_circular_premium_V8.jpg',
                            width: 230,
                            height: 230,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // 2. TEXTOS - abajo del logo, mismo eje vertical, sin traslape
                Align(
                  alignment: const Alignment(0, 0.68),
                  child: FadeTransition(
                    opacity: _fade,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 26),
                        Container(
                          width: 40 + (t * 90),
                          height: 2,
                          decoration: BoxDecoration(color: const Color(0xFFD4AF37).withOpacity(0.55), borderRadius: BorderRadius.circular(2)),
                        ),
                        const SizedBox(height: 26),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(3, (i) {
                            final double phase = (t * 2 - i * 0.35).clamp(0.0, 1.0);
                            final double op = 0.25 + (0.75 * (1 - (phase - 0.5).abs() * 2).clamp(0.0, 1.0));
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 5),
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(color: const Color(0xFFD4AF37).withOpacity(op), shape: BoxShape.circle),
                            );
                          }),
                        ),
                        const SizedBox(height: 16),
                        const Text('Cargando...', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        const SizedBox(height: 32),
                        const Text('Manuel Montt 460 - local 6 - Coronel', style: TextStyle(color: Colors.white38, fontSize: 11)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
