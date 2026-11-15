import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  // =======================================================================
  // ⚠️ ADVERTENCIA DE SEGURIDAD ⚠️
  // La función 'uploadTransaction' fue ELIMINADA de este archivo.
  // Razón: Era una versión antigua que insertaba ventas SIN folio, SIN cajero
  // y SIN barbero, generando registros "fantasma" y folios duplicados (NULL).
  //
  // La lógica de cobro y guardado de transacciones ahora vive ÚNICAMENTE 
  // en 'pos_screen.dart' (método _completeTransaction) que sí usa el folio
  // correlativo, el UUID del cajero logueado y las comisiones de los barberos.
  // =======================================================================

  /// Obtener todas las ventas de hoy (para el Dashboard o Reportes rápidos)
  Future<List<Map<String, dynamic>>> getTodaySales() async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final todayString = today.toIso8601String();
      
      final response = await _client
          .from('transactions')
          .select('*, transaction_items(*)')
          .gte('created_at', todayString)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Error al obtener ventas: $e');
      return [];
    }
  }

  /// Calcular total del día
  Future<double> getTodayTotal() async {
    try {
      final List<Map<String, dynamic>> sales = await getTodaySales();
      double total = 0.0;
      
      for (final sale in sales) {
        total += (sale['total'] as num?)?.toDouble() ?? 0.0;
      }
      
      return total;
    } catch (e) {
      print('❌ Error al calcular total: $e');
      return 0.0;
    }
  }
}