import 'package:supabase_flutter/supabase_flutter.dart';

class TicketConfigService {
  static const String table = 'settings';
  static Map<String, dynamic> _cache = {
    'nombre_negocio': 'BBS CLUB BARBERIA',
    'nombre_local': 'BBS CLUB BARBERIA',
    'rut': '77.000000-0',
    'direccion': 'Manuel Montt #460, local 6 - Coronel',
    'telefono': '+56 9 6106 9670',
    'email': '',
    'mensaje': '¡Gracias por su visita!',
    'ancho': '80mm',
    'metodo_impresion': 'browser',
    'auto_print': true,
    'logo_url': '',
    'logo_url_app': '',
    'logo_url_ticket': '',
    // FIX: Valores por defecto seguros. Si falla internet, que empiece en 9999 o similar para no duplicar.
    'folio_prefijo': '', 
    'prefijo': '',
    'folio_actual': 9999, 
    'folioActual': 9999,
    'sii_razon': 'BBS CLUB SPA',
    'sii_giro': 'Barberia',
    'sii_direccion': 'Manuel Montt #460, local 6 - Coronel',
    'sii_rut_emisor': '77.000000-0',
    'ticket_html': '',
    'document_wrapper': '',
  };

  static String get nombreNegocio => _cache['nombre_negocio'] ?? 'BBS CLUB BARBERIA';
  static String get rut => _cache['rut'] ?? '77.000000-0';
  static String get direccion => _cache['direccion'] ?? 'Coronel';
  static String get telefono => _cache['telefono'] ?? '';
  static String get email => _cache['email'] ?? '';
  static String get mensaje => _cache['mensaje'] ?? '¡Gracias por su visita!';
  static String get ancho => _cache['ancho'] ?? '80mm';
  static String get prefijo => _cache['folio_prefijo'] ?? _cache['prefijo'] ?? '';
  static String get folioPrefijo => prefijo;
  
  static int get folioActual {
    final v = _cache['folio_actual'] ?? _cache['folioActual'] ?? 9999;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 9999;
  }

  static String get logoUrl => _cache['logo_url'] ?? '';
  static String get appLogoUrl => _cache['logo_url_app'] ?? logoUrl;
  static String get ticketLogoUrl => _cache['logo_url_ticket'] ?? appLogoUrl;
  static String get shopLogoUrl => appLogoUrl;
  static String get logoUrlTicket => ticketLogoUrl;

  static String get siiRazon => _cache['sii_razon'] ?? nombreNegocio;
  static String get siiGiro => _cache['sii_giro'] ?? 'Barberia';
  static String get siiDireccion => _cache['sii_direccion'] ?? direccion;
  static String get siiRutEmisor => _cache['sii_rut_emisor'] ?? rut;
  static String get ticketHtml => _cache['ticket_html'] ?? '';
  static String get documentWrapper => _cache['document_wrapper'] ?? '';
  static bool get autoPrint => _cache['auto_print'] ?? true;
  static String get metodoImpresion => _cache['metodo_impresion'] ?? 'browser';
  static Map<String, dynamic> get config => _cache;

  static String _norm(String u) => u.trim().replaceAll(' ', '%20').replaceAll('(', '%28').replaceAll(')', '%29').replaceAll('%2520', '%20');

  static Future<void> load() async {
    try {
      final res = await Supabase.instance.client.from(table).select('*').eq('key', 'ticket_config').maybeSingle();
      if (res != null && res['value'] != null) {
        _cache.addAll(Map<String, dynamic>.from(res['value'] as Map));
      }
    } catch (e) { 
      print('TicketConfig load error: $e'); 
    }
  }

  static Future<bool> save(Map<String, dynamic> newConfig) async {
    try {
      final Map<String, dynamic> norm = {};
      newConfig.forEach((k,v){
        norm[k]=v;
        if(k.toString().contains('logo_url')) norm[k]=_norm(v.toString());
        if(k=='nombre_local') norm['nombre_negocio']=v;
        if(k=='nombre_negocio') norm['nombre_local']=v;
        if(k=='prefijo') norm['folio_prefijo']=v;
        if(k=='folio_prefijo') norm['prefijo']=v;
        if(k=='folio_actual') norm['folioActual']=v;
        if(k=='folioActual') norm['folio_actual']=v;
        if(k=='logo_url_app') norm['logo_url']=v;
      });
      
      // Actualizamos la caché local
      _cache.addAll(norm);
      
      // Guardamos en Supabase
      await Supabase.instance.client.from(table).upsert({
        'key': 'ticket_config',
        'value': _cache,
        'updated_at': DateTime.now().toIso8601String()
      }, onConflict: 'key');
      
      return true;
    } catch(e){ 
      print('❌ TicketConfig save error: $e'); 
      return false; 
    }
  }

  static Future<int> useNextFolio() async {
    try {
      // Llamada atómica a la base de datos (a prueba de doble clic)
      final response = await Supabase.instance.client.rpc('get_next_folio');
      
      // Supabase devuelve el folio que acabamos de usar
      final int folioUsado = response as int; 
      
      // Actualizamos la caché local para que la interfaz muestre el siguiente
      _cache['folio_actual'] = folioUsado + 1;
      _cache['folioActual'] = folioUsado + 1;
      
      return folioUsado;
    } catch (e) {
      // Si falla el internet o la base de datos, detenemos la venta
      throw Exception('Error de conexión: No se pudo generar el folio seguro en Supabase. $e');
    }
  }