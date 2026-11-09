// lib/screens/advanced_reports_screen.dart - FINAL CON FILTRO FECHAS + LOGO COLORES READY
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:intl/intl.dart';
import '../services/settings_service.dart';
import '../services/ticket_config_service.dart';
import 'dart:typed_data';

class AdvancedReportsScreen extends StatefulWidget {
  @override
  State<AdvancedReportsScreen> createState() => _AdvancedReportsScreenState();
}

class _AdvancedReportsScreenState extends State<AdvancedReportsScreen> {
  bool _isLoading = true;
  String _selectedPeriod = 'month';
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  double _totalSales = 0;
  double _totalTransactions = 0;
  double _averageTicket = 0;
  List<Map<String, dynamic>> _salesByDay = [];
  List<Map<String, dynamic>> _salesByBarber = [];
  List<Map<String, dynamic>> _salesByService = [];
  List<Map<String, dynamic>> _paymentMethods = [];
  // FILTROS NUEVOS
  String _filterBarber = 'all';
  String _filterService = 'all';
  String _filterMethod = 'all';
  List<String> _allBarbers = [];
  List<String> _allServices = [];
  List<Map<String, dynamic>> _allTransactions = [];
  List<Map<String, dynamic>> _filteredDetail = []; // detalle filtrado: servicio x barbero

