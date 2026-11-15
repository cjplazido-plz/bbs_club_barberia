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

// FIX: Por defecto, si falla la carga, que sea 'cashier' (cajero) por seguridad, NO admin.
String currentUserRole = 'cashier'; 
String currentUserName = '';
String currentUserEmail = '';

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
  
  // Esperar a que recupere la sesión ANTES de arrancar la app
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
    return MaterialApp(
      title: SettingsService.shopName,
      debugShowCheckedModeBanner: false,
      theme: ThemeService.lightTheme,
      darkTheme: ThemeService.darkTheme,
      themeMode: ThemeMode.dark, // Forzar modo oscuro
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
      },
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

  @override
  void initState() {
    super.initState();
    _init();

    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (mounted) {
        _init();
        setState(() {});
      }
    });
  }

  Future<void> _init() async {
    if (mounted) setState(() => _isLoading = true);
    
    try {
      await Supabase.instance.client.auth.getSession();
      final session = Supabase.instance.client.auth.currentSession;
      
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
            // FIX: Si el perfil no tiene full_name, usa el correo, si no, 'Usuario'
            currentUserName = profile['full_name'] ?? user.email?.split('@').first ?? 'Usuario';
          } else {
            // FIX: Si el usuario existe en Auth pero no en la tabla profiles
            currentUserRole = 'cashier';
            currentUserName = user.email?.split('@').first ?? 'Usuario'; 
          }
        } catch (e) {
          debugPrint('Error obteniendo perfil: $e');
          // FIX: En caso de error de red, al menos asignamos el nombre del correo
          currentUserRole = 'cashier';
          currentUserName = user.email?.split('@').first ?? 'Usuario';
        }
      }
    } catch (e) {
      debugPrint('Error recuperando sesión: $e');
    }
    
    await Future.delayed(const Duration(milliseconds: 400));
    
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
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF6366F1))),
      );
    }

    final session = Supabase.instance.client.auth.currentSession;

    if (session != null) {
      return PosScreen();
    }

    return LoginScreen();
  }
}