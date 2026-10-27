import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart' as ex;
import 'package:share_plus/share_plus.dart';
import 'dart:typed_data';
import '../services/settings_service.dart';

class ReportsScreen extends StatefulWidget {
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _period = 'week';
  bool _isLoading = true;
  double _totalSales = 0;
  int _txCount = 0;
  double _avgTicket = 0;
  List<double> _values = [];
  List<String> _labels = [];
  final Map<String, double> _paymentMethods = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String get _periodTitle => _period == 'week' ? 'Últimos 7 días' : (_period == 'month' ? 'Últimos 30 días' : 'Año ${DateTime.now().year}');

  String _paymentLabel(String m) {
    switch (m) {
      case 'cash': return 'Efectivo';
      case 'card': return 'Tarjeta';
      case 'transfer': return 'Transferencia';
      default: return m;
    }
  }

  IconData _paymentIcon(String m) {
    switch (m) {
      case 'cash': return Icons.payments;
      case 'card': return Icons.credit_card;
      case 'transfer': return Icons.phone_android;
      default: return Icons.receipt_long;
    }
  }

  String _compact(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}k';
    return v.toStringAsFixed(0);
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; });
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      DateTime start;
      int buckets;
      if (_period == 'week') {
        start = today.subtract(const Duration(days: 6));
        buckets = 7;
      } else if (_period == 'month') {
        start = today.subtract(const Duration(days: 29));
        buckets = 30;
      } else {
        start = DateTime(now.year, 1, 1);
        buckets = 12;
      }
      final res = await Supabase.instance.client
          .from('transactions')
          .select('total, created_at, payment_method')
          .eq('status', 'completed')
          .gte('created_at', start.toIso8601String());
      final rows = List<Map<String, dynamic>>.from(res);

      _totalSales = rows.fold(0.0, (s, r) => s + ((r['total'] as num?)?.toDouble() ?? 0.0));
      _txCount = rows.length;
      _avgTicket = _txCount > 0 ? _totalSales / _txCount : 0.0;

      _values = List.filled(buckets, 0.0);
      _labels = List.filled(buckets, '');
      if (_period == 'year') {
        const names = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
        for (int i = 0; i < 12; i++) {
          _labels[i] = names[i];
        }
        for (final r in rows) {
          final d = DateTime.parse(r['created_at'].toString());
          if (d.year == now.year) _values[d.month - 1] += (r['total'] as num?)?.toDouble() ?? 0.0;
        }
      } else {
        for (int i = 0; i < buckets; i++) {
          final day = start.add(Duration(days: i));
          _labels[i] = _period == 'week' ? ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'][(day.weekday - 1) % 7] : '${day.day}';
        }
        for (final r in rows) {
          final d = DateTime.parse(r['created_at'].toString());
          final idx = DateTime(d.year, d.month, d.day).difference(start).inDays;
          if (idx >= 0 && idx < buckets) _values[idx] += (r['total'] as num?)?.toDouble() ?? 0.0;
        }
      }

      _paymentMethods.clear();
      for (final r in rows) {
        final m = (r['payment_method'] ?? 'cash').toString();
        _paymentMethods[m] = (_paymentMethods[m] ?? 0.0) + ((r['total'] as num?)?.toDouble() ?? 0.0);
      }
    } catch (e) {
      print('Error al cargar reportes: $e');
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  Widget _summaryCard(String label, String value, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Card(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: 6),
                  Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]))),
                ],
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value, maxLines: 1, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportPdf() async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Center(child: pw.Text(SettingsService.ticketHeader, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold))),
          pw.SizedBox(height: 4),
          pw.Center(child: pw.Text('Reporte de Ventas - $_periodTitle', style: pw.TextStyle(fontSize: 12))),
          pw.Center(child: pw.Text('Generado: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}', style: pw.TextStyle(fontSize: 9))),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Total: ${SettingsService.formatCurrency(_totalSales)}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              pw.Text('Transacciones: $_txCount', style: pw.TextStyle(fontSize: 11)),
              pw.Text('Promedio: ${SettingsService.formatCurrency(_avgTicket)}', style: pw.TextStyle(fontSize: 11)),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Table.fromTextArray(
            headers: ['Periodo', 'Ventas'],
            data: [for (int i = 0; i < _labels.length; i++) [_labels[i], SettingsService.formatCurrency(_values[i])]],
            headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            cellStyle: pw.TextStyle(fontSize: 9),
          ),
          pw.SizedBox(height: 12),
          pw.Text('Métodos de pago', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Table.fromTextArray(
            headers: ['Método', 'Monto'],
            data: _paymentMethods.entries.map((e) => [_paymentLabel(e.key), SettingsService.formatCurrency(e.value)]).toList(),
            headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            cellStyle: pw.TextStyle(fontSize: 9),
          ),
        ],
      ),
    );
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save(), name: 'reporte_ventas.pdf');
  }

  Future<void> _exportExcel() async {
    try {
      final excel = ex.Excel.createExcel();
      final sheet = excel['Reporte'];
      sheet.appendRow([ex.TextCellValue('Reporte de Ventas'), ex.TextCellValue(_periodTitle)]);
      sheet.appendRow([ex.TextCellValue('Total Ventas'), ex.TextCellValue(SettingsService.formatCurrency(_totalSales))]);
      sheet.appendRow([ex.TextCellValue('Transacciones'), ex.IntCellValue(_txCount)]);
      sheet.appendRow([ex.TextCellValue('Ticket Promedio'), ex.TextCellValue(SettingsService.formatCurrency(_avgTicket))]);
      sheet.appendRow([]);
      sheet.appendRow([ex.TextCellValue('Periodo'), ex.TextCellValue('Ventas')]);
      for (int i = 0; i < _labels.length; i++) {
        sheet.appendRow([ex.TextCellValue(_labels[i]), ex.DoubleCellValue(_values[i])]);
      }
      sheet.appendRow([]);
      sheet.appendRow([ex.TextCellValue('Método'), ex.TextCellValue('Monto')]);
      _paymentMethods.forEach((k, v) {
        sheet.appendRow([ex.TextCellValue(_paymentLabel(k)), ex.DoubleCellValue(v)]);
      });
      final bytes = excel.save();
      if (bytes == null) throw Exception('No se pudo generar el archivo');
      await Share.shareXFiles(
        [XFile.fromData(Uint8List.fromList(bytes), name: 'reporte_ventas.xlsx', mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')],
        text: 'Reporte de ventas - $_periodTitle',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al exportar Excel: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final double maxVal = _values.isEmpty ? 1000 : _values.reduce((a, b) => a > b ? a : b);
    final double maxY = maxVal < 1000 ? 1000 : maxVal * 1.2;
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.assessment, size: 22),
            SizedBox(width: 8),
            Expanded(child: Text('Reportes de Ventas', overflow: TextOverflow.ellipsis)),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.picture_as_pdf), tooltip: 'Exportar PDF', onPressed: _exportPdf),
          IconButton(icon: const Icon(Icons.grid_on), tooltip: 'Exportar Excel', onPressed: _exportExcel),
          IconButton(icon: const Icon(Icons.refresh), tooltip: 'Actualizar', onPressed: _loadData),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(child: ChoiceChip(label: const Text('Semana'), selected: _period == 'week', onSelected: (_) { setState(() { _period = 'week'; }); _loadData(); })),
                    const SizedBox(width: 8),
                    Expanded(child: ChoiceChip(label: const Text('Mes'), selected: _period == 'month', onSelected: (_) { setState(() { _period = 'month'; }); _loadData(); })),
                    const SizedBox(width: 8),
                    Expanded(child: ChoiceChip(label: const Text('Año'), selected: _period == 'year', onSelected: (_) { setState(() { _period = 'year'; }); _loadData(); })),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _summaryCard('Total Ventas', SettingsService.formatCurrency(_totalSales), Icons.payments, Colors.blue),
                    const SizedBox(width: 8),
                    _summaryCard('Transacciones', '$_txCount', Icons.receipt_long, Colors.green),
                    const SizedBox(width: 8),
                    _summaryCard('Ticket Promedio', SettingsService.formatCurrency(_avgTicket), Icons.trending_up, Colors.orange),
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
                        Text('Ventas por ${_period == 'year' ? 'Mes' : 'Día'}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
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
                                    reservedSize: 36,
                                    getTitlesWidget: (v, m) => Text(_compact(v), style: const TextStyle(fontSize: 9)),
                                  ),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    interval: _period == 'month' ? 5 : 1,
                                    getTitlesWidget: (v, m) => Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(_labels[v.toInt().clamp(0, _labels.length - 1)], style: const TextStyle(fontSize: 9)),
                                    ),
                                  ),
                                ),
                              ),
                              barGroups: [
                                for (int i = 0; i < _values.length; i++)
                                  BarChartGroupData(
                                    x: i,
                                    barRods: [
                                      BarChartRodData(
                                        toY: _values[i],
                                        color: const Color(0xFF6366F1),
                                        width: _period == 'month' ? 6 : 14,
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
                        Text('Métodos de Pago', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                        const SizedBox(height: 8),
                        ..._paymentMethods.entries.map((e) {
                          final pct = _totalSales > 0 ? (e.value / _totalSales * 100) : 0.0;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(_paymentIcon(e.key), color: isDark ? const Color(0xFF818CF8) : Colors.indigo[700]),
                            title: Text('${_paymentLabel(e.key)} (${pct.toStringAsFixed(1)}%)', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
                            trailing: FittedBox(fit: BoxFit.scaleDown, child: Text(SettingsService.formatCurrency(e.value), maxLines: 1, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.green[300] : Colors.green[700]))),
                          );
                        }),
                        if (_paymentMethods.isEmpty)
                          Padding(padding: const EdgeInsets.all(8), child: Text('Sin datos en este período', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}