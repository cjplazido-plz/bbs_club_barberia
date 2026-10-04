import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../services/settings_service.dart';

class CommissionsScreen extends StatefulWidget {
  @override
  State<CommissionsScreen> createState() => _CommissionsScreenState();
}

class _CommissionsScreenState extends State<CommissionsScreen> {
  bool _isLoading = true;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  List<Map<String, dynamic>> _commissions = [];
  double _totalCommissions = 0;
  double _totalSales = 0;

  @override
  void initState() {
    super.initState();
    _loadCommissions();
  }

  Future<void> _loadCommissions() async {
    setState(() { _isLoading = true; });
    
    try {
      final startStr = _startDate.toIso8601String();
      final endStr = _endDate.add(const Duration(days: 1)).toIso8601String();

      print('📊 Cargando comisiones del $startStr al $endStr');

      final response = await Supabase.instance.client
          .from('transaction_items')
          .select('''
            barber_id,
            barber_name,
            price_at_moment,
            quantity,
            commission_earned,
            transactions!inner(created_at, status)
          ''')
          .eq('item_type', 'service')
          .gte('transactions.created_at', startStr)
          .lt('transactions.created_at', endStr)
          .eq('transactions.status', 'completed');

      final items = List<Map<String, dynamic>>.from(response);
      print('✅ ${items.length} items de servicios encontrados');

      Map<String, Map<String, dynamic>> barberMap = {};
      
      for (final item in items) {
        final barberId = item['barber_id'] ?? 'unknown';
        final barberName = item['barber_name'] ?? 'Desconocido';
        final price = (item['price_at_moment'] as num?)?.toDouble() ?? 0.0;
        final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
        final commission = (item['commission_earned'] as num?)?.toDouble() ?? 0.0;
        final totalItem = price * quantity;

        if (!barberMap.containsKey(barberId)) {
          barberMap[barberId] = {
            'barber_id': barberId,
            'barber_name': barberName,
            'total_sales': 0.0,
            'total_commission': 0.0,
            'services_count': 0,
          };
        }

        barberMap[barberId]!['total_sales'] = 
            (barberMap[barberId]!['total_sales'] as double) + totalItem;
        barberMap[barberId]!['total_commission'] = 
            (barberMap[barberId]!['total_commission'] as double) + commission;
        barberMap[barberId]!['services_count'] = 
            (barberMap[barberId]!['services_count'] as int) + quantity;
      }

      final commissions = barberMap.values.toList();
      commissions.sort((a, b) => 
          (b['total_commission'] as double).compareTo(a['total_commission'] as double));

      final totalCommissions = commissions.fold(0.0, 
          (sum, c) => sum + (c['total_commission'] as double));
      final totalSales = commissions.fold(0.0, 
          (sum, c) => sum + (c['total_sales'] as double));

      setState(() {
        _commissions = commissions;
        _totalCommissions = totalCommissions;
        _totalSales = totalSales;
        _isLoading = false;
      });

      print('💰 Total comisiones: ${SettingsService.formatCurrency(totalCommissions)}');
    } catch (e) {
      print('❌ Error al cargar comisiones: $e');
      setState(() { _isLoading = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _selectDateRange() async {
    final initialDateRange = DateTimeRange(start: _startDate, end: _endDate);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: initialDateRange,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: Colors.indigo[700]!,
            onPrimary: Colors.white,
            onSurface: Colors.black,
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadCommissions();
    }
  }

  void _setQuickFilter(String period) {
    final now = DateTime.now();
    DateTime start;
    
    switch (period) {
      case 'today':
        start = DateTime(now.year, now.month, now.day);
        break;
      case 'week':
        start = now.subtract(Duration(days: now.weekday - 1));
        start = DateTime(start.year, start.month, start.day);
        break;
      case 'month':
        start = DateTime(now.year, now.month, 1);
        break;
      case 'last_month':
        start = DateTime(now.year, now.month - 1, 1);
        _endDate = DateTime(now.year, now.month, 0);
        break;
      default:
        start = now.subtract(const Duration(days: 30));
    }
    
    setState(() {
      _startDate = start;
      if (period != 'last_month') _endDate = now;
    });
    _loadCommissions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('💰 Comisiones por Barbero'),
        backgroundColor: Colors.indigo[700],
        actions: [
          IconButton(
            icon: const Text('🔄', style: TextStyle(fontSize: 20)),
            tooltip: 'Actualizar',
            onPressed: _loadCommissions,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.indigo[50],
            child: Column(
              children: [
                Row(
                  children: [
                    const Text('📅', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${DateFormat('dd/MM/yyyy').format(_startDate)} - ${DateFormat('dd/MM/yyyy').format(_endDate)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _selectDateRange,
                      icon: const Text('📆', style: TextStyle(fontSize: 16)),
                      label: const Text('Rango'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo[700],
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildFilterChip('Hoy', 'today'),
                    _buildFilterChip('Esta semana', 'week'),
                    _buildFilterChip('Este mes', 'month'),
                    _buildFilterChip('Mes anterior', 'last_month'),
                    _buildFilterChip('Últimos 30 días', 'last_30'),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _commissions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('💰', style: TextStyle(fontSize: 64)),
                            const SizedBox(height: 16),
                            Text(
                              'No hay comisiones en este período',
                              style: TextStyle(color: Colors.grey[400], fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _buildSummaryCards(),
                          const SizedBox(height: 16),
                          const Text(
                            'Detalle por Barbero',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          ..._commissions.asMap().entries.map((entry) {
                            final index = entry.key;
                            final barber = entry.value;
                            return _buildBarberCard(barber, index + 1);
                          }),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String period) {
    final isSelected = _isPeriodSelected(period);
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: isSelected,
      onSelected: (selected) => _setQuickFilter(period),
      backgroundColor: Colors.white,
      selectedColor: Colors.indigo[100],
      checkmarkColor: Colors.indigo[700],
      labelStyle: TextStyle(
        color: isSelected ? Colors.indigo[700] : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  bool _isPeriodSelected(String period) {
    final now = DateTime.now();
    switch (period) {
      case 'today':
        return _startDate.year == now.year && 
               _startDate.month == now.month && 
               _startDate.day == now.day;
      case 'week':
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        return _startDate.year == weekStart.year && 
               _startDate.month == weekStart.month && 
               _startDate.day == weekStart.day;
      case 'month':
        return _startDate.year == now.year && 
               _startDate.month == now.month && 
               _startDate.day == 1;
      case 'last_month':
        return _startDate.year == now.year && 
               _startDate.month == now.month - 1 && 
               _startDate.day == 1;
      case 'last_30':
        final thirtyDaysAgo = now.subtract(const Duration(days: 30));
        return _startDate.year == thirtyDaysAgo.year && 
               _startDate.month == thirtyDaysAgo.month && 
               _startDate.day == thirtyDaysAgo.day;
      default:
        return false;
    }
  }

  Widget _buildSummaryCards() {
    return Row(
      children: [
        Expanded(
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('💵 Total Ventas', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    SettingsService.formatCurrency(_totalSales),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('💰 Total Comisiones', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    SettingsService.formatCurrency(_totalCommissions),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBarberCard(Map<String, dynamic> barber, int position) {
    final barberName = barber['barber_name'] as String;
    final totalSales = barber['total_sales'] as double;
    final totalCommission = barber['total_commission'] as double;
    final servicesCount = barber['services_count'] as int;
    final commissionRate = totalSales > 0 ? (totalCommission / totalSales * 100) : 0.0;

    final medals = ['🥇', '🥈', '🥉'];
    final medal = position <= 3 ? medals[position - 1] : '$position';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(medal, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        barberName,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '$servicesCount servicios realizados',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.indigo[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${commissionRate.toStringAsFixed(1)}%',
                    style: TextStyle(color: Colors.indigo[700], fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Ventas', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    Text(
                      SettingsService.formatCurrency(totalSales),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Comisión a pagar', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    Text(
                      SettingsService.formatCurrency(totalCommission),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}