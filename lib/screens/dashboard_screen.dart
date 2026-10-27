import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/settings_service.dart';

class DashboardScreen extends StatefulWidget {
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  double _ventasHoy = 0;
  int _transaccionesHoy = 0;
  int _citasHoy = 0;
  double _ventasMes = 0;
  final List<double> _weekValues = List.filled(7, 0);
  final List<String> _weekLabels = List.filled(7, '');
  List<Map<String, dynamic>> _ranking = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; });
    try {
      final now = DateTime.now();
      final startToday = DateTime(now.year, now.month, now.day);
      final endToday = startToday.add(const Duration(days: 1));
      final startMonth = DateTime(now.year, now.month, 1);
      final startWeek = startToday.subtract(const Duration(days: 6));

      final todayRes = await Supabase.instance.client
          .from('transactions').select('total')
          .eq('status', 'completed')
          .gte('created_at', startToday.toIso8601String())
          .lt('created_at', endToday.toIso8601String());
      _transaccionesHoy = todayRes.length;
      _ventasHoy = todayRes.fold(0.0, (s, r) => s + ((r['total'] as num?)?.toDouble() ?? 0.0));

      final monthRes = await Supabase.instance.client
          .from('transactions').select('total')
          .eq('status', 'completed')
          .gte('created_at', startMonth.toIso8601String());
      _ventasMes = monthRes.fold(0.0, (s, r) => s + ((r['total'] as num?)?.toDouble() ?? 0.0));

      final citasRes = await Supabase.instance.client
          .from('appointments').select('id')
          .gte('appointment_date', startToday.toIso8601String())
          .lt('appointment_date', endToday.toIso8601String())
          .neq('status', 'cancelled');
      _citasHoy = citasRes.length;

      final weekRes = await Supabase.instance.client
          .from('transactions').select('total, created_at')
          .eq('status', 'completed')
          .gte('created_at', startWeek.toIso8601String());
      for (int i = 0; i < 7; i++) {
        final day = startWeek.add(Duration(days: i));
        _weekLabels[i] = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'][(day.weekday - 1) % 7];
        final dayStr = DateFormat('yyyy-MM-dd').format(day);
        double sum = 0;
        for (final r in weekRes) {
          final created = DateTime.parse(r['created_at'].toString());
          if (DateFormat('yyyy-MM-dd').format(created) == dayStr) {
            sum += (r['total'] as num?)?.toDouble() ?? 0.0;
          }
        }
        _weekValues[i] = sum;
      }

      final rankStart = now.subtract(const Duration(days: 30));
      final rankRes = await Supabase.instance.client
          .from('transaction_items')
          .select('barber_name, commission_earned, quantity, transactions!inner(created_at, status)')
          .eq('item_type', 'service')
          .gte('transactions.created_at', rankStart.toIso8601String())
          .eq('transactions.status', 'completed');
      final map = <String, Map<String, dynamic>>{};
      for (final item in rankRes) {
        final name = (item['barber_name'] ?? 'Sin barbero').toString();
        final commission = (item['commission_earned'] as num?)?.toDouble() ?? 0.0;
        final qty = (item['quantity'] as num?)?.toInt() ?? 1;
        map.putIfAbsent(name, () => {'name': name, 'commission': 0.0, 'services': 0});
        map[name]!['commission'] = (map[name]!['commission'] as double) + commission;
        map[name]!['services'] = (map[name]!['services'] as int) + qty;
      }
      _ranking = map.values.toList()..sort((a, b) => (b['commission'] as double).compareTo(a['commission'] as double));
      if (_ranking.length > 5) _ranking = _ranking.sublist(0, 5);
    } catch (e) {
      print('Error al cargar dashboard: $e');
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  String _compact(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}k';
    return v.toStringAsFixed(0);
  }

Widget _summaryCard(String label, String value, IconData icon, Color color) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return Card(
    color: isDark ? const Color(0xFF1E293B) : Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ],
      ),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final double maxWeek = _weekValues.reduce((a, b) => a > b ? a : b);
    final double maxY = maxWeek < 1000 ? 1000 : maxWeek * 1.2;
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.dashboard, size: 22),
            SizedBox(width: 8),
            Expanded(child: Text('Dashboard', overflow: TextOverflow.ellipsis)),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), tooltip: 'Actualizar', onPressed: _loadData),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 2.5,  // ← Cambiado de 1.7 a 2.5
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      children: [
                        _summaryCard('Ventas Hoy', SettingsService.formatCurrency(_ventasHoy), Icons.payments, Colors.green),
                        _summaryCard('Transacciones', '$_transaccionesHoy', Icons.receipt_long, Colors.blue),
                        _summaryCard('Citas Hoy', '$_citasHoy', Icons.event, Colors.orange),
                        _summaryCard('Ventas Mes', SettingsService.formatCurrency(_ventasMes), Icons.trending_up, Colors.purple),
                      ],
                    ),
                const SizedBox(height: 16),
                Card(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ventas de la Semana', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 200,
                          child: BarChart(
                            BarChartData(
                              alignment: BarChartAlignment.spaceAround,
                              maxY: maxY,
                              barTouchData: BarTouchData(enabled: false),
                              gridData: const FlGridData(show: true, drawVerticalLine: false),
                              borderData: FlBorderData(show: false),
                              titlesData: FlTitlesData(
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 40,
                                    getTitlesWidget: (v, m) => Text(_compact(v), style: const TextStyle(fontSize: 10)),
                                  ),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (v, m) => Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(_weekLabels[v.toInt().clamp(0, 6)], style: const TextStyle(fontSize: 10)),
                                    ),
                                  ),
                                ),
                              ),
                              barGroups: [
                                for (int i = 0; i < 7; i++)
                                  BarChartGroupData(
                                    x: i,
                                    barRods: [
                                      BarChartRodData(
                                        toY: _weekValues[i],
                                        color: const Color(0xFF6366F1),
                                        width: 14,
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ranking de Barberos (30 días)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                        const SizedBox(height: 8),
                        ..._ranking.asMap().entries.map((entry) {
                          final i = entry.key;
                          final r = entry.value;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: isDark ? const Color(0xFF312E81) : Colors.indigo[100],
                              child: Text('${i + 1}', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF818CF8) : Colors.indigo[700])),
                            ),
                            title: Text(r['name'], maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
                            subtitle: Text('${r['services']} servicios', style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                            trailing: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(SettingsService.formatCurrency(r['commission']), maxLines: 1, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.green[300] : Colors.green[700])),
                            ),
                          );
                        }),
                        if (_ranking.isEmpty)
                          Padding(padding: const EdgeInsets.all(8), child: Text('Sin datos de comisiones aún', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}