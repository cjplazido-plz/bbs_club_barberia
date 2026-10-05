import 'package:supabase_flutter/supabase_flutter.dart';

class SettingsService {
  // Variables estáticas
  static String shopName = 'BBS CLUB F.C';
  static String shopRif = '77.123.456-7';
  static String shopAddress = 'LOS BIGOTES 1313 - LOMAS TURBO';
  static String shopPhone = '+56 99 9 9 9 9 9 9 9';
  static String shopEmail = '';
  static String shopLogoUrl = '';
  static String ticketLogoUrl = ''; // ✅ NUEVO: Logo específico para tickets
  static String currencySymbol = '\$';
  static String currencyCode = 'CLP';
  static String ticketHeader = 'BBS CLUB F.C';
  static String ticketFooter = '¡Gracias por su visita!';

  // Formato de moneda chilena
  static String formatCurrency(double amount) {
    final formatted = amount.toStringAsFixed(0);
    final buffer = StringBuffer();
    for (int i = 0; i < formatted.length; i++) {
      if (i > 0 && (formatted.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(formatted[i]);
    }
    return '$currencySymbol${buffer.toString()}';
  }

  // ✅ MÉTODO: Cargar settings desde Supabase
  static Future<void> loadSettings() async {
    try {
      print('🔄 Cargando configuración desde Supabase...');
      final response = await Supabase.instance.client
          .from('settings')
          .select('*')
          .limit(1)
          .maybeSingle();

      if (response != null) {
        shopName = response['shop_name'] ?? shopName;
        shopRif = response['shop_rif'] ?? shopRif;
        shopAddress = response['shop_address'] ?? shopAddress;
        shopPhone = response['shop_phone'] ?? shopPhone;
        shopEmail = response['shop_email'] ?? shopEmail;
        shopLogoUrl = response['shop_logo_url'] ?? shopLogoUrl;
        ticketLogoUrl = response['ticket_logo_url'] ?? ''; // ✅ NUEVO
        currencySymbol = response['currency_symbol'] ?? currencySymbol;
        currencyCode = response['currency_code'] ?? currencyCode;
        ticketHeader = response['ticket_header'] ?? ticketHeader;
        ticketFooter = response['ticket_footer'] ?? ticketFooter;
        print('✅ Configuración cargada correctamente');
      } else {
        print('⚠️ No hay configuración en Supabase, usando valores por defecto');
      }
    } catch (e) {
      print('❌ Error al cargar configuración: $e');
    }
  }

  // ✅ MÉTODO: Guardar múltiples settings
  static Future<bool> updateMultiple(Map<String, String> values) async {
    try {
      print('🔄 Guardando configuración en Supabase...');
      
      // Verificar si ya existe un registro
      final existing = await Supabase.instance.client
          .from('settings')
          .select('id')
          .limit(1)
          .maybeSingle();

      if (existing != null) {
        // Actualizar registro existente
        await Supabase.instance.client
            .from('settings')
            .update(values)
            .eq('id', existing['id']);
      } else {
        // Insertar nuevo registro
        await Supabase.instance.client
            .from('settings')
            .insert(values);
      }

      // Actualizar valores en memoria
      values.forEach((key, value) {
        switch (key) {
          case 'shop_name': shopName = value; break;
          case 'shop_rif': shopRif = value; break;
          case 'shop_address': shopAddress = value; break;
          case 'shop_phone': shopPhone = value; break;
          case 'shop_email': shopEmail = value; break;
          case 'shop_logo_url': shopLogoUrl = value; break;
          case 'ticket_logo_url': ticketLogoUrl = value; break; // ✅ NUEVO
          case 'currency_symbol': currencySymbol = value; break;
          case 'currency_code': currencyCode = value; break;
          case 'ticket_header': ticketHeader = value; break;
          case 'ticket_footer': ticketFooter = value; break;
        }
      });

      print('✅ Configuración guardada correctamente');
      return true;
    } catch (e) {
      print(' Error al guardar configuración: $e');
      return false;
    }
  }
}