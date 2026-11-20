import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../repositories/dashboard_repository.dart';
import '../services/settings_service.dart';

class DashboardScreen extends StatefulWidget {
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _dashboardRepo = DashboardRepository();
  
  bool _isLoading = true;
  
  // --- FILTROS ---
  DateTimeRange _selectedDateRange = DateTimeRange(
    start: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day), 
    end: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)
  );
  String _activeQuickFilter = 'today'; 
  String _selectedBarberId = 'all';
  List<Map<String, dynamic>> _barbersList = []; 

  // --- DATOS DEL DASHBOARD ---
  double _totalSales = 0;
  int _totalTransactions = 0;
  int _totalAppointments = 0;
  double _averageTicket = 0;
  
  List<Map<String, dynamic>> _weekSales = [];
  List<Map<String, dynamic>> _barberRanking = [];
  List<Map<String, dynamic>> _barberCommissions = [];
  Map<String, int> _paymentMethods = {};

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      _barbersList = await _dashboardRepo.getBarbers();
    } catch (e) {
      debugPrint('Error cargando barberos: $e');
    }
    _loadData();
  }

  void _setQuickDate(String type) {
    final now = DateTime.now();
    setState(() {
      _activeQuickFilter = type;
      if (type == 'today') {
        _selectedDateRange = DateTimeRange(
          start: DateTime(now.year, now.month, now.day),
          end: DateTime(now.year, now.month, now.day),
        );
      } else if (type == 'week') {
        // FIX: Ahora filtra los últimos 7 días
        _selectedDateRange = DateTimeRange(
          start: DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7)),
          end: DateTime(now.year, now.month, now.day),
        );
      } else if (type == 'month') {
        // FIX: Ahora filtra los últimos 30 días
        _selectedDateRange = DateTimeRange(
          start: DateTime(now.year, now.month, now.day).subtract(const Duration(days: 30)),
          end: DateTime(now.year, now.month, now.day),
        );
      }
    });
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final rawStart = _selectedDateRange.start;
      final rawEnd = _selectedDateRange.end;
      
      final start = DateTime(rawStart.year, rawStart.month, rawStart.day);
      final end = DateTime(rawEnd.year, rawEnd.month, rawEnd.day).add(const Duration(days: 1)); 
      
      final barber = _selectedBarberId;

      final totalSales = await _dashboardRepo.getTotalSales(start, end, barber);
      final totalTransactions = await _dashboardRepo.getTransactionCount(start, end, barber);
      final appointments = await _dashboardRepo.getAppointmentsCount(start, end, barber);
      final weekSales = await _dashboardRepo.getWeekSales(start, end, barber);
      final barberRanking = await _dashboardRepo.getBarberRanking(start, end, barber);
      final barberCommissions = await _dashboardRepo.getBarberCommissions(start, end, barber);
      final paymentMethods = await _dashboardRepo.getPaymentMethods(start, end, barber);
      
      setState(() {
        _totalSales = totalSales;
        _totalTransactions = totalTransactions;
        _totalAppointments = appointments;
        _averageTicket = _totalTransactions > 0 ? (_totalSales / _totalTransactions) : 0.0;
        
        _weekSales = weekSales;
        _barberRanking = barberRanking;
        _barberCommissions = barberCommissions;
        _paymentMethods = paymentMethods;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error cargando dashboard: $e');
    }
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _selectedDateRange,
      builder: (c, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: Color(0xFF6366F1), surface: Color(0xFF1E293B))
        ), 
        child: child!
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
        _activeQuickFilter = 'custom'; 
      });
      _loadData();
    }
  }

  Widget _buildQuickDateChip(String label, String type) {
    final isSelected = _activeQuickFilter == type;
    return InkWell(
      onTap: () => _setQuickDate(type),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6366F1) : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? const Color(0xFF6366F1) : Colors.white10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white54,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
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
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1))) 
          : RefreshIndicator(
              color: const Color(0xFF6366F1), 
              onRefresh: _loadData, 
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(isDesktop ? 20 : 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, 
                  children: [
                    _buildFiltersBar(isDesktop),
                    const SizedBox(height: 16),
                    _buildSummaryCardsCompact(isDesktop),
                    const SizedBox(height: 16),
                    
                    if (isDesktop)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start, 
                        children: [
                          Expanded(flex: 2, child: _buildWeekChart()),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 1, 
                            child: Column(
                              children: [
                                _buildBarberRanking(), 
                                const SizedBox(height: 16), 
                                _buildPaymentMethodsChart()
                              ]
                            )
                          ),
                        ]
                      )
                    else ...[
                      _buildWeekChart(),
                      const SizedBox(height: 16),
                      _buildBarberRanking(),
                      const SizedBox(height: 16),
                      _buildCommissions(),
                      const SizedBox(height: 16),
                      _buildPaymentMethodsChart(),
                    ]
                  ]
                ),
              )
          ),
    );
  }

  Widget _buildFiltersBar(bool isDesktop) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B), 
        borderRadius: BorderRadius.circular(16), 
        border: Border.all(color: Colors.white.withOpacity(0.06)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // FILTRO UNIFICADO - mismo estilo que Reportes Avanzados (Período de Análisis)
          Row(
            children: const [
              Icon(Icons.calendar_month_rounded, color: Color(0xFF818CF8), size: 18),
              SizedBox(width: 8),
              Text('Período de Análisis', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                backgroundColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? const Color(0xFF6366F1) : Colors.transparent),
                foregroundColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? Colors.white : Colors.white54),
                side: WidgetStateProperty.all(BorderSide(color: Colors.white.withOpacity(0.1))),
              ),
              segments: const [
                ButtonSegment(value: 'today', label: Text('Hoy', style: TextStyle(fontSize: 11))),
                ButtonSegment(value: 'week', label: Text('Semana', style: TextStyle(fontSize: 11))),
                ButtonSegment(value: 'month', label: Text('Mes', style: TextStyle(fontSize: 11))),
              ],
              selected: {['today', 'week', 'month'].contains(_activeQuickFilter) ? _activeQuickFilter : 'today'},
              onSelectionChanged: (Set<String> v) { _setQuickDate(v.first); },
            ),
          ),
          const SizedBox(height: 12),
          
          LayoutBuilder(
            builder: (context, constraints) {
              final dateWidget = InkWell(
                onTap: _pickDateRange,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _activeQuickFilter == 'custom' ? const Color(0xFF6366F1) : Colors.white.withOpacity(0.08)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.date_range_rounded, color: _activeQuickFilter == 'custom' ? const Color(0xFF6366F1) : Colors.white38, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FittedBox(
                          alignment: Alignment.centerLeft,
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '${DateFormat('dd/MM/yyyy').format(_selectedDateRange.start)}  →  ${DateFormat('dd/MM/yyyy').format(_selectedDateRange.end)}',
                            style: TextStyle(color: _activeQuickFilter == 'custom' ? Colors.white : Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(_activeQuickFilter == 'custom' ? 'CAMBIAR' : 'EDITAR', style: const TextStyle(color: Color(0xFF818CF8), fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              );

              final barberWidget = Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedBarberId,
                    dropdownColor: const Color(0xFF1E293B),
                    icon: const Icon(Icons.person_search, color: Color(0xFF818CF8), size: 16),
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    items: [
                      const DropdownMenuItem(value: 'all', child: Text('Todos los Barberos')),
                      ..._barbersList.map((b) => DropdownMenuItem(value: b['id'].toString(), child: Text(b['name'].toString())))
                    ],
                    onChanged: (val) {
                      setState(() => _selectedBarberId = val ?? 'all');
                      _loadData();
                    },
                  ),
                ),
              );

              if (!isDesktop) {
                return Column(
                  children: [
                    dateWidget,
                    if (_barbersList.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      barberWidget,
                    ]
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: dateWidget),
                  if (_barbersList.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    barberWidget,
                  ]
                ],
              );
            }
          )
        ],
      ),
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
        _compactCard('Ventas del Periodo', SettingsService.formatCurrency(_totalSales), '💵', const Color(0xFF10B981)),
        _compactCard('Transacciones', '$_totalTransactions', '🧾', const Color(0xFF6366F1)),
        _compactCard('Ticket Promedio', SettingsService.formatCurrency(_averageTicket), '⚖️', const Color(0xFFF59E0B)),
        _compactCard('Citas', '$_totalAppointments', '📅', const Color(0xFF8B5CF6)),
      ],
    );
  }

  Widget _compactCard(String title, String value, String icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B), 
        borderRadius: BorderRadius.circular(14), 
        border: Border.all(color: Colors.white.withOpacity(0.06))
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, 
        mainAxisAlignment: MainAxisAlignment.spaceBetween, 
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, 
            children: [
              Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: Text(icon, style: const TextStyle(fontSize: 14))),
            ]
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start, 
            children: [
              Text(title, style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
            ]
          )
        ]
      ),
    );
  }

  Widget _buildWeekChart() {
    final maxVal = _weekSales.isEmpty 
        ? 0.0 
        : _weekSales.map((e) => (e['total'] as num).toDouble()).reduce((a, b) => a > b ? a : b);
    final maxY = maxVal == 0 ? 10.0 : maxVal * 1.3;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.06))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Text('📊 Ventas del Periodo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)), const Spacer(), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.15), borderRadius: BorderRadius.circular(20)), child: const Text('Rango Seleccionado', style: TextStyle(fontSize: 9, color: Color(0xFF818CF8), fontWeight: FontWeight.bold)))]),
        const SizedBox(height: 16),
        SizedBox(
          height: 160,
          child: _weekSales.isEmpty ? const Center(child: Text('Sin datos', style: TextStyle(color: Colors.white38, fontSize: 11))) : BarChart(BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxY,
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
      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.06))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('🏆 Top Barberos', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 12),
        if (_barberRanking.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Center(child: Text('Sin ventas en el periodo', style: TextStyle(color: Colors.white38, fontSize: 11)))) else ..._barberRanking.take(4).toList().asMap().entries.map((entry) {
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
      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.06))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('💰 Comisiones (Periodo)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 12),
        if (_barberCommissions.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Center(child: Text('Sin comisiones', style: TextStyle(color: Colors.white38, fontSize: 11)))) else ..._barberCommissions.map((barber) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
          CircleAvatar(radius: 12, backgroundColor: const Color(0xFF6366F1).withOpacity(0.15), child: Text((barber['name'] as String)[0].toUpperCase(), style: const TextStyle(color: Color(0xFF6366F1), fontSize: 10, fontWeight: FontWeight.bold))),
          const SizedBox(width: 8),
          Expanded(child: Text(barber['name'] as String, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600))),
          Text(SettingsService.formatCurrency((barber['commission'] as num).toDouble()), style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 11))
        ]))),
      ]),
    );
  }

  Widget _buildPaymentMethodsChart() {
    if (_paymentMethods.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.06))),
        child: const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('Sin transacciones', style: TextStyle(color: Colors.white38, fontSize: 11)))),
      );
    }

    int totalTx = _paymentMethods.values.reduce((a, b) => a + b);
    final colors = [const Color(0xFF10B981), const Color(0xFF6366F1), const Color(0xFFF59E0B), const Color(0xFF8B5CF6)];
    final icons = {'Efectivo': '💵', 'Tarjeta': '💳', 'Transferencia': '📱', 'Mixto': '🔀'};

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.06))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('💳 Métodos de Pago', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 16),
        SizedBox(
          height: 120,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 30,
              sections: _paymentMethods.entries.toList().asMap().entries.map((entry) {
                final index = entry.key;
                final mapEntry = entry.value;
                final percentage = (mapEntry.value / totalTx) * 100;
                return PieChartSectionData(
                  color: colors[index % colors.length],
                  value: mapEntry.value.toDouble(),
                  title: '${percentage.toStringAsFixed(0)}%',
                  radius: 40,
                  titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: _paymentMethods.entries.toList().asMap().entries.map((entry) {
            final index = entry.key;
            final mapEntry = entry.value;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: colors[index % colors.length], shape: BoxShape.circle)),
                const SizedBox(width: 4),
                Text('${icons[mapEntry.key] ?? ''} ${mapEntry.key}', style: const TextStyle(color: Colors.white70, fontSize: 10)),
              ],
            );
          }).toList(),
        )
      ]),
    );
  }
}