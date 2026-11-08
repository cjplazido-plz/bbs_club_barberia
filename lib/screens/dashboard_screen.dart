import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../repositories/dashboard_repository.dart';
import '../services/settings_service.dart';

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
    setState(() => _isLoading = true);
    try {
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
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 800;
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20), onPressed: () => Navigator.pop(context)),
        title: const Text('Dashboard Premium', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
        centerTitle: true,
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 20), onPressed: _loadData)],
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1))) : RefreshIndicator(color: const Color(0xFF6366F1), onRefresh: _loadData, child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(isDesktop ? 20 : 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildSummaryCardsCompact(isDesktop),
          const SizedBox(height: 16),
          if (isDesktop)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 2, child: _buildWeekChart()),
              const SizedBox(width: 16),
              Expanded(flex: 1, child: Column(children: [_buildBarberRanking(), const SizedBox(height: 16), _buildPaymentMethods()])),
            ])
          else ...[
            _buildWeekChart(),
            const SizedBox(height: 16),
            _buildBarberRanking(),
            const SizedBox(height: 16),
            _buildCommissions(),
            const SizedBox(height: 16),
            _buildPaymentMethods(),
          ]
        ]),
      )),
    );
  }

  Widget _buildSummaryCardsCompact(bool isDesktop) {
    return GridView.count(
      crossAxisCount: isDesktop ? 4 : 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: isDesktop ? 1.6 : 1.7,
      children: [
        _compactCard('Ventas Hoy', SettingsService.formatCurrency(_todaySales), '💵', const Color(0xFF10B981)),
        _compactCard('Transacciones', '$_todayTransactions', '🧾', const Color(0xFF6366F1)),
        _compactCard('Citas Hoy', '$_todayAppointments', '📅', const Color(0xFFF59E0B)),
        _compactCard('Ventas Mes', SettingsService.formatCurrency(_monthSales), '📈', const Color(0xFF8B5CF6)),
      ],
    );
  }

  Widget _compactCard(String title, String value, String icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withOpacity(0.06))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: Text(icon, style: const TextStyle(fontSize: 14))),
          Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: const Text('+12%', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFF10B981)))),
        ]),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
        ])
      ]),
    );
  }

  Widget _buildWeekChart() {
    final maxSales = _weekSales.isEmpty ? 1.0 : _weekSales.map((e) => (e['total'] as num).toDouble()).reduce((a, b) => a > b ? a : b);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withOpacity(0.06))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Text('📊 Ventas Semana', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)), const Spacer(), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.15), borderRadius: BorderRadius.circular(20)), child: const Text('7 días', style: TextStyle(fontSize: 9, color: Color(0xFF818CF8), fontWeight: FontWeight.bold)))]),
        const SizedBox(height: 16),
        SizedBox(
          height: 140,
          child: _weekSales.isEmpty ? const Center(child: Text('Sin datos', style: TextStyle(color: Colors.white38, fontSize: 11))) : BarChart(BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxSales * 1.3,
            barGroups: _weekSales.asMap().entries.map((entry) {
              final index = entry.key;
              final data = entry.value;
              return BarChartGroupData(x: index, barRods: [BarChartRodData(toY: (data['total'] as num).toDouble(), color: const Color(0xFF6366F1), width: 14, borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))]);
            }).toList(),
            titlesData: FlTitlesData(
              show: true,
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22, getTitlesWidget: (value, meta) { if (value.toInt() < _weekSales.length) { return Padding(padding: const EdgeInsets.only(top: 4), child: Text(_weekSales[value.toInt()]['day'] as String, style: const TextStyle(fontSize: 9, color: Colors.white54))); } return const SizedBox.shrink(); })),
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: FlGridData(show: false),
            borderData: FlBorderData(show: false),
          )),
        ),
      ]),
    );
  }

  Widget _buildBarberRanking() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withOpacity(0.06))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('🏆 Ranking Barberos (Hoy)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 12),
        if (_barberRanking.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Center(child: Text('Sin ventas hoy', style: TextStyle(color: Colors.white38, fontSize: 11)))) else ..._barberRanking.take(5).toList().asMap().entries.map((entry) {
          final index = entry.key;
          final barber = entry.value;
          final medals = ['🥇', '🥈', '🥉'];
          return Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
            Text(index < 3 ? medals[index] : '${index + 1}', style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(barber['name'] as String, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text('${barber['services']} servicios', style: const TextStyle(color: Colors.white38, fontSize: 9))
            ])),
            Text(SettingsService.formatCurrency((barber['total'] as num).toDouble()), style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 11))
          ]));
        }),
      ]),
    );
  }

  Widget _buildCommissions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withOpacity(0.06))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('💰 Comisiones del Día', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 12),
        if (_barberCommissions.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Center(child: Text('Sin comisiones hoy', style: TextStyle(color: Colors.white38, fontSize: 11)))) else ..._barberCommissions.map((barber) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
          CircleAvatar(radius: 12, backgroundColor: const Color(0xFF6366F1).withOpacity(0.15), child: Text((barber['name'] as String)[0].toUpperCase(), style: const TextStyle(color: Color(0xFF6366F1), fontSize: 10, fontWeight: FontWeight.bold))),
          const SizedBox(width: 8),
          Expanded(child: Text(barber['name'] as String, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600))),
          Text(SettingsService.formatCurrency((barber['commission'] as num).toDouble()), style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 11))
        ]))),
      ]),
    );
  }

  Widget _buildPaymentMethods() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withOpacity(0.06))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('💳 Métodos de Pago', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 12),
        if (_paymentMethods.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Center(child: Text('Sin transacciones hoy', style: TextStyle(color: Colors.white38, fontSize: 11)))) else ..._paymentMethods.entries.map((entry) {
          final icons = {'Efectivo': '💵', 'Tarjeta': '💳', 'Transferencia': '📱'};
          return Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
            Text(icons[entry.key] ?? '💰', style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 8),
            Expanded(child: Text(entry.key, style: const TextStyle(color: Colors.white, fontSize: 11))),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.15), borderRadius: BorderRadius.circular(20)), child: Text('${entry.value}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
          ]));
        }),
      ]),
    );
  }
}
