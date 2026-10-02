import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../repositories/dashboard_repository.dart';

class DashboardScreen extends StatefulWidget {
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _dashboardRepo = DashboardRepository();
  bool _isLoading = true;

  double _todaySales = 0;
  int _todayTransactions = 0;
  int _todayAppointments = 0;
  double _monthSales = 0;
  List<Map<String, dynamic>> _weekSales = [];
  List<Map<String, dynamic>> _barberRanking = [];
  List<Map<String, dynamic>> _barberCommissions = [];
  Map<String, int> _paymentMethods = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; });

    final todaySales = await _dashboardRepo.getTodaySales();
    final todayTransactions = await _dashboardRepo.getTodayTransactionCount();
    final todayAppointments = await _dashboardRepo.getTodayAppointments();
    final monthSales = await _dashboardRepo.getMonthSales();
    final weekSales = await _dashboardRepo.getWeekSales();
    final barberRanking = await _dashboardRepo.getBarberRanking();
    final barberCommissions = await _dashboardRepo.getBarberCommissions();
    final paymentMethods = await _dashboardRepo.getPaymentMethods();

    setState(() {
      _todaySales = todaySales;
      _todayTransactions = todayTransactions;
      _todayAppointments = todayAppointments;
      _monthSales = monthSales;
      _weekSales = weekSales;
      _barberRanking = barberRanking;
      _barberCommissions = barberCommissions;
      _paymentMethods = paymentMethods;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: Colors.indigo[700],
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Tarjetas de resumen
                  _buildSummaryCards(),
                  const SizedBox(height: 24),

                  // Gráfica de ventas semanales
                  _buildWeekChart(),
                  const SizedBox(height: 24),

                  // Ranking de barberos
                  _buildBarberRanking(),
                  const SizedBox(height: 24),

                  // Comisiones
                  _buildCommissions(),
                  const SizedBox(height: 24),

                  // Métodos de pago
                  _buildPaymentMethods(),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCards() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildSummaryCard('Ventas Hoy', '\$${_todaySales.toStringAsFixed(2)}', Icons.attach_money, Colors.green),
        _buildSummaryCard('Transacciones', '$_todayTransactions', Icons.receipt_long, Colors.blue),
        _buildSummaryCard('Citas Hoy', '$_todayAppointments', Icons.event, Colors.orange),
        _buildSummaryCard('Ventas Mes', '\$${_monthSales.toStringAsFixed(2)}', Icons.trending_up, Colors.purple),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 24),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                const SizedBox(height: 4),
                Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekChart() {
    final maxSales = _weekSales.isEmpty ? 1.0 : _weekSales.map((e) => e['total'] as double).reduce((a, b) => a > b ? a : b);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ventas de la Semana', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxSales * 1.2,
                  barGroups: _weekSales.asMap().entries.map((entry) {
                    final index = entry.key;
                    final data = entry.value;
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: data['total'] as double,
                          color: Colors.indigo,
                          width: 20,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    );
                  }).toList(),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() < _weekSales.length) {
                            return Text(_weekSales[value.toInt()]['day'] as String, style: const TextStyle(fontSize: 12));
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarberRanking() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🏆 Ranking de Barberos (Hoy)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (_barberRanking.isEmpty)
              const Center(child: Text('Sin ventas hoy', style: TextStyle(color: Colors.grey)))
            else
              ..._barberRanking.asMap().entries.map((entry) {
                final index = entry.key;
                final barber = entry.value;
                final medals = ['', '🥈', '🥉'];
                return ListTile(
                  leading: Text(index < 3 ? medals[index] : '${index + 1}', style: const TextStyle(fontSize: 24)),
                  title: Text(barber['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${barber['services']} servicios'),
                  trailing: Text('\$${(barber['total'] as double).toStringAsFixed(2)}', style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.bold, fontSize: 16)),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildCommissions() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('💰 Comisiones del Día', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (_barberCommissions.isEmpty)
              const Center(child: Text('Sin comisiones hoy', style: TextStyle(color: Colors.grey)))
            else
              ..._barberCommissions.map((barber) => ListTile(
                leading: CircleAvatar(backgroundColor: Colors.indigo[100], child: Text((barber['name'] as String)[0], style: TextStyle(color: Colors.indigo[700]))),
                title: Text(barber['name'] as String),
                trailing: Text('\$${(barber['commission'] as double).toStringAsFixed(2)}', style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.bold, fontSize: 16)),
              )),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethods() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('💳 Métodos de Pago', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (_paymentMethods.isEmpty)
              const Center(child: Text('Sin transacciones hoy', style: TextStyle(color: Colors.grey)))
            else
              ..._paymentMethods.entries.map((entry) {
                final icons = {'Efectivo': Icons.money, 'Tarjeta': Icons.credit_card, 'Transferencia': Icons.phone_android};
                final colors = {'Efectivo': Colors.green, 'Tarjeta': Colors.blue, 'Transferencia': Colors.orange};
                return ListTile(
                  leading: Icon(icons[entry.key] ?? Icons.payment, color: colors[entry.key]),
                  title: Text(entry.key),
                  trailing: Text('${entry.value} transacciones', style: const TextStyle(fontWeight: FontWeight.bold)),
                );
              }),
          ],
        ),
      ),
    );
  }
}