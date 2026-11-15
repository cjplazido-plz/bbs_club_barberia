import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class DashboardRepository {
  final _client = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getBarbers() async {
    try {
      final response = await _client.from('barbers').select('id, name').order('name');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error al obtener barberos: $e');
      return [];
    }
  }

  Future<double> getTotalSales(DateTime start, DateTime end, String? barberId) async {
    try {
      var query = _client
          .from('transactions')
          .select('total, transaction_items(barber_id, price_at_moment, quantity)')
          .gte('created_at', start.toIso8601String())
          .lte('created_at', end.toIso8601String())
          .eq('status', 'completed'); // FIX: Solo ventas completadas

      final response = await query;
      final transactions = List<Map<String, dynamic>>.from(response);
      
      double total = 0.0;
      for (final t in transactions) {
        if (barberId != null && barberId != 'all') {
          // FIX: Sumar solo los items del barbero seleccionado
          final items = List<Map<String, dynamic>>.from(t['transaction_items'] ?? []);
          for (final item in items) {
            if (item['barber_id'] == barberId) {
              final price = (item['price_at_moment'] as num?)?.toDouble() ?? 0.0;
              final qty = (item['quantity'] as num?)?.toInt() ?? 1;
              total += (price * qty);
            }
          }
        } else {
          total += (t['total'] as num?)?.toDouble() ?? 0.0;
        }
      }
      return total;
    } catch (e) {
      print('Error al obtener ventas del periodo: $e');
      return 0.0;
    }
  }

  Future<List<Map<String, dynamic>>> getWeekSales(DateTime start, DateTime end, String? barberId) async {
    final weekData = <String, Map<String, dynamic>>{};
    
    for (int i = 0; i <= end.difference(start).inDays; i++) {
      final date = start.add(Duration(days: i));
      final dayName = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'][date.weekday - 1];
      weekData[DateFormat('yyyy-MM-dd').format(date)] = {'day': dayName, 'total': 0.0, 'count': 0};
    }

    try {
      var query = _client
          .from('transactions')
          .select('total, created_at, transaction_items(barber_id, price_at_moment, quantity)')
          .gte('created_at', start.toIso8601String())
          .lte('created_at', end.toIso8601String())
          .eq('status', 'completed'); // FIX: Solo ventas completadas

      final response = await query;
      final transactions = List<Map<String, dynamic>>.from(response);

      for (final t in transactions) {
        final date = DateTime.parse(t['created_at']);
        final key = DateFormat('yyyy-MM-dd').format(date);
        if (weekData.containsKey(key)) {
          if (barberId != null && barberId != 'all') {
             final items = List<Map<String, dynamic>>.from(t['transaction_items'] ?? []);
             for (final item in items) {
               if (item['barber_id'] == barberId) {
                 final price = (item['price_at_moment'] as num?)?.toDouble() ?? 0.0;
                 final qty = (item['quantity'] as num?)?.toInt() ?? 1;
                 weekData[key]!['total'] = (weekData[key]!['total'] as double) + (price * qty);
               }
             }
          } else {
             weekData[key]!['total'] = (weekData[key]!['total'] as double) + ((t['total'] as num?)?.toDouble() ?? 0.0);
             weekData[key]!['count'] = (weekData[key]!['count'] as int) + 1;
          }
        }
      }

      return weekData.values.toList();
    } catch (e) {
      print('Error al obtener ventas del periodo: $e');
      return weekData.values.toList();
    }
  }

  Future<int> getTransactionCount(DateTime start, DateTime end, String? barberId) async {
    try {
      var query = _client
          .from('transactions')
          .select('id')
          .gte('created_at', start.toIso8601String())
          .lte('created_at', end.toIso8601String())
          .eq('status', 'completed'); // FIX: Solo ventas completadas

      final response = await query;
      return response.length;
    } catch (e) {
      print('Error al obtener conteo: $e');
      return 0;
    }
  }

  Future<List<Map<String, dynamic>>> getBarberRanking(DateTime start, DateTime end, String? barberId) async {
    try {
      var query = _client
          .from('transactions')
          .select('*, transaction_items(*)')
          .gte('created_at', start.toIso8601String())
          .lte('created_at', end.toIso8601String())
          .eq('status', 'completed'); // FIX: Solo ventas completadas

      final response = await query;
      final transactions = List<Map<String, dynamic>>.from(response);
      final barberStats = <String, Map<String, dynamic>>{};

      for (final transaction in transactions) {
        final items = List<Map<String, dynamic>>.from(transaction['transaction_items'] ?? []);
        for (final item in items) {
          if (barberId != null && barberId != 'all' && item['barber_id'] != barberId) continue;
          
          final bName = item['barber_name'] ?? 'Sin barbero';
          
          if (!barberStats.containsKey(bName)) {
            barberStats[bName] = {'name': bName, 'total': 0.0, 'services': 0};
          }
          
          final price = (item['price_at_moment'] as num?)?.toDouble() ?? 0.0;
          final qty = (item['quantity'] as num?)?.toInt() ?? 1;
          
          barberStats[bName]!['total'] = (barberStats[bName]!['total'] as double) + (price * qty);
          barberStats[bName]!['services'] = (barberStats[bName]!['services'] as int) + qty;
        }
      }

      final ranking = barberStats.values.toList();
      ranking.sort((a, b) => (b['total'] as double).compareTo(a['total'] as double));
      return ranking;
    } catch (e) {
      print('Error al obtener ranking: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getBarberCommissions(DateTime start, DateTime end, String? barberId) async {
    try {
      var query = _client
          .from('transactions')
          .select('*, transaction_items(*)')
          .gte('created_at', start.toIso8601String())
          .lte('created_at', end.toIso8601String())
          .eq('status', 'completed'); // FIX: Solo ventas completadas

      final response = await query;
      final transactions = List<Map<String, dynamic>>.from(response);
      final barberCommissions = <String, double>{};

      for (final transaction in transactions) {
        final items = List<Map<String, dynamic>>.from(transaction['transaction_items'] ?? []);
        for (final item in items) {
          if (barberId != null && barberId != 'all' && item['barber_id'] != barberId) continue;
          
          final bName = item['barber_name'] ?? 'Sin barbero';
          final commission = (item['commission_earned'] as num?)?.toDouble() ?? 0.0;
          barberCommissions[bName] = (barberCommissions[bName] ?? 0.0) + commission;
        }
      }

      final result = barberCommissions.entries
          .map((e) => {'name': e.key, 'commission': e.value})
          .toList();
      result.sort((a, b) => (b['commission'] as double).compareTo(a['commission'] as double));
      return result;
    } catch (e) {
      print('Error al obtener comisiones: $e');
      return [];
    }
  }

  Future<int> getAppointmentsCount(DateTime start, DateTime end, String? barberId) async {
    try {
      var query = _client
          .from('appointments')
          .select()
          .gte('appointment_date', start.toIso8601String())
          .lte('appointment_date', end.toIso8601String())
          .neq('status', 'cancelled');

      if (barberId != null && barberId != 'all') {
        query = query.eq('barber_id', barberId); 
      }

      final response = await query;
      return response.length;
    } catch (e) {
      print('Error al obtener citas: $e');
      return 0;
    }
  }

  Future<Map<String, int>> getPaymentMethods(DateTime start, DateTime end, String? barberId) async {
    try {
      var query = _client
          .from('transactions')
          .select('payment_method')
          .gte('created_at', start.toIso8601String())
          .lte('created_at', end.toIso8601String())
          .eq('status', 'completed'); // FIX: Solo ventas completadas

      final response = await query;
      final transactions = List<Map<String, dynamic>>.from(response);
      final methods = <String, int>{};

      for (final t in transactions) {
        final rawMethod = t['payment_method'];
        final method = rawMethod == 'cash' ? 'Efectivo'
            : rawMethod == 'card' ? 'Tarjeta'
            : rawMethod == 'mixed' || rawMethod == 'mixto' ? 'Mixto'
            : 'Transferencia';
            
        methods[method] = (methods[method] ?? 0) + 1;
      }
      return methods;
    } catch (e) {
      print('Error al obtener métodos de pago: $e');
      return {};
    }
  }
}