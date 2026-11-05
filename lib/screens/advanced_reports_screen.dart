import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import '../services/settings_service.dart';
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
  List<Map<String, dynamic>> _rawTransactions = [];

  @override
  void initState() {
    super.initState();
    _loadReportData();
  }

  Future<void> _loadReportData() async {
    setState(() => _isLoading = true);
    try {
      final startStr = DateTime(_startDate.year, _startDate.month, _startDate.day).toIso8601String();
      final endStr = DateTime(_endDate.year, _endDate.month, _endDate.day).add(const Duration(days: 1)).toIso8601String();

      final transactions = await Supabase.instance.client.from('transactions').select('*').gte('created_at', startStr).lte('created_at', endStr).eq('status', 'completed');
      final transList = List<Map<String, dynamic>>.from(transactions);
      _rawTransactions = transList;

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
        final barber = t['barber_name']?.toString().isNotEmpty == true ? t['barber_name'] : 'Sin barbero';
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
        try {
          final items = await Supabase.instance.client.from('transaction_items').select('service_name, product_name, quantity, price_at_moment').inFilter('transaction_id', transList.map((t) => t['id']).toList());
          final itemList = List<Map<String, dynamic>>.from(items);
          Map<String, Map<String, dynamic>> serviceMap = {};
          for (final item in itemList) {
            final name = item['service_name'] ?? item['product_name'] ?? 'Desconocido';
            final qty = (item['quantity'] as num?)?.toInt() ?? 1;
            final price = (item['price_at_moment'] as num?)?.toDouble() ?? 0.0;
            if (!serviceMap.containsKey(name)) serviceMap[name] = {'name': name, 'quantity': 0, 'total': 0.0};
            serviceMap[name]!['quantity'] = (serviceMap[name]!['quantity'] as int) + qty;
            serviceMap[name]!['total'] = (serviceMap[name]!['total'] as double) + (price * qty);
          }
          _salesByService = serviceMap.values.toList();
          _salesByService.sort((a, b) => (b['total'] as double).compareTo(a['total'] as double));
        } catch (e) {
          print('items error: $e');
        }
      } else {
        _salesByService = [];
      }

      setState(() => _isLoading = false);
    } catch (e) {
      print('❌ Error reportes: $e');
      setState(() => _isLoading = false);
    }
  }

  void _setPeriod(String period) {
    setState(() => _selectedPeriod = period);
    final now = DateTime.now();
    switch (period) {
      case 'week': _startDate = now.subtract(const Duration(days: 7)); _endDate = now; break;
      case 'month': _startDate = now.subtract(const Duration(days: 30)); _endDate = now; break;
      case 'year': _startDate = now.subtract(const Duration(days: 365)); _endDate = now; break;
      case 'custom': return; // no auto
    }
    _loadReportData();
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) => Theme(data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: Color(0xFF6366F1), surface: Color(0xFF1E293B)), dialogBackgroundColor: const Color(0xFF0F172A)), child: child!),
    );
    if (picked != null) {
      setState(() { _startDate = picked.start; _endDate = picked.end; _selectedPeriod = 'custom'; });
      await _loadReportData();
    }
  }

  Future<void> _pickSingleDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: Color(0xFF6366F1)), dialogBackgroundColor: const Color(0xFF1E293B)), child: child!),
    );
    if (picked != null) {
      setState(() {
        if (isStart) _startDate = picked; else _endDate = picked;
        _selectedPeriod = 'custom';
      });
      await _loadReportData();
    }
  }

  Future<void> _exportToPDF() async {
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) => [
        pw.Header(level: 0, child: pw.Text('Reporte de Ventas - BBS Club Barbería', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold))),
        pw.Text('Período: ${DateFormat('dd/MM/yyyy').format(_startDate)} - ${DateFormat('dd/MM/yyyy').format(_endDate)}', style: const pw.TextStyle(fontSize: 10)),
        pw.SizedBox(height: 12),
        pw.Header(level: 1, child: pw.Text('Resumen General', style: const pw.TextStyle(fontSize: 12))),
        pw.TableHelper.fromTextArray(headers: ['Métrica', 'Valor'], data: [
          ['Total Ventas', SettingsService.formatCurrency(_totalSales)],
          ['Total Transacciones', '${_totalTransactions.toInt()}'],
          ['Ticket Promedio', SettingsService.formatCurrency(_averageTicket)],
        ]),
        pw.SizedBox(height: 12),
        if (_salesByBarber.isNotEmpty) ...[
          pw.Header(level: 1, child: pw.Text('Ventas por Barbero')),
          pw.TableHelper.fromTextArray(headers: ['Barbero', 'Total'], data: _salesByBarber.map((e) => [e['barber'], SettingsService.formatCurrency(e['total'] as double)]).toList()),
          pw.SizedBox(height: 12),
        ],
        if (_salesByService.isNotEmpty) ...[
          pw.Header(level: 1, child: pw.Text('Servicios / Productos')),
          pw.TableHelper.fromTextArray(headers: ['Nombre', 'Cantidad', 'Total'], data: _salesByService.map((e) => [e['name'], '${e['quantity']}', SettingsService.formatCurrency(e['total'] as double)]).toList()),
          pw.SizedBox(height: 12),
        ],
        pw.Header(level: 1, child: pw.Text('Detalle Transacciones')),
        pw.TableHelper.fromTextArray(headers: ['Fecha', 'Barbero', 'Pago', 'Total'], data: _rawTransactions.map((t) => [
          DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(t['created_at'])),
          (t['barber_name'] ?? 'Sin barbero').toString(),
          (t['payment_method'] ?? '').toString(),
          SettingsService.formatCurrency((t['total'] as num).toDouble())
        ]).toList()),
      ],
    ));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'Reporte_${DateFormat('ddMMyyyy').format(DateTime.now())}.pdf');
  }

  Future<void> _exportToExcel() async {
    final excel = Excel.createExcel();
    final sheet = excel['Reporte'];
    sheet.appendRow([TextCellValue('BBS CLUB - Reporte de Ventas')]);
    sheet.appendRow([TextCellValue('Período: ${DateFormat('dd/MM/yyyy').format(_startDate)} - ${DateFormat('dd/MM/yyyy').format(_endDate)}')]);
    sheet.appendRow([]);
    sheet.appendRow([TextCellValue('RESUMEN'), TextCellValue('')]);
    sheet.appendRow([TextCellValue('Total Ventas'), TextCellValue(SettingsService.formatCurrency(_totalSales))]);
    sheet.appendRow([TextCellValue('Transacciones'), IntCellValue(_totalTransactions.toInt())]);
    sheet.appendRow([TextCellValue('Ticket Prom'), TextCellValue(SettingsService.formatCurrency(_averageTicket))]);
    sheet.appendRow([]);
    sheet.appendRow([TextCellValue('VENTAS POR BARBERO')]);
    sheet.appendRow([TextCellValue('Barbero'), TextCellValue('Total')]);
    for (final b in _salesByBarber) sheet.appendRow([TextCellValue(b['barber'] as String), TextCellValue(SettingsService.formatCurrency(b['total'] as double))]);
    sheet.appendRow([]);
    sheet.appendRow([TextCellValue('SERVICIOS / PRODUCTOS')]);
    sheet.appendRow([TextCellValue('Nombre'), TextCellValue('Cantidad'), TextCellValue('Total')]);
    for (final s in _salesByService) sheet.appendRow([TextCellValue(s['name'] as String), IntCellValue(s['quantity'] as int), TextCellValue(SettingsService.formatCurrency(s['total'] as double))]);
    sheet.appendRow([]);
    sheet.appendRow([TextCellValue('DETALLE TRANSACCIONES')]);
    sheet.appendRow([TextCellValue('Fecha'), TextCellValue('Barbero'), TextCellValue('Cajero'), TextCellValue('Pago'), TextCellValue('Total')]);
    for (final t in _rawTransactions) {
      sheet.appendRow([
        TextCellValue(DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(t['created_at']))),
        TextCellValue((t['barber_name'] ?? 'Sin barbero').toString()),
        TextCellValue((t['cashier_name'] ?? '').toString()),
        TextCellValue((t['payment_method'] ?? '').toString()),
        TextCellValue(SettingsService.formatCurrency((t['total'] as num).toDouble())),
      ]);
    }
    final fileBytes = excel.save();
    if (fileBytes != null) {
      await Printing.sharePdf(bytes: Uint8List.fromList(fileBytes), filename: 'Reporte_${DateFormat('ddMMyyyy').format(DateTime.now())}.xlsx');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('📊 Excel exportado'), backgroundColor: Color(0xFF10B981)));
    }
  }

  Widget _buildChip(String id, String label) {
    final selected = _selectedPeriod == id;
    return InkWell(onTap: () => id == 'custom' ? _pickCustomRange() : _setPeriod(id), child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), decoration: BoxDecoration(color: selected ? const Color(0xFF6366F1) : const Color(0xFF1E293B), borderRadius: BorderRadius.circular(20), border: Border.all(color: selected ? const Color(0xFF6366F1) : Colors.white10)), child: Row(mainAxisSize: MainAxisSize.min, children: [if (selected) const Text('✓ ', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)), Text(label, style: TextStyle(color: selected ? Colors.white : Colors.white54, fontSize: 11, fontWeight: FontWeight.bold))])) );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: const Text('Reportes Avanzados Premium', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white70, size: 20), tooltip: 'Exportar PDF', onPressed: _exportToPDF),
          IconButton(icon: const Icon(Icons.table_chart_rounded, color: Colors.white70, size: 20), tooltip: 'Exportar Excel', onPressed: _exportToExcel),
          IconButton(icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 18), onPressed: _loadReportData),
        ],
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1))) : SingleChildScrollView(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // FILTRO FECHAS PREMIUM
        Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF1E1B4B), Color(0xFF312E81)]), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withOpacity(0.08))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Text('📅', style: TextStyle(fontSize: 14))),
            const SizedBox(width: 8),
            Expanded(child: Text('${DateFormat('dd/MM/yyyy').format(_startDate)} - ${DateFormat('dd/MM/yyyy').format(_endDate)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
            InkWell(onTap: _pickCustomRange, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(20)), child: const Text('Cambiar', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)))),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: InkWell(onTap: () => _pickSingleDate(true), child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white10)), child: Row(children: [const Icon(Icons.calendar_today_rounded, size: 14, color: Colors.white38), const SizedBox(width: 6), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Desde', style: TextStyle(color: Colors.white38, fontSize: 9)), Text(DateFormat('dd/MM/yyyy').format(_startDate), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))])])))),
            const SizedBox(width: 10),
            Expanded(child: InkWell(onTap: () => _pickSingleDate(false), child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white10)), child: Row(children: [const Icon(Icons.event_rounded, size: 14, color: Colors.white38), const SizedBox(width: 6), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Hasta', style: TextStyle(color: Colors.white38, fontSize: 9)), Text(DateFormat('dd/MM/yyyy').format(_endDate), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))])])))),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [_buildChip('week', '7 días'), _buildChip('month', '30 días'), _buildChip('year', '1 año'), _buildChip('custom', '📅 Personalizado')]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: ElevatedButton.icon(onPressed: _exportToExcel, icon: const Text('📗', style: TextStyle(fontSize: 14)), label: const Text('Excel', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 10)))),
            const SizedBox(width: 8),
            Expanded(child: ElevatedButton.icon(onPressed: _exportToPDF, icon: const Text('📕', style: TextStyle(fontSize: 14)), label: const Text('PDF', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 10)))),
          ])
        ])),

        const SizedBox(height: 12),
        // CARDS RESUMEN COMPACTAS
        GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 2.2, children: [
          _summary('Total Ventas', SettingsService.formatCurrency(_totalSales), const Color(0xFF10B981)),
          _summary('Ticket Prom', SettingsService.formatCurrency(_averageTicket), const Color(0xFF60A5FA)),
          _summary('Transacciones', '${_totalTransactions.toInt()}', const Color(0xFFA78BFA)),
          _summary('Periodo', _selectedPeriod, const Color(0xFFFBBF24)),
        ]),

        const SizedBox(height: 16),
        const Text('Ventas por Día', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 8),
        Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withOpacity(0.06))), child: SizedBox(height: 180, child: _salesByDay.isEmpty ? const Center(child: Text('Sin datos', style: TextStyle(color: Colors.white38, fontSize: 11))) : BarChart(BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: _salesByDay.map((e) => e['total'] as double).reduce((a, b) => a > b ? a : b) * 1.3,
          barGroups: _salesByDay.asMap().entries.map((entry) => BarChartGroupData(x: entry.key, barRods: [BarChartRodData(toY: entry.value['total'] as double, color: const Color(0xFF6366F1), width: 12, borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))])).toList(),
          titlesData: FlTitlesData(bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22, getTitlesWidget: (v, m) { if (v.toInt() < _salesByDay.length) return Padding(padding: const EdgeInsets.only(top: 4), child: Text(_salesByDay[v.toInt()]['day'] as String, style: const TextStyle(fontSize: 9, color: Colors.white54))); return const SizedBox.shrink(); })), leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false))),
          gridData: const FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 5000, getDrawingHorizontalLine: (v) => const FlLine(color: Colors.white10, strokeWidth: 0.5)),
          borderData: FlBorderData(show: false),
        )))),

        const SizedBox(height: 16),
        const Text('Ventas por Barbero', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 8),
        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withOpacity(0.06))), child: _salesByBarber.isEmpty ? const Center(child: Text('Sin datos', style: TextStyle(color: Colors.white38, fontSize: 11))) : SizedBox(height: 200, child: PieChart(PieChartData(
          sections: _salesByBarber.asMap().entries.map((e) {
            final colors = [const Color(0xFF6366F1), const Color(0xFF10B981), const Color(0xFFF59E0B), const Color(0xFFEC4899), const Color(0xFF8B5CF6)];
            final perc = _totalSales > 0 ? (e.value['total'] as double) / _totalSales * 100 : 0;
            return PieChartSectionData(color: colors[e.key % colors.length], value: e.value['total'] as double, title: '${e.value['barber']}\n${perc.toStringAsFixed(0)}%', radius: 70, titleStyle: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white));
          }).toList(),
          sectionsSpace: 2, centerSpaceRadius: 30,
        )))),
      ])),
    );
  }

  Widget _summary(String title, String value, Color color) {
    return Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.06))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(title, style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
    ]));
  }
}
