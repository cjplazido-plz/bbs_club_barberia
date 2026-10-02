import 'package:supabase_flutter/supabase_flutter.dart';

class SettingsService {
  static final _client = Supabase.instance.client;
  static Map<String, String> _cache = {};

  static Future<void> loadSettings() async {
    try {
      final response = await _client.from('settings').select();
      _cache = {};
      for (final row in List<Map<String, dynamic>>.from(response)) {
        _cache[row['key']] = row['value'] ?? '';
      }
      print('✅ Configuración cargada: ${_cache.length} valores');
    } catch (e) {
      print('⚠️ Error al cargar configuración: $e');
    }
  }

  static String get(String key, {String defaultValue = ''}) {
    return _cache[key] ?? defaultValue;
  }

  static Future<bool> update(String key, String value) async {
    try {
      print('🔄 Actualizando $key = $value');
      
      // Verificar si existe
      final existing = await _client
          .from('settings')
          .select('id')
          .eq('key', key)
          .maybeSingle();
      
      if (existing != null) {
        // Actualizar existente
        await _client
            .from('settings')
            .update({
              'value': value,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('key', key);
      } else {
        // Insertar nuevo
        await _client.from('settings').insert({
          'key': key,
          'value': value,
          'description': '',
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
      
      _cache[key] = value;
      print('✅ Configuración actualizada: $key = $value');
      return true;
    } catch (e) {
      print('❌ Error al actualizar $key: $e');
      return false;
    }
  }

  static Future<bool> updateMultiple(Map<String, String> values) async {
    bool allSuccess = true;
    for (final entry in values.entries) {
      final success = await update(entry.key, entry.value);
      if (!success) {
        allSuccess = false;
      }
    }
    return allSuccess;
  }

  // Getters para configuración
  static String get shopName => get('shop_name', defaultValue: 'BarberFlow');
  static String get shopRif => get('shop_rif');
  static String get shopAddress => get('shop_address');
  static String get shopPhone => get('shop_phone');
  static String get shopEmail => get('shop_email');
  static String get shopLogoUrl => get('shop_logo_url');
  static String get currencySymbol => get('currency_symbol', defaultValue: '\$');
  static String get currencyCode => get('currency_code', defaultValue: 'CLP');
  static String get ticketFooter => get('ticket_footer', defaultValue: '¡Gracias por su visita!');
  static String get ticketHeader => get('ticket_header', defaultValue: 'BarberFlow POS');
}