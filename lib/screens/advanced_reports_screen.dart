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
  String _selectedPeriod = 'month'; // week, month, year
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  // Datos de reportes
  double _totalSales = 0;
  double _totalTransactions = 0;
  double _averageTicket = 0;
  List<Map<String, dynamic>> _salesByDay = [];
  List<Map<String, dynamic>> _salesByBarber = [];
  List<Map<String, dynamic>> _salesByService = [];
  List<Map<String, dynamic>> _paymentMethods = [];

  @override
  void initState() {
    super.initState();
    _loadReportData();
  }

  Future<void> _loadReportData() async {
    setState(() { _isLoading = true; });

    try {
      final startStr = _startDate.toIso8601String();
      final endStr = _endDate.add(const Duration(days: 1)).toIso8601String();

      // 1. Obtener todas las transacciones del período
      final transactions = await Supabase.instance.client
          .from('transactions')
          .select('*')
          .gte('created_at', startStr)
          .lte('created_at', endStr)
          .eq('status', 'completed');

      final transList = List<Map<String, dynamic>>.from(transactions);

      // 2. Calcular totales
      _totalSales = transList.fold(0.0, (sum, t) => sum + ((t['total'] as num?)?.toDouble() ?? 0.0));
      _totalTransactions = transList.length.toDouble();
      _averageTicket = _totalTransactions > 0 ? _totalSales / _totalTransactions : 0.0;

      // 3. Ventas por día
      Map<String, double> salesByDayMap = {};
      for (final t in transList) {
        final date = DateTime.parse(t['created_at']);
        final dateKey = '${date.day}/${date.month}';
        salesByDayMap[dateKey] = (salesByDayMap[dateKey] ?? 0.0) + ((t['total'] as num?)?.toDouble() ?? 0.0);
      }
      _salesByDay = salesByDayMap.entries.map((e) => {'day': e.key, 'total': e.value}).toList();

      // 4. Ventas por barbero
      Map<String, double> salesByBarberMap = {};
      for (final t in transList) {
        final barber = t['barber_name'] ?? 'Sin barbero';
        salesByBarberMap[barber] = (salesByBarberMap[barber] ?? 0.0) + ((t['total'] as num?)?.toDouble() ?? 0.0);
      }
      _salesByBarber = salesByBarberMap.entries.map((e) => {'barber': e.key, 'total': e.value}).toList();

      // 5. Ventas por método de pago
      Map<String, double> paymentMap = {};
      for (final t in transList) {
        final method = t['payment_method'] ?? 'unknown';
        paymentMap[method] = (paymentMap[method] ?? 0.0) + ((t['total'] as num?)?.toDouble() ?? 0.0);
      }
      _paymentMethods = paymentMap.entries.map((e) => {'method': e.key, 'total': e.value}).toList();

      // 6. Servicios más vendidos
      final items = await Supabase.instance.client
          .from('transaction_items')
          .select('service_name, product_name, quantity, price_at_moment')
          .inFilter('transaction_id', transList.map((t) => t['id']).toList());

      final itemList = List<Map<String, dynamic>>.from(items);
      Map<String, Map<String, dynamic>> serviceMap = {};
      for (final item in itemList) {
        final name = item['service_name'] ?? item['product_name'] ?? 'Desconocido';
        final qty = (item['quantity'] as num?)?.toInt() ?? 1;
        final price = (item['price_at_moment'] as num?)?.toDouble() ?? 0.0;
        
        if (!serviceMap.containsKey(name)) {
          serviceMap[name] = {'name': name, 'quantity': 0, 'total': 0.0};
        }
        serviceMap[name]!['quantity'] = (serviceMap[name]!['quantity'] as int) + qty;
        serviceMap[name]!['total'] = (serviceMap[name]!['total'] as double) + (price * qty);
      }
      _salesByService = serviceMap.values.toList();
      _salesByService.sort((a, b) => (b['total'] as double).compareTo(a['total'] as double));

      setState(() { _isLoading = false; });
    } catch (e) {
      print('❌ Error al cargar reportes: $e');
      setState(() { _isLoading = false; });
    }
  }

  void _setPeriod(String period) {
    setState(() { _selectedPeriod = period; });
    
    final now = DateTime.now();
    switch (period) {
      case 'week':
        _startDate = now.subtract(const Duration(days: 7));
        break;
      case 'month':
        _startDate = now.subtract(const Duration(days: 30));
        break;
      case 'year':
        _startDate = now.subtract(const Duration(days: 365));
        break;
    }
    _endDate = now;
    _loadReportData();
  }

  Future<void> _exportToPDF() async {
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) => [
          pw.Header(
            level: 0,
            child: pw.Text('Reporte de Ventas - BBS Club Barbería',
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 20),
          pw.Text('Período: ${DateFormat('dd/MM/yyyy').format(_startDate)} - ${DateFormat('dd/MM/yyyy').format(_endDate)}',
              style: const pw.TextStyle(fontSize: 12)),
          pw.SizedBox(height: 20),
          
          // Resumen
          pw.Header(level: 1, child: pw.Text('Resumen General')),
          pw.TableHelper.fromTextArray(
            headers: ['Métrica', 'Valor'],
            data: [
              ['Total Ventas', SettingsService.formatCurrency(_totalSales)],
              ['Total Transacciones', '${_totalTransactions.toInt()}'],
              ['Ticket Promedio', SettingsService.formatCurrency(_averageTicket)],
            ],
          ),
          pw.SizedBox(height: 20),
          
          // Ventas por barbero
          if (_salesByBarber.isNotEmpty) ...[
            pw.Header(level: 1, child: pw.Text('Ventas por Barbero')),
            pw.TableHelper.fromTextArray(
              headers: ['Barbero', 'Total Ventas'],
              data: _salesByBarber.map((e) => [
                e['barber'],
                SettingsService.formatCurrency(e['total'] as double),
              ]).toList(),
            ),
            pw.SizedBox(height: 20),
          ],
          
          // Servicios más vendidos
          if (_salesByService.isNotEmpty) ...[
            pw.Header(level: 1, child: pw.Text('Servicios/Productos Más Vendidos')),
            pw.TableHelper.fromTextArray(
              headers: ['Nombre', 'Cantidad', 'Total'],
              data: _salesByService.map((e) => [
                e['name'],
                '${e['quantity']}',
                SettingsService.formatCurrency(e['total'] as double),
              ]).toList(),
            ),
          ],
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Reporte_Ventas_${DateFormat('ddMMyyyy').format(DateTime.now())}.pdf',
    );
  }

  Future<void> _exportToExcel() async {
    final excel = Excel.createExcel();
    final sheet = excel['Reporte de Ventas'];

    // Encabezados
    sheet.appendRow([TextCellValue('Reporte de Ventas - BBS Club Barbería')]);
    sheet.appendRow([TextCellValue('Período: ${DateFormat('dd/MM/yyyy').format(_startDate)} - ${DateFormat('dd/MM/yyyy').format(_endDate)}')]);
    sheet.appendRow([]);

    // Resumen
    sheet.appendRow([TextCellValue('RESUMEN GENERAL')]);
    sheet.appendRow([TextCellValue('Total Ventas'), TextCellValue(SettingsService.formatCurrency(_totalSales))]);
    sheet.appendRow([TextCellValue('Total Transacciones'), TextCellValue('${_totalTransactions.toInt()}')]);
    sheet.appendRow([TextCellValue('Ticket Promedio'), TextCellValue(SettingsService.formatCurrency(_averageTicket))]);
    sheet.appendRow([]);

    // Ventas por barbero
    if (_salesByBarber.isNotEmpty) {
      sheet.appendRow([TextCellValue('VENTAS POR BARBERO')]);
      sheet.appendRow([TextCellValue('Barbero'), TextCellValue('Total Ventas')]);
      for (final barber in _salesByBarber) {
        sheet.appendRow([
          TextCellValue(barber['barber'] as String),
          TextCellValue(SettingsService.formatCurrency(barber['total'] as double)),
        ]);
      }
      sheet.appendRow([]);
    }

    // Servicios más vendidos
    if (_salesByService.isNotEmpty) {
      sheet.appendRow([TextCellValue('SERVICIOS/PRODUCTOS MÁS VENDIDOS')]);
      sheet.appendRow([TextCellValue('Nombre'), TextCellValue('Cantidad'), TextCellValue('Total')]);
      for (final service in _salesByService) {
        sheet.appendRow([
          TextCellValue(service['name'] as String),
          TextCellValue('${service['quantity']}'),
          TextCellValue(SettingsService.formatCurrency(service['total'] as double)),
        ]);
      }
    }

    // Guardar archivo
    final fileBytes = excel.save();
    if (fileBytes != null) {
      await Printing.sharePdf(
        bytes: Uint8List.fromList(fileBytes),
        filename: 'Reporte_Ventas_${DateFormat('ddMMyyyy').format(DateTime.now())}.xlsx',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📊 Reportes Avanzados'),
        backgroundColor: Colors.indigo[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Text('📄', style: TextStyle(fontSize: 20)),
            tooltip: 'Exportar PDF',
            onPressed: _exportToPDF,
          ),
          IconButton(
            icon: const Text('📊', style: TextStyle(fontSize: 20)),
            tooltip: 'Exportar Excel',
            onPressed: _exportToExcel,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Selector de período
                  Row(
                    children: [
                      Expanded(
                        child: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'week', label: Text('Semana')),
                            ButtonSegment(value: 'month', label: Text('Mes')),
                            ButtonSegment(value: 'year', label: Text('Año')),
                          ],
                          selected: {_selectedPeriod},
                          onSelectionChanged: (Set<String> newSelection) {
                            _setPeriod(newSelection.first);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Tarjetas de resumen
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard('💵 Total Ventas', SettingsService.formatCurrency(_totalSales), Colors.blue),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSummaryCard('🧾 Transacciones', '${_totalTransactions.toInt()}', Colors.green),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSummaryCard('📊 Ticket Promedio', SettingsService.formatCurrency(_averageTicket), Colors.orange),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // Gráfico de ventas por día
                  if (_salesByDay.isNotEmpty) ...[
                    const Text('Ventas por Día', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 300,
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: _salesByDay.map((e) => e['total'] as double).reduce((a, b) => a > b ? a : b) * 1.2,
                          barGroups: _salesByDay.asMap().entries.map((entry) {
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
                                  final index = value.toInt();
                                  if (index >= 0 && index < _salesByDay.length) {
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        _salesByDay[index]['day'] as String,
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 60,
                                getTitlesWidget: (value, meta) {
                                  return Text(
                                    '\$${(value / 1000).toStringAsFixed(0)}k',
                                    style: const TextStyle(fontSize: 10),
                                  );
                                },
                              ),
                            ),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          gridData: const FlGridData(show: true),
                          borderData: FlBorderData(show: false),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],

                  // Gráfico de ventas por barbero
                  if (_salesByBarber.isNotEmpty) ...[
                    const Text('Ventas por Barbero', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 250,
                      child: PieChart(
                        PieChartData(
                          sections: _salesByBarber.asMap().entries.map((entry) {
                            final colors = [Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.red];
                            final data = entry.value;
                            final percentage = (data['total'] as double) / _totalSales * 100;
                            return PieChartSectionData(
                              color: colors[entry.key % colors.length],
                              value: data['total'] as double,
                              title: '${data['barber']}\n${percentage.toStringAsFixed(1)}%',
                              radius: 80,
                              titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                            );
                          }).toList(),
                          sectionsSpace: 2,
                          centerSpaceRadius: 40,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],

                  // Top servicios
                  if (_salesByService.isNotEmpty) ...[
                    const Text('Top Servicios/Productos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    ..._salesByService.take(5).map((service) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.indigo[100],
                          child: Text('${service['quantity']}', style: TextStyle(color: Colors.indigo[700])),
                        ),
                        title: Text(service['name'] as String),
                        subtitle: Text('Cantidad: ${service['quantity']}'),
                        trailing: Text(
                          SettingsService.formatCurrency(service['total'] as double),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                      ),
                    )),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCard(String title, String value, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}