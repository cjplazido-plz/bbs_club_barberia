import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'services/database_service.dart';
import 'services/settings_service.dart';
import 'services/theme_service.dart';
import 'screens/login_screen.dart';
import 'screens/public_booking_screen.dart';
import 'screens/appointments_screen.dart'; // <- tu pantalla principal después del login

String currentUserRole = 'admin';
String currentUserName = '';
String currentUserEmail = '';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // ✅ Inicializar locale español
  await initializeDateFormatting('es', null);
  
  // Inicializar Isar
  await DatabaseService.init();
  
  // Inicializar Supabase CON opciones para web (esto arregla el refresh)
  await Supabase.initialize(
    url: 'https://kshpmivwtconponuxevx.supabase.co',
    anonKey: 'sb_publishable_Vg3CpOZkRDJbTD-Mw_F3nw_S2Wmajf3',
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
      autoRefreshToken: true,
    ),
  );
  
  // ✅ CLAVE: Esperar a que Supabase recupere la sesión del localStorage en web
  try {
    await Supabase.instance.client.auth.getSession();
  } catch (_) {}
  
  // Cargar configuración de la barbería
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
    return MaterialApp(
      title: SettingsService.shopName,
      debugShowCheckedModeBanner: false,
      theme: ThemeService.lightTheme,
      darkTheme: ThemeService.darkTheme,
      themeMode: ThemeService.themeMode,
      locale: const Locale('es'),
      supportedLocales: const [
        Locale('es'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // ✅ FIX: En vez de initialRoute fijo a login, usamos AuthGate que decide si hay sesión
      home: const AuthGate(),
      routes: {
        '/login': (context) => LoginScreen(),
        '/reservar': (context) => PublicBookingScreen(),
        '/agenda': (context) => AppointmentsScreen(),
      },
    );
  }
}

/// ✅ ESTE WIDGET ARREGLA EL LOGOUT AL REFRESCAR
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _init();

    // Escucha cambios de auth (login/logout) para actualizarse automático
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _init() async {
    try {
      await Supabase.instance.client.auth.getSession();
    } catch (_) {}
    
    // Pequeño delay para web, asegura que localStorage cargó
    await Future.delayed(const Duration(milliseconds: 400));
    
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final session = Supabase.instance.client.auth.currentSession;
    final user = Supabase.instance.client.auth.currentUser;

    // Si hay sesión guardada, entra directo a la agenda
    if (session != null && user != null) {
      // Si guardas rol/nombre en variables globales, restáuralos aquí
      currentUserEmail = user.email ?? '';
      return AppointmentsScreen();
      // Si tu pantalla principal es otra (ej: DashboardScreen), cámbiala aquí
    }

    // Si no hay sesión, va al login
    return LoginScreen();
  }
}
