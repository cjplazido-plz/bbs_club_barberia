import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'services/database_service.dart';
import 'services/settings_service.dart';
import 'services/theme_service.dart';
import 'screens/login_screen.dart';
import 'screens/public_booking_screen.dart';
import 'screens/pos_screen.dart'; // <- Pantalla principal real después del login

String currentUserRole = 'admin';
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
      themeMode: ThemeService.themeMode,
      locale: const Locale('es'),
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const AuthGate(),
      routes: {
        '/login': (context) => LoginScreen(),
        '/reservar': (context) => PublicBookingScreen(),
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
      if (mounted) setState(() {});
    });
  }

  Future<void> _init() async {
    try {
      await Supabase.instance.client.auth.getSession();
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        // Recupera rol y nombre si hay sesión guardada
        try {
          if (user.email?.toLowerCase() == 'cjplazido@gmail.com') {
            currentUserRole = 'admin';
            currentUserName = 'Desarrollador (Acceso Total)';
            currentUserEmail = user.email ?? '';
          } else {
            final profile = await Supabase.instance.client
                .from('profiles')
                .select()
                .eq('email', user.email ?? '')
                .maybeSingle();
            if (profile != null) {
              currentUserRole = profile['role'] ?? 'admin';
              currentUserName = profile['full_name'] ?? profile['name'] ?? user.email?.split('@').first ?? 'Usuario';
              currentUserEmail = user.email ?? '';
            }
          }
        } catch (_) {}
      }
    } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final session = Supabase.instance.client.auth.currentSession;
    final user = Supabase.instance.client.auth.currentUser;

    if (session != null && user != null) {
      // ✅ Entra directo al POS (tu pantalla principal real)
      // Desde el POS podrás ir a Dashboard y a Agenda con flecha de volver
      return PosScreen();
    }

    return LoginScreen();
  }
}
