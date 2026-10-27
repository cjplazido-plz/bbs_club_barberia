import 'package:supabase_flutter/supabase_flutter.dart';

class SettingsService {
  // Valores por defecto
  static String shopName = 'BBS CLUB BARBERÍA';
  static String shopRif = '78.123.456-7';
  static String shopAddress = 'LOS BIGOTES 1313 - LOMAS TURBO';
  static String shopPhone = '+56 99 999 9999';
  static String shopLogoUrl = '';
  static String ticketLogoUrl = '';
  static String ticketHeader = 'BBS CLUB';
  static String ticketFooter = '¡Gracias por su visita!';

  static const String _currencySymbol = '\$';
  static const String _currencyCode = 'CLP';

  static String formatCurrency(double amount) {
    final formatted = amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
    return '$_currencySymbol$formatted';
  }

  // ✅ CARGAR configuración desde Supabase
  static Future<void> loadSettings() async {
    try {
      final response = await Supabase.instance.client
          .from('settings')
          .select('key, value');

      final settings = List<Map<String, dynamic>>.from(response);
      for (final setting in settings) {
        final key = setting['key'] as String;
        final value = setting['value'] as String? ?? '';

        switch (key) {
          case 'shop_name':
            shopName = value;
            break;
          case 'shop_rif':
            shopRif = value;
            break;
          case 'shop_address':
            shopAddress = value;
            break;
          case 'shop_phone':
            shopPhone = value;
            break;
          case 'shop_logo_url':
            shopLogoUrl = value;
            break;
          case 'ticket_logo_url':
            ticketLogoUrl = value;
            break;
          case 'ticket_header':
            ticketHeader = value;
            break;
          case 'ticket_footer':
            ticketFooter = value;
            break;
        }
      }
      print('✅ Configuración cargada desde Supabase');
    } catch (e) {
      print('⚠️ Error al cargar configuración: $e');
    }
  }

  // ✅ GUARDAR configuración usando upsert (evita error de clave duplicada)
static Future<void> saveSettingsToSupabase() async {
  try {
    // ✅ Función helper para actualizar o insertar
    Future<void> saveSetting(String key, String value) async {
      final existing = await Supabase.instance.client
          .from('settings')
          .select()
          .eq('key', key)
          .maybeSingle();

      if (existing != null) {
        await Supabase.instance.client
            .from('settings')
            .update({'value': value})
            .eq('key', key);
      } else {
        await Supabase.instance.client
            .from('settings')
            .insert({'key': key, 'value': value});
      }
    }

    await saveSetting('shop_name', shopName);
    await saveSetting('shop_rif', shopRif);
    await saveSetting('shop_address', shopAddress);
    await saveSetting('shop_phone', shopPhone);
    await saveSetting('shop_logo_url', shopLogoUrl);
    await saveSetting('ticket_logo_url', ticketLogoUrl);
    await saveSetting('ticket_header', ticketHeader);
    await saveSetting('ticket_footer', ticketFooter);

    print('✅ Configuración guardada en Supabase');
  } catch (e) {
    print('❌ Error al guardar configuración: $e');
    rethrow;
  }
}