import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/local_transaction.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Subir una venta a la nube
  Future<void> uploadTransaction(LocalTransaction transaction) async {
    try {
      // 1. Insertar la transacción principal
      final transactionResponse = await _client
          .from('transactions')
          .insert({
            'subtotal': transaction.subtotal,
            'total': transaction.total,
            'payment_method': transaction.paymentMethod,
            'status': transaction.status,
          })
          .select()
          .single();

      final transactionId = transactionResponse['id'] as String;

      // 2. Insertar los ítems de la transacción
      final itemsData = transaction.items.map((item) {
        return {
          'transaction_id': transactionId,
          'service_name': item.serviceName,
          'price_at_moment': item.priceAtMoment,
          'quantity': item.quantity,
        };
      }).toList();

      await _client.from('transaction_items').insert(itemsData);

      print('✅ Venta subida a la nube: $transactionId');
    } catch (e) {
      print('❌ Error al subir venta a la nube: $e');
    }
  }

  /// Obtener todas las ventas de hoy (para el dashboard)
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
      print(' Error al obtener ventas: $e');
      return [];
    }
  }

  /// Calcular total del día
  Future<double> getTodayTotal() async {
    try {
      final List<Map<String, dynamic>> sales = await getTodaySales();
      double total = 0.0;
      
      for (final sale in sales) {
        total += (sale['total'] as num).toDouble();
      }
      
      return total;
    } catch (e) {
      print('❌ Error al calcular total: $e');
      return 0.0;
    }
  }
}