import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'services/database_service.dart';
import 'services/settings_service.dart';
import 'screens/login_screen.dart';
import 'screens/public_booking_screen.dart';

String currentUserRole = 'admin';
String currentUserName = '';
String currentUserEmail = '';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // ✅ Inicializar locale español
  await initializeDateFormatting('es', null);
  
  // Inicializar Isar
  await DatabaseService.init();
  
  // Inicializar Supabase
  await Supabase.initialize(
    url: 'https://kshpmivwtconponuxevx.supabase.co',
    anonKey: 'sb_publishable_Vg3CpOZkRDJbTD-Mw_F3nw_S2Wmajf3',
  );
  
  // Cargar configuración de la barbería
  await SettingsService.loadSettings();
  
  runApp(BarberFlowApp());
}

class BarberFlowApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: SettingsService.shopName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => LoginScreen(),
        '/reservar': (context) => PublicBookingScreen(),
      },
    );
  }
}