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
import 'screens/pos_screen.dart'; // <- pantalla principal despues del login: POS, no Agenda

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
      // FIX QR /reservar publica: home ignoraba la URL y AuthGate mandaba a login.
      // Ahora initialRoute respeta la URL y AuthGate tambien revisa Uri.base.
      initialRoute: (Uri.base.path == '/reservar' || Uri.base.path == '/reservar/') ? '/reservar' : '/',
      routes: {
        '/': (context) => const AuthGate(),
        '/login': (context) => LoginScreen(),
        '/reservar': (context) => PublicBookingScreen(),
        '/agenda': (context) => AppointmentsScreen(),
        '/pos': (context) => PosScreen(),
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
      if (mounted) {
        _init(); // Volver a cargar el perfil si cambia la sesión
        setState(() {});
      }
    });
  }

  Future<void> _init() async {
    setState(() => _isLoading = true);
    try {
      // 1. Recuperar sesión
      await Supabase.instance.client.auth.getSession();
      final session = Supabase.instance.client.auth.currentSession;
      
      if (session != null) {
        final user = session.user;
        currentUserEmail = user.email ?? '';
        
        // 2. Buscar su perfil en la base de datos para saber su ROL
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('role, full_name')
            .eq('id', user.id)
            .maybeSingle();

        if (profile != null) {
          currentUserRole = profile['role'] ?? 'cashier';
          currentUserName = profile['full_name'] ?? '';
        } else {
          // Si no tiene perfil (raro), lo dejamos como cashier por seguridad
          currentUserRole = 'cashier'; 
        }
      }
    } catch (e) {
      print('Error cargando perfil: $e');
    }
    
    // Pequeño delay para web, asegura que localStorage cargó
    await Future.delayed(const Duration(milliseconds: 300));
    
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // PUBLICA: si la URL es /reservar, mostrar Reservar Cita aunque no haya sesion
    final uriPath = Uri.base.path;
    if (uriPath == '/reservar' || uriPath == '/reservar/') {
      return PublicBookingScreen();
    }
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final session = Supabase.instance.client.auth.currentSession;

    // Si hay sesion guardada, entra directo a POS
    if (session != null) {
      return PosScreen();
    }

    // Si no hay sesión, va al login
    return LoginScreen();
  }
}
