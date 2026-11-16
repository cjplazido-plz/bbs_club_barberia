// lib/screens/advanced_reports_screen.dart - CON PERMISOS, COMISIONES Y CIERRE POR FECHAS
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import '../services/settings_service.dart';
import '../services/ticket_config_service.dart';
import '../main.dart';
import '../services/role_permissions.dart';
import 'dart:typed_data';
import 'dart:async';

class AdvancedReportsScreen extends StatefulWidget {
  @override
  State<AdvancedReportsScreen> createState() => _AdvancedReportsScreenState();
}

class _AdvancedReportsScreenState extends State<AdvancedReportsScreen> {
  bool _isLoading = true;
  
  String _selectedPeriod = 'today';
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day); 
  DateTime _endDate = DateTime.now();
  
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  double _totalSales = 0;
  double _totalTransactions = 0;
  double _averageTicket = 0;
  double _totalCommissions = 0;
  double _netProfit = 0;
  
  List<Map<String, dynamic>> _paymentMethods = [];
  List<Map<String, dynamic>> _topServices = [];
  
  String _filterService = 'all';
  String _filterMethod = 'all';
  String _searchQuery = ''; 
  
  List<String> _allServicesList = [];
  
  List<Map<String, dynamic>> _allTransactions = [];
  List<Map<String, dynamic>> _filteredDetail = []; 

  @override
  void initState() {
    super.initState();
    _loadReportData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      setState(() => _searchQuery = val);
      _loadReportData(showLoading: false);
    });
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

  Future<void> _loadReportData({bool showLoading = true}) async { 
    if (showLoading) setState(() => _isLoading = true); 
    try {

      final servicesRes = await Supabase.instance.client.from('services').select('name').order('name');
      _allServicesList = List<Map<String, dynamic>>.from(servicesRes).map((e) => e['name'].toString()).toList();

      final startStr = _startDate.toIso8601String();
      final endStr = _endDate.add(const Duration(days: 1)).toIso8601String();
      
      final transactions = await Supabase.instance.client
          .from('transactions')
          .select('*, transaction_items(*)')
          .gte('created_at', startStr)
          .lte('created_at', endStr)
          .eq('status', 'completed');

      var transList = List<Map<String, dynamic>>.from(transactions);

      if (_filterMethod != 'all') transList = transList.where((tr) => (tr['payment_method'] ?? '').toString() == _filterMethod).toList();
      
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        transList = transList.where((tr) => 
          (tr['id'] ?? '').toString().toLowerCase().contains(q) || 
          (tr['barber_name'] ?? '').toString().toLowerCase().contains(q) || 
          (tr['cashier_name'] ?? '').toString().toLowerCase().contains(q) || 
          (tr['client_name'] ?? '').toString().toLowerCase().contains(q) ||
          _formatMethod(tr['payment_method']?.toString()).toLowerCase().contains(q)
        ).toList();
      }

      _allTransactions = List<Map<String, dynamic>>.from(transList);
      _filteredDetail = [];
      _totalCommissions = 0;
      _totalSales = transList.fold(0.0, (sum, t) => sum + ((t['total'] as num?)?.toDouble() ?? 0.0));
      _totalTransactions = transList.length.toDouble();
      
      Map<String, double> paymentMap = {};
      Map<String, double> servicesMap = {}; 

      for (var t in transList) {
        final method = (t['payment_method'] ?? 'cash').toString();
        paymentMap[method] = (paymentMap[method] ?? 0.0) + ((t['total'] as num?)?.toDouble() ?? 0.0);

        final items = List<Map<String, dynamic>>.from(t['transaction_items'] ?? []);
        for (var item in items) {
          _totalCommissions += (item['commission_earned'] as num?)?.toDouble() ?? 0.0;
          
          final itemName = item['service_name'] ?? item['product_name'] ?? 'Item';
          final itemTotal = (item['price_at_moment'] as num).toDouble() * (item['quantity'] as num).toInt();
          
          servicesMap[itemName] = (servicesMap[itemName] ?? 0.0) + itemTotal;

          _filteredDetail.add({
            'service': itemName,
            'barber': item['barber_name'] ?? 'Sin barbero',
            'qty': item['quantity'],
            'total': itemTotal,
            'commission': item['commission_earned'] ?? 0.0,
          });
        }
      }
      
      _averageTicket = _totalTransactions > 0 ? _totalSales / _totalTransactions : 0.0;
      _netProfit = _totalSales - _totalCommissions;

      var sortedServices = servicesMap.entries.map((e) => {'name': e.key, 'total': e.value}).toList();
      sortedServices.sort((a, b) => (b['total'] as double).compareTo(a['total'] as double));
      _topServices = sortedServices.take(5).toList();

      _paymentMethods = paymentMap.entries.map((e) => {'method': e.key, 'total': e.value}).toList();

      if (mounted) setState(() => _isLoading = false);
    } catch (e) { 
      print('Error: $e'); 
      if (mounted) setState(() => _isLoading = false); 
    }
  }

  void _showCierrePorFechasDialog() {
    if (!RolePermissions.isAdmin(currentUserRole)) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('🔒 Cierre de Caja por Fechas', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Período: ${DateFormat('dd/MM/yyyy').format(_startDate)} - ${DateFormat('dd/MM/yyyy').format(_endDate)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const Divider(color: Colors.white10),
              _buildCierreRow('Ventas Totales', SettingsService.formatCurrency(_totalSales), isBold: true),
              _buildCierreRow('Transacciones', '${_totalTransactions.toInt()}'),
              _buildCierreRow('Ticket Promedio', SettingsService.formatCurrency(_averageTicket)),
              const Divider(color: Colors.white10),
              _buildCierreRow('Comisiones Generadas', SettingsService.formatCurrency(_totalCommissions), isRed: true),
              _buildCierreRow('Ganancia Neta', SettingsService.formatCurrency(_netProfit), isGreen: true, isBold: true),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar', style: TextStyle(color: Colors.grey))),
          ElevatedButton.icon(
            onPressed: () { Navigator.pop(ctx); _exportToPDF(); },
            icon: const Icon(Icons.picture_as_pdf, size: 16),
            label: const Text('Exportar Cierre a PDF'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
          ),
        ],
      ),
    );
  }

  Widget _buildCierreRow(String label, String value, {bool isBold = false, bool isRed = false, bool isGreen = false}) {
    Color color = Colors.white;
    if (isRed) color = Colors.redAccent;
    if (isGreen) color = const Color(0xFF10B981);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: isBold ? Colors.white : Colors.white54, fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: isBold ? FontWeight.bold : FontWeight.w600)),
        ],
      ),
    );
  }

  void _clearFilters() { 
    _searchController.clear(); 
    setState(() { 
      _filterService = 'all'; 
      _filterMethod = 'all'; 
      _searchQuery = '';
    }); 
    _loadReportData(showLoading: false); 
  }
  
  String get _filterLabel {
    final parts = <String>[];
    if (_filterService != 'all') parts.add('Servicio: $_filterService');
    if (_filterMethod != 'all') parts.add('Pago: ${_formatMethod(_filterMethod)}');
    if (_searchQuery.isNotEmpty) parts.add('Búsqueda: "$_searchQuery"');
    return parts.isEmpty ? 'Sin filtros - todo el periodo' : parts.join(' • ');
  }
  
  String _formatMethod(String? m) {
    switch (m) { 
      case 'cash': return 'Efectivo'; 
      case 'transfer': return 'Transferencia'; 
      case 'card': return 'Tarjeta'; 
      case 'mixto': return 'Mixto'; 
      default: return m ?? 'Efectivo'; 
    } 
  }

  void _setPeriod(String period) {
    setState(() => _selectedPeriod = period);
    final now = DateTime.now();
    if (period == 'today') _startDate = DateTime(now.year, now.month, now.day);
    if (period == 'week') _startDate = now.subtract(const Duration(days: 7));
    if (period == 'month') _startDate = now.subtract(const Duration(days: 30));
    // ELIMINADO: if (period == 'year') _startDate = now.subtract(const Duration(days: 365));
    _endDate = now;
    _loadReportData();
  }

  Future<void> _exportToPDF() async {
    pw.ImageProvider? logoImage;
    final logoUrl = SettingsService.ticketLogoUrl.isNotEmpty 
        ? SettingsService.ticketLogoUrl 
        : SettingsService.shopLogoUrl;

    if (logoUrl.isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(logoUrl));
        if (response.statusCode == 200) {
          logoImage = pw.MemoryImage(response.bodyBytes);
        }
      } catch (e) {
        debugPrint('Error al cargar el logo: $e');
      }
    }

    final now = DateTime.now();
    final generatedDate = DateFormat('dd-MM-yyyy, h:mm:ss a').format(now);
    final periodStr = "${DateFormat('dd/MM/yyyy').format(_startDate)} - ${DateFormat('dd/MM/yyyy').format(_endDate)}";

    final pdf = pw.Document();
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        build: (pw.Context context) {
          return [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text((SettingsService.shopName.isNotEmpty ? SettingsService.shopName : 'BBS CLUB').toUpperCase(), style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    pw.Text('RUT: ${SettingsService.shopRif}', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text(SettingsService.shopAddress, style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('Tel: ${SettingsService.shopPhone}', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    if (logoImage != null) pw.Image(logoImage, height: 40),
                    pw.SizedBox(height: 8),
                    pw.Text('Generado: $generatedDate', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Divider(thickness: 1, color: PdfColors.grey400),
            pw.SizedBox(height: 10),

            pw.Text('REPORTE DE VENTAS', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text('Período: $periodStr  |  Filtros aplicados: $_filterLabel', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            pw.SizedBox(height: 20),

            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _buildPdfSummaryBox('VENTAS TOTALES', SettingsService.formatCurrency(_totalSales)),
                _buildPdfSummaryBox('TRANSACCIONES', '${_totalTransactions.toInt()}'),
                _buildPdfSummaryBox('COMISIONES', SettingsService.formatCurrency(_totalCommissions)),
                _buildPdfSummaryBox('GANANCIA NETA', SettingsService.formatCurrency(_netProfit)),
              ],
            ),
            pw.SizedBox(height: 20),

            pw.Text('Detalle de Ventas', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            
            pw.TableHelper.fromTextArray(
              headers: ['Folio', 'Fecha', 'Barbero', 'Cliente', 'Items', 'Forma Pago', 'Total'],
              data: _allTransactions.map((t) {
                final items = List<Map<String, dynamic>>.from(t['transaction_items'] ?? []);
                final itemsStr = items.map((i) => "${i['quantity']}x ${i['service_name'] ?? i['product_name']}").join(', ');
                
                final rawId = t['id'].toString();
                final shortId = rawId.length > 6 ? rawId.substring(rawId.length - 6).toUpperCase() : rawId.toUpperCase();

                String barberName = t['barber_name']?.toString() ?? '';
                if (barberName.isEmpty) {
                  final itemBarbers = items.map((i) => i['barber_name']?.toString()).where((b) => b != null && b.isNotEmpty).toSet().toList();
                  barberName = itemBarbers.isNotEmpty ? itemBarbers.join(', ') : '';
                }

                return [
                  shortId, 
                  DateFormat('dd/MM/yy HH:mm').format(DateTime.parse(t['created_at'])),
                  barberName, 
                  t['client_name'] ?? 'Consumidor Final',
                  itemsStr.length > 30 ? '${itemsStr.substring(0, 30)}...' : itemsStr, 
                  _formatMethod(t['payment_method']?.toString() ?? 'cash'),
                  SettingsService.formatCurrency((t['total'] as num).toDouble()),
                ];
              }).toList(),
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF1E293B)),
              cellStyle: const pw.TextStyle(fontSize: 7),
              cellAlignment: pw.Alignment.centerLeft,
              oddRowDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF1F5F9)),
              headerAlignment: pw.Alignment.centerLeft,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.centerLeft,
                4: pw.Alignment.centerLeft,
                5: pw.Alignment.centerLeft,
                6: pw.Alignment.centerRight, 
              },
            ),
          ];
        },
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 10),
            child: pw.Text('Página ${context.pageNumber} de ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
          );
        },
      ),
    );

    final fileName = 'Reporte_Ventas_${DateFormat('dd-MM-yyyy_HH-mm').format(now)}.pdf';
    final bytes = await pdf.save();
    await Printing.sharePdf(
      bytes: bytes,
      filename: fileName,
    );
  }
  
  pw.Widget _buildPdfSummaryBox(String title, String value) {
    return pw.Container(
      width: 120,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFF8FAFC),
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          pw.SizedBox(height: 4),
          pw.Text(value, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
        ],
      ),
    );
  }

  Future<void> _exportToExcel() async {
    var excel = Excel.createExcel();
    Sheet s = excel['Reporte'];
    s.appendRow([TextCellValue('BBS Club - Reporte ${DateFormat('dd/MM/yyyy').format(_startDate)} - ${DateFormat('dd/MM/yyyy').format(_endDate)}')]);
    s.appendRow([TextCellValue('Total Ventas'), TextCellValue(_totalSales.toString())]);
    s.appendRow([TextCellValue('Transacciones'), TextCellValue(_totalTransactions.toString())]);
    s.appendRow([TextCellValue('Comisiones'), TextCellValue(_totalCommissions.toString())]);
    s.appendRow([TextCellValue('Ganancia Neta'), TextCellValue(_netProfit.toString())]);
    final b = excel.save();
    if (b != null) await Printing.sharePdf(bytes: Uint8List.fromList(b), filename: 'reporte_bbs_${DateFormat('ddMMyyyy').format(DateTime.now())}.xlsx');
  }

  Widget _buildPremiumDropdown({required String label, required IconData icon, required String value, required List<DropdownMenuItem<String>> items, required ValueChanged<String?> onChanged}) {
    return DropdownButtonFormField<String>(
      value: value,
      dropdownColor: const Color(0xFF1E293B),
      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white54, size: 20),
      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54, fontSize: 11),
        floatingLabelStyle: const TextStyle(color: Color(0xFF818CF8), fontSize: 12),
        prefixIcon: Icon(icon, color: const Color(0xFF818CF8), size: 18),
        filled: true,
        fillColor: const Color(0xFF0F172A),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.08))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      items: items,
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!RolePermissions.can(currentUserRole, BbsPerm.viewReports) && !RolePermissions.isAdmin(currentUserRole)) {
      return const Scaffold(backgroundColor: Color(0xFF0F172A), body: Center(child: Text('No tienes permisos para ver esta sección', style: TextStyle(color: Colors.white))));
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B), 
        title: const Text('Reportes Avanzados', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)), 
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: ()=> Navigator.pop(context)), 
        actions: [
          if (RolePermissions.isAdmin(currentUserRole))
            IconButton(
              icon: const Icon(Icons.lock_clock_rounded, color: Color(0xFF10B981)),
              tooltip: 'Cierre por Fechas (Admin)',
              onPressed: _showCierrePorFechasDialog,
            ),
          IconButton(icon: const Icon(Icons.picture_as_pdf, color: Colors.white70), onPressed: _exportToPDF, tooltip: 'PDF'), 
          IconButton(icon: const Icon(Icons.table_chart, color: Colors.white70), onPressed: _exportToExcel, tooltip: 'Excel')
        ]
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1))) : SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        
        // ==== SECCIÓN DE FILTROS DE FECHA ====
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B), 
            borderRadius: BorderRadius.circular(16), 
            border: Border.all(color: Colors.white.withOpacity(0.06)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))]
          ), 
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(
              children: [
                const Icon(Icons.calendar_month_rounded, color: Color(0xFF818CF8), size: 18),
                const SizedBox(width: 8),
                const Text('Período de Análisis', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              ]
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
                  // FIX: Se eliminó la opción 'year' de aquí
                ], 
                selected: {['today', 'week', 'month'].contains(_selectedPeriod) ? _selectedPeriod : 'today'}, 
                onSelectionChanged: (Set<String> v){ _setPeriod(v.first); }
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDateRange, 
              borderRadius: BorderRadius.circular(12), 
              child: Container(
                width: double.infinity, 
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), 
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A), 
                  borderRadius: BorderRadius.circular(12), 
                  border: Border.all(color: _selectedPeriod=='custom'? const Color(0xFF6366F1): Colors.white.withOpacity(0.08))
                ), 
                child: Row(children: [
                  Icon(Icons.date_range_rounded, color: _selectedPeriod=='custom'? const Color(0xFF6366F1): Colors.white38, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: FittedBox(alignment: Alignment.centerLeft, fit: BoxFit.scaleDown, child: Text('${DateFormat('dd/MM/yyyy').format(_startDate)}  →  ${DateFormat('dd/MM/yyyy').format(_endDate)}', style: TextStyle(color: _selectedPeriod=='custom'? Colors.white: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)))),
                  const SizedBox(width: 8),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: Text(_selectedPeriod=='custom'? 'CAMBIAR':'EDITAR', style: const TextStyle(color: Color(0xFF818CF8), fontSize: 10, fontWeight: FontWeight.bold))),
                ])
              )
            ),
          ])
        ),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B), 
            borderRadius: BorderRadius.circular(16), 
            border: Border.all(color: Colors.white.withOpacity(0.06)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))]
          ), 
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.tune_rounded, size: 16, color: Color(0xFF818CF8))),
              const SizedBox(width: 10),
              const Text('Filtros de Búsqueda', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              const Spacer(),
              if (_filterService != 'all' || _filterMethod != 'all' || _searchQuery.isNotEmpty) 
                TextButton.icon(
                  onPressed: _clearFilters, 
                  icon: const Icon(Icons.clear_all_rounded, size: 16, color: Colors.redAccent), 
                  label: const Text('Limpiar', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(backgroundColor: Colors.redAccent.withOpacity(0.1), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4)),
                ),
            ]),
            const SizedBox(height: 16),
            
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 750) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            labelText: 'Buscar folio, barbero, cajero...',
                            labelStyle: const TextStyle(color: Colors.white54, fontSize: 11),
                            prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF818CF8), size: 18),
                            suffixIcon: _searchQuery.isNotEmpty ? IconButton(
                              icon: const Icon(Icons.clear, size: 16, color: Colors.white54), 
                              onPressed: () { 
                                _searchController.clear(); 
                                setState(() => _searchQuery = ''); 
                                _loadReportData(showLoading: false); 
                              }
                            ) : null,
                            filled: true,
                            fillColor: const Color(0xFF0F172A),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.08))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: _buildPremiumDropdown(
                        label: 'Servicio', icon: Icons.content_cut_rounded, value: _filterService, 
                        items: [const DropdownMenuItem(value: 'all', child: Text('Todos los servicios')), ..._allServicesList.map((s) => DropdownMenuItem(value: s, child: Text(s)))], 
                        onChanged: (v) { setState(() => _filterService = v ?? 'all'); _loadReportData(showLoading: false); }
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: _buildPremiumDropdown(
                        label: 'Método de Pago', icon: Icons.payments_rounded, value: _filterMethod, 
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('Todos los métodos')), 
                          DropdownMenuItem(value: 'cash', child: Text('Efectivo')), 
                          DropdownMenuItem(value: 'transfer', child: Text('Transferencia')), 
                          DropdownMenuItem(value: 'card', child: Text('Tarjeta')), 
                          DropdownMenuItem(value: 'mixto', child: Text('Mixto'))
                        ], 
                        onChanged: (v) { setState(() => _filterMethod = v ?? 'all'); _loadReportData(showLoading: false); }
                      )),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      TextField(
                        controller: _searchController, 
                        onChanged: _onSearchChanged,   
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'Buscar folio, barbero, cajero...',
                          labelStyle: const TextStyle(color: Colors.white54, fontSize: 11),
                          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF818CF8), size: 18),
                          suffixIcon: _searchQuery.isNotEmpty ? IconButton(
                            icon: const Icon(Icons.clear, size: 16, color: Colors.white54), 
                            onPressed: () { 
                              _searchController.clear(); 
                              setState(() => _searchQuery = ''); 
                              _loadReportData(showLoading: false); 
                            }
                          ) : null,                          
                          filled: true,
                          fillColor: const Color(0xFF0F172A),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.08))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildPremiumDropdown(
                        label: 'Servicio', icon: Icons.content_cut_rounded, value: _filterService, 
                        items: [const DropdownMenuItem(value: 'all', child: Text('Todos los servicios')), ..._allServicesList.map((s) => DropdownMenuItem(value: s, child: Text(s)))], 
                        onChanged: (v) { setState(() => _filterService = v ?? 'all'); _loadReportData(showLoading: false); }
                      ),
                      const SizedBox(height: 10),
                      _buildPremiumDropdown(
                        label: 'Método de Pago', icon: Icons.payments_rounded, value: _filterMethod, 
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('Todos los métodos')), 
                          DropdownMenuItem(value: 'cash', child: Text('Efectivo')), 
                          DropdownMenuItem(value: 'transfer', child: Text('Transferencia')), 
                          DropdownMenuItem(value: 'card', child: Text('Tarjeta')), 
                          DropdownMenuItem(value: 'mixto', child: Text('Mixto'))
                        ], 
                        onChanged: (v) { setState(() => _filterMethod = v ?? 'all'); _loadReportData(showLoading: false); }
                      ),
                    ],
                  );
                }
              }
            ),
            
            if (_filterService != 'all' || _filterMethod != 'all' || _searchQuery.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.2))),
                  child: Row(children: [
                    const Icon(Icons.info_outline_rounded, color: Color(0xFF818CF8), size: 14),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_filterLabel, style: const TextStyle(color: Color(0xFF818CF8), fontSize: 11, fontWeight: FontWeight.w500))),
                  ]),
                ),
              ),
          ])
        ),
        const SizedBox(height: 20),

        // === TARJETAS DE RESUMEN ===
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 600) {
              return Row(children: [
                Expanded(child: _buildSummaryCard('💵 Ventas', SettingsService.formatCurrency(_totalSales), const Color(0xFF38BDF8))),
                const SizedBox(width: 12),
                Expanded(child: _buildSummaryCard('💰 Comisiones', SettingsService.formatCurrency(_totalCommissions), const Color(0xFFF59E0B))),
                const SizedBox(width: 12),
                Expanded(child: _buildSummaryCard('📈 Ganancia Neta', SettingsService.formatCurrency(_netProfit), const Color(0xFF10B981))),
              ]);
            }
            return Column(children: [
              _buildSummaryCard('💵 Ventas', SettingsService.formatCurrency(_totalSales), const Color(0xFF38BDF8)),
              const SizedBox(height: 10),
              _buildSummaryCard('💰 Comisiones', SettingsService.formatCurrency(_totalCommissions), const Color(0xFFF59E0B)),
              const SizedBox(height: 10),
              _buildSummaryCard('📈 Ganancia Neta', SettingsService.formatCurrency(_netProfit), const Color(0xFF10B981)),
            ]);
          }
        ),
        const SizedBox(height: 20),

        if (_paymentMethods.isNotEmpty) ...[
          const Text('Desglose por Método de Pago', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10, runSpacing: 10,
            children: _paymentMethods.map((m) {
              final method = m['method'].toString();
              final total = (m['total'] as num).toDouble();
              final label = _formatMethod(method);
              IconData icon;
              Color color;
              switch (method) {
                case 'cash': icon = Icons.money_rounded; color = const Color(0xFF10B981); break;
                case 'card': icon = Icons.credit_card_rounded; color = const Color(0xFF3B82F6); break;
                case 'transfer': icon = Icons.swap_horiz_rounded; color = const Color(0xFFF59E0B); break;
                case 'mixto': icon = Icons.call_split_rounded; color = const Color(0xFF8B5CF6); break;
                default: icon = Icons.payments_rounded; color = Colors.grey;
              }
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.3))),
                child: Row(children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: 10),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                    Text(SettingsService.formatCurrency(total), style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w900)),
                  ])
                ]),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
        ],

        if (_topServices.isNotEmpty) ...[
          const Text('Top 5 Servicios / Productos', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.06))),
            child: Column(
              children: _topServices.asMap().entries.map((entry) {
                final idx = entry.key;
                final item = entry.value;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: idx == _topServices.length - 1 ? null : Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05)))
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 24, height: 24,
                        decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.2), shape: BoxShape.circle),
                        child: Center(child: Text('${idx + 1}', style: const TextStyle(color: Color(0xFF818CF8), fontSize: 12, fontWeight: FontWeight.bold))),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(item['name'].toString(), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))),
                      Text(SettingsService.formatCurrency((item['total'] as num).toDouble()), style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),
        ],

        if (_filteredDetail.isNotEmpty) ...[
          const Text('Detalle de Ventas y Comisiones', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ..._filteredDetail.map((d) => Container(
            margin: const EdgeInsets.only(bottom: 8), 
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), 
            decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.06))), 
            child: Row(
              children: [
                Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF818CF8), size: 16)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, 
                    children: [
                      Text(d['service'].toString(), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text('${d['barber']} • x${d['qty']}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                    ]
                  )
                ), 
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(SettingsService.formatCurrency((d['total'] as num).toDouble()), style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 13)),
                    Text('Com: ${SettingsService.formatCurrency((d['commission'] as num).toDouble())}', style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.w600)),
                  ]
                )
              ]
            )
          )),
          const SizedBox(height: 20),
        ],
      ])),
    );
  }

  Widget _buildSummaryCard(String title, String value, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16), 
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B), 
        borderRadius: BorderRadius.circular(16), 
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]
      ), 
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
        ),
      ])
    );
  }
}