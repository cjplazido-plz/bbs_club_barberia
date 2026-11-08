// lib/services/settings_service.dart - ROBUSTO - FIX para "Algunos valores no se pudieron guardar" image_7d4ab2.png
import 'package:supabase_flutter/supabase_flutter.dart';

class SettingsService {
  static String shopName = 'BBS CLUB';
  static String shopRif = '76.123.456-7';
  static String shopAddress = 'Manuel Montt #460, local 6 - Coronel';
  static String shopPhone = '+569 6106 9670';
  static String shopEmail = '';
  static String shopLogoUrl = '';
  static String ticketLogoUrl = '';
  static String currencySymbol = '\$';
  static String currencyCode = 'CLP';
  static String ticketHeader = 'BBS CLUB F.C';
  static String ticketFooter = '¡Gracias por su visita!';
  static String currencyFormat = 'es-CL';

  static Future<void> loadSettings() async {
    try {
      final data = await Supabase.instance.client.from('settings').select('*');
      for (var row in data as List) {
        final key = row['key']?.toString() ?? '';
        final value = row['value']?.toString() ?? row['val']?.toString() ?? '';
        if (value.isEmpty) continue;
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
      }
      // Fallback desde ticket_config si settings vacio
      try {
        final tc = await Supabase.instance.client.from('settings').select('*').eq('key', 'ticket_config').maybeSingle();
        if (tc != null && tc['value'] != null) {
          final v = Map<String, dynamic>.from(tc['value'] as Map);
          if (shopName == 'BBS CLUB' && v['nombre_negocio'] != null) shopName = v['nombre_negocio'];
          if (v['logo_url'] != null && ticketLogoUrl.isEmpty) ticketLogoUrl = v['logo_url'];
        }
      } catch (_) {}
    } catch (e) {
      print('Settings load $e');
    }
  }

  static Future<bool> updateMultiple(Map<String, String> values) async {
    bool allOk = true;
    for (var entry in values.entries) {
      try {
        await Supabase.instance.client.from('settings').upsert({
          'key': entry.key,
          'value': entry.value,
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'key');
        // actualizar cache local
        switch (entry.key) {
          case 'shop_name': shopName = entry.value; break;
          case 'shop_rif': shopRif = entry.value; break;
          case 'shop_address': shopAddress = entry.value; break;
          case 'shop_phone': shopPhone = entry.value; break;
          case 'shop_email': shopEmail = entry.value; break;
          case 'shop_logo_url': shopLogoUrl = entry.value; break;
          case 'ticket_logo_url': ticketLogoUrl = entry.value; break;
          case 'currency_symbol': currencySymbol = entry.value; break;
          case 'currency_code': currencyCode = entry.value; break;
          case 'ticket_header': ticketHeader = entry.value; break;
          case 'ticket_footer': ticketFooter = entry.value; break;
        }
      } catch (e) {
        print('Settings upsert fail ${entry.key}: $e');
        allOk = false;
        // no retornamos false inmediato, seguimos con los demas
      }
    }
    return allOk;
  }

  static String formatCurrency(double amount) {
    final fmt = amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
    return '\$ $fmt';
  }

  static Future<bool> updateSingle(String key, String value) async {
    final r = await updateMultiple({key: value});
    return r;
  }
}
