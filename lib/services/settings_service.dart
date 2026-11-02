import 'package:supabase_flutter/supabase_flutter.dart';

class SettingsService {
  static String shopName = 'BBS CLUB BARBERÍA';
  static String shopRif = '78.123.456-7';
  static String shopAddress = 'LOS BIGOTES 1313 - LOMAS TURBO';
  static String shopPhone = '+56 99 999 9999';
  static String shopEmail = '';
  static String shopLogoUrl = '';
  static String ticketLogoUrl = '';
  static String currencySymbol = '\$';
  static String currencyCode = 'CLP';
  static String ticketHeader = 'BBS CLUB';
  static String ticketFooter = '¡Gracias por su visita!';

  static String formatCurrency(double amount) {
    final formatted = amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
    return '$currencySymbol$formatted';
  }

  static Future<void> loadSettings() async {
    try {
      print('🔄 Cargando configuración desde Supabase...');
      final response = await Supabase.instance.client
          .from('settings')
          .select('*')
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null) {
        shopName = response['shop_name'] ?? shopName;
        shopRif = response['shop_rif'] ?? shopRif;
        shopAddress = response['shop_address'] ?? shopAddress;
        shopPhone = response['shop_phone'] ?? shopPhone;
        shopEmail = response['shop_email'] ?? shopEmail;
        shopLogoUrl = response['shop_logo_url'] ?? shopLogoUrl;
        ticketLogoUrl = response['ticket_logo_url'] ?? ticketLogoUrl;
        currencySymbol = response['currency_symbol'] ?? currencySymbol;
        currencyCode = response['currency_code'] ?? currencyCode;
        ticketHeader = response['ticket_header'] ?? ticketHeader;
        ticketFooter = response['ticket_footer'] ?? ticketFooter;
        print('✅ Configuración cargada');
      } else {
        print('⚠️ No hay configuración en Supabase');
      }
    } catch (e) {
      print('❌ Error al cargar configuración: $e');
    }
  }

  // ✅ MÉTODO CORRECTO: Actualiza si existe, inserta si no existe
  static Future<bool> updateMultiple(Map<String, String> values) async {
    try {
      print('🔄 Guardando configuración...');
      
      // Buscar si ya existe una fila de configuración
      final existing = await Supabase.instance.client
          .from('settings')
          .select('id')
          .limit(1)
          .maybeSingle();

      if (existing != null) {
        // ✅ ACTUALIZAR la fila existente
        print('📝 Actualizando configuración existente (ID: ${existing['id']})');
        await Supabase.instance.client
            .from('settings')
            .update(values)
            .eq('id', existing['id']);
      } else {
        // ✅ INSERTAR nueva fila
        print('➕ Insertando nueva configuración');
        await Supabase.instance.client
            .from('settings')
            .insert(values);
      }

      // Actualizar variables en memoria
      values.forEach((key, value) {
        switch (key) {
          case 'shop_name': shopName = value; break;
          case 'shop_rif': shopRif = value; break;
          case 'shop_address': shopAddress = value; break;
          case 'shop_phone': shopPhone = value; break;
          case 'shop_email': shopEmail = value; break;
          case 'shop_logo_url': shopLogoUrl = value; break;
          case 'ticket_logo_url': ticketLogoUrl = value; break;
          case 'currency_symbol': currencySymbol = value; break;
          case 'currency_code': currencyCode = value; break;
          case 'ticket_header': ticketHeader = value; break;
          case 'ticket_footer': ticketFooter = value; break;
        }
      });
      
      print('✅ Configuración guardada');
      return true;
    } catch (e) {
      print('❌ Error al guardar: $e');
      return false;
    }
  }
}