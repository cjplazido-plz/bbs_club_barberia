import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardRepository {
  final _client = Supabase.instance.client;

  Future<double> getTodaySales() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    try {
      final response = await _client
          .from('transactions')
          .select()
          .gte('created_at', startOfDay.toIso8601String())
          .lt('created_at', endOfDay.toIso8601String());
      final transactions = List<Map<String, dynamic>>.from(response);
      double total = 0.0;
      for (final t in transactions) {
        total = total + (t['total'] as num).toDouble();
      }
      return total;
    } catch (e) {
      print('Error al obtener ventas del día: $e');
      return 0.0;
    }
  }

  Future<List<Map<String, dynamic>>> getWeekSales() async {
    final today = DateTime.now();
    final weekData = <Map<String, dynamic>>[];
    for (int i = 6; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      try {
        final response = await _client
            .from('transactions')
            .select()
            .gte('created_at', startOfDay.toIso8601String())
            .lt('created_at', endOfDay.toIso8601String());
        final transactions = List<Map<String, dynamic>>.from(response);
        double total = 0.0;
        for (final t in transactions) {
          total = total + (t['total'] as num).toDouble();
        }
        final dayName = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'][date.weekday - 1];
        weekData.add({'day': dayName, 'total': total, 'count': transactions.length});
      } catch (e) {
        print('Error al obtener ventas del día $date: $e');
        weekData.add({'day': 'Error', 'total': 0.0, 'count': 0});
      }
    }
    return weekData;
  }

  Future<double> getMonthSales() async {
    final today = DateTime.now();
    final startOfMonth = DateTime(today.year, today.month, 1);
    try {
      final response = await _client
          .from('transactions')
          .select()
          .gte('created_at', startOfMonth.toIso8601String());
      final transactions = List<Map<String, dynamic>>.from(response);
      double total = 0.0;
      for (final t in transactions) {
        total = total + (t['total'] as num).toDouble();
      }
      return total;
    } catch (e) {
      print('Error al obtener ventas del mes: $e');
      return 0.0;
    }
  }

  Future<int> getTodayTransactionCount() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    try {
      final response = await _client
          .from('transactions')
          .select()
          .gte('created_at', startOfDay.toIso8601String())
          .lt('created_at', endOfDay.toIso8601String());
      return response.length;
    } catch (e) {
      print('Error al obtener conteo: $e');
      return 0;
    }
  }

  Future<List<Map<String, dynamic>>> getBarberRanking() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    try {
      final response = await _client
          .from('transactions')
          .select('*, transaction_items(*)')
          .gte('created_at', startOfDay.toIso8601String())
          .lt('created_at', endOfDay.toIso8601String());
      final transactions = List<Map<String, dynamic>>.from(response);
      final barberStats = <String, Map<String, dynamic>>{};
      for (final transaction in transactions) {
        final items = List<Map<String, dynamic>>.from(transaction['transaction_items'] ?? []);
        for (final item in items) {
          final barberName = item['barber_name'] ?? 'Sin barbero';
          if (!barberStats.containsKey(barberName)) {
            barberStats[barberName] = {'name': barberName, 'total': 0.0, 'services': 0};
          }
          final price = (item['price_at_moment'] as num).toDouble();
          final qty = item['quantity'] as int;
          final currentTotal = barberStats[barberName]!['total'] as double;
          barberStats[barberName]!['total'] = currentTotal + (price * qty);
          final currentServices = barberStats[barberName]!['services'] as int;
          barberStats[barberName]!['services'] = currentServices + qty;
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

  Future<List<Map<String, dynamic>>> getBarberCommissions() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    try {
      final response = await _client
          .from('transactions')
          .select('*, transaction_items(*)')
          .gte('created_at', startOfDay.toIso8601String())
          .lt('created_at', endOfDay.toIso8601String());
      final transactions = List<Map<String, dynamic>>.from(response);
      final barberCommissions = <String, double>{};
      for (final transaction in transactions) {
        final items = List<Map<String, dynamic>>.from(transaction['transaction_items'] ?? []);
        for (final item in items) {
          final barberName = item['barber_name'] ?? 'Sin barbero';
          final commission = (item['commission_earned'] as num).toDouble();
          barberCommissions[barberName] = (barberCommissions[barberName] ?? 0.0) + commission;
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

  Future<int> getTodayAppointments() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    try {
      final response = await _client
          .from('appointments')
          .select()
          .gte('appointment_date', startOfDay.toIso8601String())
          .lt('appointment_date', endOfDay.toIso8601String())
          .neq('status', 'cancelled');
      return response.length;
    } catch (e) {
      print('Error al obtener citas: $e');
      return 0;
    }
  }

  Future<Map<String, int>> getPaymentMethods() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    try {
      final response = await _client
          .from('transactions')
          .select()
          .gte('created_at', startOfDay.toIso8601String())
          .lt('created_at', endOfDay.toIso8601String());
      final transactions = List<Map<String, dynamic>>.from(response);
      final methods = <String, int>{};
      for (final t in transactions) {
        final method = t['payment_method'] == 'cash' ? 'Efectivo'
            : t['payment_method'] == 'card' ? 'Tarjeta'
            : 'Transferencia';
        final current = methods[method] ?? 0;
        methods[method] = current + 1;
      }
      return methods;
    } catch (e) {
      print('Error al obtener métodos de pago: $e');
      return {};
    }
  }
}