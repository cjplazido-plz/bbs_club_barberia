import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../repositories/dashboard_repository.dart';
import '../services/settings_service.dart';

class DashboardScreen extends StatefulWidget {
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with TickerProviderStateMixin {
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
  
  late AnimationController _mainController;
  late AnimationController _glowController;
  late List<Animation<double>> _cardAnimations;

  @override
  void initState() {
    super.initState();
    _mainController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    _glowController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat(reverse: true);
    
    _cardAnimations = List.generate(4, (index) {
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _mainController,
          curve: Interval(0.1 + index * 0.1, 0.6 + index * 0.1, curve: Curves.easeOutCubic),
        ),
      );
    });
    
    _loadData();
  }

  @override
  void dispose() {
    _mainController.dispose();
    _glowController.dispose();
    super.dispose();
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
    _mainController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Dashboard Premium', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          AnimatedBuilder(
            animation: _glowController,
            builder: (context, child) {
              return Container(
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withOpacity(_glowController.value * 0.5),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                  onPressed: _loadData,
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
          : RefreshIndicator(
              color: const Color(0xFF6366F1),
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSummaryCards(isDark),
                  const SizedBox(height: 24),
                  _buildWeekChart(isDark),
                  const SizedBox(height: 24),
                  _buildBarberRanking(isDark),
                  const SizedBox(height: 24),
                  _buildCommissions(isDark),
                  const SizedBox(height: 24),
                  _buildPaymentMethods(isDark),
                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCards(bool isDark) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      childAspectRatio: 1.45,
      children: [
        _buildPremiumCard('Ventas Hoy', SettingsService.formatCurrency(_todaySales), '💵', const Color(0xFF10B981), 0, isDark),
        _buildPremiumCard('Transacciones', '$_todayTransactions', '🧾', const Color(0xFF3B82F6), 1, isDark),
        _buildPremiumCard('Citas Hoy', '$_todayAppointments', '📅', const Color(0xFFF59E0B), 2, isDark),
        _buildPremiumCard('Ventas Mes', SettingsService.formatCurrency(_monthSales), '📈', const Color(0xFF8B5CF6), 3, isDark),
      ],
    );
  }

  Widget _buildPremiumCard(String title, String value, String icon, Color color, int index, bool isDark) {
    return AnimatedBuilder(
      animation: _cardAnimations[index],
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - _cardAnimations[index].value)),
          child: Opacity(
            opacity: _cardAnimations[index].value,
            child: child,
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF1E293B), const Color(0xFF1E293B).withOpacity(0.8)]
                : [Colors.white, Colors.white.withOpacity(0.9)],
          ),
          border: Border.all(color: color.withOpacity(0.2), width: 1),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 8)),
            BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color.withOpacity(0.2)),
                    ),
                    child: Text(icon, style: const TextStyle(fontSize: 22)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                    child: Text('+12%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.5)),
                  const SizedBox(height: 6),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: Duration(milliseconds: 1000 + index * 200),
                    curve: Curves.easeOutCubic,
                    builder: (context, val, child) {
                      return Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87));
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeekChart(bool isDark) {
    final maxSales = _weekSales.isEmpty ? 1.0 : _weekSales.map((e) => e['total'] as double).reduce((a, b) => a > b ? a : b);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: const Text('📊', style: TextStyle(fontSize: 18))),
                const SizedBox(width: 12),
                const Text('Ventas de la Semana', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxSales * 1.3,
                  barGroups: _weekSales.asMap().entries.map((entry) {
                    final index = entry.key;
                    final data = entry.value;
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: data['total'] as double,
                          gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF818CF8)], begin: Alignment.bottomCenter, end: Alignment.topCenter),
                          width: 18,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
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
                            return Padding(padding: const EdgeInsets.only(top: 8), child: Text(_weekSales[value.toInt()]['day'] as String, style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600])));
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: maxSales / 4, getDrawingHorizontalLine: (value) => FlLine(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1), strokeWidth: 1)),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarberRanking(bool isDark) {
    return _buildPremiumSection(
      isDark: isDark,
      title: '🏆 Ranking de Barberos (Hoy)',
      child: _barberRanking.isEmpty
          ? Center(child: Padding(padding: const EdgeInsets.all(20), child: Text('Sin ventas hoy', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey))))
          : Column(
              children: _barberRanking.asMap().entries.map((entry) {
                final index = entry.key;
                final barber = entry.value;
                final medals = ['🥇', '🥈', '🥉'];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A).withOpacity(0.5) : Colors.grey[50],
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: index == 0 ? const Color(0xFFF59E0B).withOpacity(0.3) : Colors.transparent),
                  ),
                  child: Row(
                    children: [
                      Text(index < 3 ? medals[index] : '${index + 1}', style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(barber['name'] as String, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)), Text('${barber['services']} servicios', style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]))])),
                      Text(SettingsService.formatCurrency(barber['total'] as double), style: TextStyle(color: const Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildCommissions(bool isDark) {
    return _buildPremiumSection(
      isDark: isDark,
      title: '💰 Comisiones del Día',
      child: _barberCommissions.isEmpty
          ? Center(child: Padding(padding: const EdgeInsets.all(20), child: Text('Sin comisiones hoy', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey))))
          : Column(
              children: _barberCommissions.map((barber) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: isDark ? const Color(0xFF0F172A).withOpacity(0.5) : Colors.grey[50], borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        CircleAvatar(backgroundColor: const Color(0xFF6366F1).withOpacity(0.15), child: Text((barber['name'] as String)[0].toUpperCase(), style: const TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold))),
                        const SizedBox(width: 12),
                        Expanded(child: Text(barber['name'] as String, style: TextStyle(fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black87))),
                        Text(SettingsService.formatCurrency(barber['commission'] as double), style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )).toList(),
            ),
    );
  }

  Widget _buildPaymentMethods(bool isDark) {
    return _buildPremiumSection(
      isDark: isDark,
      title: '💳 Métodos de Pago',
      child: _paymentMethods.isEmpty
          ? Center(child: Padding(padding: const EdgeInsets.all(20), child: Text('Sin transacciones hoy', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey))))
          : Column(
              children: _paymentMethods.entries.map((entry) {
                final icons = {'Efectivo': '💵', 'Tarjeta': '💳', 'Transferencia': '📱'};
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: isDark ? const Color(0xFF0F172A).withOpacity(0.5) : Colors.grey[50], borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    children: [
                      Text(icons[entry.key] ?? '💰', style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 12),
                      Text(entry.key, style: TextStyle(fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black87)),
                      const Spacer(),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.15), borderRadius: BorderRadius.circular(20)), child: Text('${entry.value} transacciones', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6366F1)))),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildPremiumSection({required bool isDark, required String title, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), const SizedBox(height: 16), child])),
    );
  }
}