  @override
  void initState() {
    super.initState();
    _loadReportData();
  }

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (ctx, child) => Theme(data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: Color(0xFF6366F1), surface: Color(0xFF1E293B))), child: child!),
    );
    if (range != null) {
      setState(() { _startDate = range.start; _endDate = range.end; _selectedPeriod = 'custom'; });
      _loadReportData();
    }
  }

  Future<void> _loadReportData() async {
    setState(() => _isLoading = true);
    try {
      final startStr = _startDate.toIso8601String();
      final endStr = _endDate.add(const Duration(days: 1)).toIso8601String();
      final transactions = await Supabase.instance.client.from('transactions').select('*').gte('created_at', startStr).lte('created_at', endStr).eq('status', 'completed');
      var transList = List<Map<String, dynamic>>.from(transactions);
      // Cargar barberos distintos para el dropdown (siempre de todo el periodo, no del filtrado)
      final barbersSet = <String>{};
      for (final tr in transList) { final b = (tr['barber_name'] ?? '').toString(); if (b.isNotEmpty) barbersSet.add(b); }
      _allBarbers = barbersSet.toList()..sort();
      // Filtro barbero + metodo (sobre transacciones)
      if (_filterBarber != 'all') transList = transList.where((tr) => (tr['barber_name'] ?? '').toString() == _filterBarber).toList();
      if (_filterMethod != 'all') transList = transList.where((tr) => (tr['payment_method'] ?? '').toString() == _filterMethod).toList();
      _allTransactions = List<Map<String, dynamic>>.from(transList);
      // Items para servicios + filtro servicio
      List<Map<String, dynamic>> itemList = [];
      Map<String, Map<String, dynamic>> transById = { for (final tr in transList) (tr['id'].toString()): tr };
      if (transList.isNotEmpty) {
        final items = await Supabase.instance.client.from('transaction_items').select('transaction_id, service_name, product_name, quantity, price_at_moment, barber_name, barber_id').inFilter('transaction_id', transList.map((t) => t['id']).toList());
        itemList = List<Map<String, dynamic>>.from(items);
        final svcSet = <String>{};
        for (final it in itemList) { final n = (it['service_name'] ?? it['product_name'] ?? '').toString(); if (n.isNotEmpty) svcSet.add(n); }
        _allServices = svcSet.toList()..sort();
      } else { _allServices = []; }
      // Si hay filtro de servicio, recalcular totales SOLO con ese servicio (no el total de la venta completa)
      double totalSalesCalc;
      double totalTransCalc;
      if (_filterService != 'all') {
        final filteredItems = itemList.where((it) => (it['service_name'] ?? it['product_name'] ?? '').toString() == _filterService).toList();
        totalSalesCalc = filteredItems.fold(0.0, (s, it) => s + (((it['price_at_moment'] as num?)?.toDouble() ?? 0.0) * ((it['quantity'] as num?)?.toInt() ?? 1)));
        final ids = filteredItems.map((it) => it['transaction_id'].toString()).toSet();
        totalTransCalc = ids.length.toDouble();
        // Para ventas por dia / barbero / servicio, usar solo items filtrados
        _filteredDetail = filteredItems.map((it) {
          final tr = transById[it['transaction_id'].toString()];
          return {'service': _filterService, 'barber': (it['barber_name'] ?? tr?['barber_name'] ?? 'Sin barbero').toString(), 'qty': (it['quantity'] as num?)?.toInt() ?? 1, 'total': (((it['price_at_moment'] as num?)?.toDouble() ?? 0.0) * ((it['quantity'] as num?)?.toInt() ?? 1)), 'date': tr?['created_at']};
        }).toList();
        // Reemplazar transList por solo las que tienen ese servicio para los graficos por dia/barbero
        transList = transList.where((tr) => ids.contains(tr['id'].toString())).toList();
        // Y recalcular salesByDay con el monto del servicio, no el total de la venta
        Map<String, double> salesByDayMapTmp = {};
        for (final it in filteredItems) {
          final tr = transById[it['transaction_id'].toString()];
          if (tr == null) continue;
          final date = DateTime.parse(tr['created_at']);
          final key = '${date.day}/${date.month}';
          final v = (((it['price_at_moment'] as num?)?.toDouble() ?? 0.0) * ((it['quantity'] as num?)?.toInt() ?? 1));
          salesByDayMapTmp[key] = (salesByDayMapTmp[key] ?? 0.0) + v;
        }
        _salesByDay = salesByDayMapTmp.entries.map((e) => {'day': e.key, 'total': e.value}).toList();
        Map<String, double> salesByBarberMapTmp = {};
        for (final it in filteredItems) {
          final tr = transById[it['transaction_id'].toString()];
          final b = (it['barber_name'] ?? tr?['barber_name'] ?? 'Sin barbero').toString();
          final v = (((it['price_at_moment'] as num?)?.toDouble() ?? 0.0) * ((it['quantity'] as num?)?.toInt() ?? 1));
          salesByBarberMapTmp[b] = (salesByBarberMapTmp[b] ?? 0.0) + v;
        }
        _salesByBarber = salesByBarberMapTmp.entries.map((e) => {'barber': e.key, 'total': e.value}).toList();
        Map<String, double> payTmp = {};
        for (final tr in transList) { final m = (tr['payment_method'] ?? 'unknown').toString(); payTmp[m] = (payTmp[m] ?? 0.0) + ((tr['total'] as num?)?.toDouble() ?? 0.0); }
        _paymentMethods = payTmp.entries.map((e) => {'method': e.key, 'total': e.value}).toList();
        _totalSales = totalSalesCalc;
        _totalTransactions = totalTransCalc;
        _averageTicket = _totalTransactions > 0 ? _totalSales / _totalTransactions : 0.0;
        // Servicios: solo el filtrado
        final qty = filteredItems.fold<int>(0, (s, it) => s + ((it['quantity'] as num?)?.toInt() ?? 1));
        _salesByService = [{'name': _filterService, 'quantity': qty, 'total': totalSalesCalc}];
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      // Sin filtro servicio: calculo normal
      _totalSales = transList.fold(0.0, (sum, t) => sum + ((t['total'] as num?)?.toDouble() ?? 0.0));
      _totalTransactions = transList.length.toDouble();
      _averageTicket = _totalTransactions > 0 ? _totalSales / _totalTransactions : 0.0;

      Map<String, double> salesByDayMap = {};
      for (final t in transList) {
        final date = DateTime.parse(t['created_at']);
        final dateKey = '${date.day}/${date.month}';
        salesByDayMap[dateKey] = (salesByDayMap[dateKey] ?? 0.0) + ((t['total'] as num?)?.toDouble() ?? 0.0);
      }
      _salesByDay = salesByDayMap.entries.map((e) => {'day': e.key, 'total': e.value}).toList();

      Map<String, double> salesByBarberMap = {};
      for (final t in transList) {
        final barber = t['barber_name'] ?? 'Sin barbero';
        salesByBarberMap[barber] = (salesByBarberMap[barber] ?? 0.0) + ((t['total'] as num?)?.toDouble() ?? 0.0);
      }
      _salesByBarber = salesByBarberMap.entries.map((e) => {'barber': e.key, 'total': e.value}).toList();

      Map<String, double> paymentMap = {};
      for (final t in transList) {
        final method = t['payment_method'] ?? 'unknown';
        paymentMap[method] = (paymentMap[method] ?? 0.0) + ((t['total'] as num?)?.toDouble() ?? 0.0);
      }
      _paymentMethods = paymentMap.entries.map((e) => {'method': e.key, 'total': e.value}).toList();

      if (transList.isNotEmpty) {
        // itemList ya cargado arriba (con barber y transaction_id)
        Map<String, Map<String, dynamic>> serviceMap = {};
        _filteredDetail = [];
        for (final item in itemList) {
          final name = item['service_name'] ?? item['product_name'] ?? 'Desconocido';
          final qty = (item['quantity'] as num?)?.toInt() ?? 1;
          final price = (item['price_at_moment'] as num?)?.toDouble() ?? 0.0;
          if (!serviceMap.containsKey(name)) serviceMap[name] = {'name': name, 'quantity': 0, 'total': 0.0};
          serviceMap[name]!['quantity'] = (serviceMap[name]!['quantity'] as int) + qty;
          serviceMap[name]!['total'] = (serviceMap[name]!['total'] as double) + (price * qty);
          // detalle: servicio x barbero
          final tr = transById[item['transaction_id'].toString()];
          _filteredDetail.add({'service': name, 'barber': (item['barber_name'] ?? tr?['barber_name'] ?? 'Sin barbero').toString(), 'qty': qty, 'total': price * qty, 'date': tr?['created_at']});
        }
        _salesByService = serviceMap.values.toList();
        _salesByService.sort((a, b) => (b['total'] as double).compareTo((a['total'] as double)));
      } else { _salesByService = []; _filteredDetail = []; }
      if (mounted) setState(() => _isLoading = false);
    } catch (e) { print('Error: $e'); if (mounted) setState(() => _isLoading = false); }
  }

  void _clearFilters() { setState(() { _filterBarber = 'all'; _filterService = 'all'; _filterMethod = 'all'; }); _loadReportData(); }
  String get _filterLabel {
    final parts = <String>[];
    if (_filterBarber != 'all') parts.add('Barbero: $_filterBarber');
    if (_filterService != 'all') parts.add('Servicio: $_filterService');
    if (_filterMethod != 'all') parts.add('Pago: ${_formatMethod(_filterMethod)}');
    return parts.isEmpty ? 'Sin filtros - todo el periodo' : parts.join(' • ');
  }
  String _formatMethod(String m) { switch (m) { case 'cash': return 'Efectivo'; case 'transfer': return 'Transferencia'; case 'card': return 'Tarjeta'; case 'debito': return 'Débito'; case 'mixto': return 'Mixto'; default: return m; } }

  void _setPeriod(String period) {
    setState(() => _selectedPeriod = period);
    final now = DateTime.now();
    if (period == 'week') _startDate = now.subtract(const Duration(days: 7));
    if (period == 'month') _startDate = now.subtract(const Duration(days: 30));
    if (period == 'year') _startDate = now.subtract(const Duration(days: 365));
    _endDate = now;
    _loadReportData();
  }

  Future<void> _exportToPDF() async {
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(pageFormat: PdfPageFormat.a4, build: (c) => [
      pw.Header(level: 0, child: pw.Text('Reporte BBS Club - ${TicketConfigService.nombreLocal}', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold))),
      pw.Text('Período: ${DateFormat('dd/MM/yyyy').format(_startDate)} - ${DateFormat('dd/MM/yyyy').format(_endDate)} | Filtros: $_filterLabel', style: const pw.TextStyle(fontSize: 11)),
      pw.SizedBox(height: 10),
      pw.TableHelper.fromTextArray(headers: ['Métrica','Valor'], data: [
        ['Total Ventas', SettingsService.formatCurrency(_totalSales)],
        ['Transacciones', '${_totalTransactions.toInt()}'],
        ['Ticket Promedio', SettingsService.formatCurrency(_averageTicket)],
      ]),
      pw.SizedBox(height: 16),
      pw.Header(level: 1, child: pw.Text('Ventas por Barbero')),
      pw.TableHelper.fromTextArray(headers: ['Barbero','Total'], data: _salesByBarber.map((e)=> [e['barber'].toString(), SettingsService.formatCurrency((e['total'] as num).toDouble())]).toList()),
    ]));
    await Printing.layoutPdf(onLayout: (f) async => pdf.save());
  }

  Future<void> _exportToExcel() async {
    var excel = Excel.createExcel();
    Sheet s = excel['Reporte'];
    s.appendRow([TextCellValue('BBS Club - Reporte ${DateFormat('dd/MM/yyyy').format(_startDate)} - ${DateFormat('dd/MM/yyyy').format(_endDate)}')]);
    s.appendRow([TextCellValue('Total'), TextCellValue(_totalSales.toString())]);
    s.appendRow([TextCellValue('Transacciones'), TextCellValue(_totalTransactions.toString())]);
    final b = excel.save();
    if (b != null) await Printing.sharePdf(bytes: Uint8List.fromList(b), filename: 'reporte_bbs_${DateFormat('ddMMyyyy').format(DateTime.now())}.xlsx');
  }

  @override
  Widget build(BuildContext context) {
    // FIX maxY: redondeado a 20k para que $100k no se monte sobre $80k. Calculo fuera del BarChart para no enredar parentesis.
    double chartMaxY = 100;
    if (_salesByDay.isNotEmpty) {
      double m = 0;
      for (final e in _salesByDay) { final v = (e['total'] as num).toDouble(); if (v > m) m = v; }
      chartMaxY = ((m / 20000).ceil() * 20000).toDouble();
      if (chartMaxY < 20000) chartMaxY = 20000;
    }
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(backgroundColor: const Color(0xFF1E293B), title: const Text('Reportes Avanzados', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)), leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: ()=> Navigator.pop(context)), actions: [IconButton(icon: const Icon(Icons.picture_as_pdf, color: Colors.white70), onPressed: _exportToPDF, tooltip: 'PDF'), IconButton(icon: const Icon(Icons.table_chart, color: Colors.white70), onPressed: _exportToExcel, tooltip: 'Excel')]),
      body: _isLoading ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1))) : SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // FILTRO PERIODO + FECHAS CUSTOM
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)), child: Column(children: [
          // FIX overflow: Período arriba, botones abajo a ancho completo (antes Row se cortaba Año)
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Período', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            SingleChildScrollView(scrollDirection: Axis.horizontal, child: SegmentedButton<String>(showSelectedIcon: false, style: ButtonStyle(visualDensity: VisualDensity.compact, tapTargetSize: MaterialTapTargetSize.shrinkWrap), segments: const [ButtonSegment(value: 'week', label: Text('Semana', style: TextStyle(fontSize: 11))), ButtonSegment(value: 'month', label: Text('Mes', style: TextStyle(fontSize: 11))), ButtonSegment(value: 'year', label: Text('Año', style: TextStyle(fontSize: 11)))], selected: {_selectedPeriod=='custom'? 'month': _selectedPeriod}, onSelectionChanged: (Set<String> v){ _setPeriod(v.first); })),
          ]),
          const SizedBox(height: 12),
          InkWell(onTap: _pickDateRange, borderRadius: BorderRadius.circular(8), child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(8), border: Border.all(color: _selectedPeriod=='custom'? const Color(0xFF6366F1): Colors.white10)), child: Row(children: [
            Icon(Icons.calendar_today, color: _selectedPeriod=='custom'? const Color(0xFF6366F1): Colors.white38, size: 14),
            const SizedBox(width: 8),
            Expanded(child: FittedBox(alignment: Alignment.centerLeft, fit: BoxFit.scaleDown, child: Text('${DateFormat('dd/MM/yyyy').format(_startDate)}  →  ${DateFormat('dd/MM/yyyy').format(_endDate)}', style: TextStyle(color: _selectedPeriod=='custom'? Colors.white: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)))),
            const SizedBox(width: 8),
            FittedBox(fit: BoxFit.scaleDown, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.2), borderRadius: BorderRadius.circular(6)), child: Text(_selectedPeriod=='custom'? 'PERSONALIZADO':'CAMBIAR FECHAS', style: const TextStyle(color: Color(0xFF6366F1), fontSize: 9, fontWeight: FontWeight.bold)))),
          ]))),
        ])),
        const SizedBox(height: 12),
        // FILTROS: Barbero + Servicio + Metodo
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.filter_list_rounded, size: 16, color: Color(0xFF6366F1)),
            const SizedBox(width: 6),
            const Text('Filtros', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            const Spacer(),
            if (_filterBarber != 'all' || _filterService != 'all' || _filterMethod != 'all') GestureDetector(onTap: _clearFilters, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.red.withOpacity(0.15), borderRadius: BorderRadius.circular(20)), child: const Text('Limpiar filtros ✕', style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)))),
          ]),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(value: _filterBarber, dropdownColor: const Color(0xFF1E293B), style: const TextStyle(color: Colors.white, fontSize: 12), decoration: InputDecoration(labelText: 'Barbero', labelStyle: const TextStyle(color: Colors.white54, fontSize: 11), filled: true, fillColor: const Color(0xFF0F172A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)), items: [const DropdownMenuItem(value: 'all', child: Text('Todos los barberos')), ..._allBarbers.map((b) => DropdownMenuItem(value: b, child: Text(b)))], onChanged: (v) { setState(() => _filterBarber = v ?? 'all'); _loadReportData(); }),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(value: _filterService, dropdownColor: const Color(0xFF1E293B), style: const TextStyle(color: Colors.white, fontSize: 12), decoration: InputDecoration(labelText: 'Servicio / Producto', labelStyle: const TextStyle(color: Colors.white54, fontSize: 11), filled: true, fillColor: const Color(0xFF0F172A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)), items: [const DropdownMenuItem(value: 'all', child: Text('Todos los servicios')), ..._allServices.map((s) => DropdownMenuItem(value: s, child: Text(s)))], onChanged: (v) { setState(() => _filterService = v ?? 'all'); _loadReportData(); }),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(value: _filterMethod, dropdownColor: const Color(0xFF1E293B), style: const TextStyle(color: Colors.white, fontSize: 12), decoration: InputDecoration(labelText: 'Método de pago', labelStyle: const TextStyle(color: Colors.white54, fontSize: 11), filled: true, fillColor: const Color(0xFF0F172A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)), items: const [DropdownMenuItem(value: 'all', child: Text('Todos los métodos')), DropdownMenuItem(value: 'cash', child: Text('Efectivo')), DropdownMenuItem(value: 'transfer', child: Text('Transferencia')), DropdownMenuItem(value: 'card', child: Text('Tarjeta')), DropdownMenuItem(value: 'debito', child: Text('Débito')), DropdownMenuItem(value: 'mixto', child: Text('Mixto'))], onChanged: (v) { setState(() => _filterMethod = v ?? 'all'); _loadReportData(); }),
          const SizedBox(height: 10),
          Text(_filterLabel, style: const TextStyle(color: Colors.white54, fontSize: 11)),
          if (_filterBarber != 'all' || _filterService != 'all' || _filterMethod != 'all') Padding(padding: const EdgeInsets.only(top: 6), child: Text('Mostrando ${_totalTransactions.toInt()} ventas filtradas', style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold))),
        ])),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _buildSummaryCard('💵 Total Ventas', SettingsService.formatCurrency(_totalSales), const Color(0xFF38BDF8))),
          const SizedBox(width: 10),
          Expanded(child: _buildSummaryCard('🧾 Transacciones', '${_totalTransactions.toInt()}', const Color(0xFF10B981))),
          const SizedBox(width: 10),
          Expanded(child: _buildSummaryCard('📊 Ticket Promedio', SettingsService.formatCurrency(_averageTicket), const Color(0xFFF59E0B))),
        ]),
        const SizedBox(height: 24),
        if (_salesByDay.isNotEmpty) ...[
          const Text('Ventas por Día', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          SizedBox(height: 280, child: BarChart(BarChartData(alignment: BarChartAlignment.spaceAround, maxY: chartMaxY, barGroups: _salesByDay.asMap().entries.map((entry){ final i=entry.key; final d=entry.value; final v=(d['total'] as num).toDouble(); return BarChartGroupData(x: i, barRods: [BarChartRodData(toY: v, color: const Color(0xFF6366F1), width: 12, borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))]);}).toList(), titlesData: FlTitlesData(show: true, bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (val, meta){ final idx=val.toInt(); if(idx>=0 && idx<_salesByDay.length) return Padding(padding: const EdgeInsets.only(top:4), child: Text(_salesByDay[idx]['day'] as String, style: const TextStyle(color: Colors.white54, fontSize: 8))); return const SizedBox.shrink();})), leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 48, interval: 20000, getTitlesWidget: (v,m){ if (v % 20000 != 0) return const SizedBox.shrink(); return Text('\$${(v/1000).toStringAsFixed(0)}k', style: const TextStyle(color: Colors.white38, fontSize: 8)); })), topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false))), gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v)=> const FlLine(color: Colors.white10, strokeWidth: 0.4)), borderData: FlBorderData(show: false)))),
          const SizedBox(height: 28),
        ],
        if (_salesByBarber.isNotEmpty) ...[
          const Text('Ventas por Barbero', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          SizedBox(height: 220, child: PieChart(PieChartData(sections: _salesByBarber.asMap().entries.map((e){ final colors=[const Color(0xFF38BDF8), const Color(0xFF10B981), const Color(0xFFF59E0B), const Color(0xFFA78BFA), Colors.redAccent]; final d=e.value; final tot=(d['total'] as num).toDouble(); final perc=_totalSales>0? tot/_totalSales*100:0; return PieChartSectionData(color: colors[e.key % colors.length], value: tot, title: '${d['barber']}\n${perc.toStringAsFixed(1)}%', radius: 68, titleStyle: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white));}).toList(), sectionsSpace: 2, centerSpaceRadius: 32))),
          const SizedBox(height: 28),
        ],
        if (_filteredDetail.isNotEmpty) ...[
          const Text('Detalle filtrado (servicio x barbero)', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ..._filteredDetail.take(20).map((d) => Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)), child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(d['service'].toString(), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)), const SizedBox(height: 2), Text(d['barber'].toString(), style: const TextStyle(color: Colors.white54, fontSize: 10))])), Text('x${d['qty']}', style: const TextStyle(color: Colors.white54, fontSize: 11)), const SizedBox(width: 10), Text(SettingsService.formatCurrency((d['total'] as num).toDouble()), style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 11))]))),
          const SizedBox(height: 20),
        ],
        if (_salesByService.isNotEmpty) ...[
          const Text('Top Servicios/Productos', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ..._salesByService.take(6).map((s)=> Container(margin: const EdgeInsets.only(bottom: 8), decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)), child: ListTile(leading: CircleAvatar(backgroundColor: const Color(0xFF6366F1).withOpacity(0.18), child: Text('${s['quantity']}', style: const TextStyle(color: Color(0xFF6366F1), fontSize: 10, fontWeight: FontWeight.bold))), title: Text(s['name'] as String, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)), subtitle: Text('Cant: ${s['quantity']}', style: const TextStyle(color: Colors.white54, fontSize: 9)), trailing: Text(SettingsService.formatCurrency((s['total'] as num).toDouble()), style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 11))))),
        ],
      ])),
    );
  }

  Widget _buildSummaryCard(String title, String value, Color color) {
    return Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.35))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: Colors.white54, fontSize: 9)),
      const SizedBox(height: 6),
      Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: color)),
    ]));
  }
}
