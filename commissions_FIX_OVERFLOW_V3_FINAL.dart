import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../services/settings_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class CommissionsScreen extends StatefulWidget {
  @override
  State<CommissionsScreen> createState() => _CommissionsScreenState();
}

class _CommissionsScreenState extends State<CommissionsScreen> {
  bool _isLoading = true;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  List<Map<String, dynamic>> _commissions = [];
  double _totalCommissions = 0;
  double _totalSales = 0;
  String _selectedBarberId = 'all'; // 'all' = todos, si no = barber_id
  List<Map<String, dynamic>> get _filteredCommissions => _selectedBarberId == 'all' ? _commissions : _commissions.where((b) => (b['barber_id']?.toString() ?? '') == _selectedBarberId).toList();
  double get _filteredSales => _filteredCommissions.fold(0.0, (s, b) => s + (b['total_sales'] as double));
  double get _filteredCommissionsTotal => _filteredCommissions.fold(0.0, (s, b) => s + (b['total_commission'] as double));
  int get _filteredServices => _filteredCommissions.fold(0, (s, b) => s + (b['services_count'] as int));

  @override
  void initState() {
    super.initState();
    _loadCommissions();
  }

  Future<void> _loadCommissions() async {
    setState(() { _isLoading = true; });
    try {
      final startStr = _startDate.toIso8601String();
      final endStr = _endDate.add(const Duration(days: 1)).toIso8601String();
      final response = await Supabase.instance.client
          .from('transaction_items')
          .select("barber_id, barber_name, price_at_moment, quantity, commission_earned, transactions!inner(created_at, status)")
          .eq('item_type', 'service')
          .gte('transactions.created_at', startStr)
          .lt('transactions.created_at', endStr)
          .eq('transactions.status', 'completed');
      final items = List<Map<String, dynamic>>.from(response);
      Map<String, Map<String, dynamic>> barberMap = {};
      for (final item in items) {
        final barberId = item['barber_id'] ?? 'unknown';
        final barberName = item['barber_name'] ?? 'Desconocido';
        final price = (item['price_at_moment'] as num?)?.toDouble() ?? 0.0;
        final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
        final commission = (item['commission_earned'] as num?)?.toDouble() ?? 0.0;
        final totalItem = price * quantity;
        if (!barberMap.containsKey(barberId)) {
          barberMap[barberId] = {
            'barber_id': barberId,
            'barber_name': barberName,
            'total_sales': 0.0,
            'total_commission': 0.0,
            'services_count': 0,
          };
        }
        barberMap[barberId]!['total_sales'] = (barberMap[barberId]!['total_sales'] as double) + totalItem;
        barberMap[barberId]!['total_commission'] = (barberMap[barberId]!['total_commission'] as double) + commission;
        barberMap[barberId]!['services_count'] = (barberMap[barberId]!['services_count'] as int) + quantity;
      }
      final commissions = barberMap.values.toList();
      commissions.sort((a, b) => (b['total_commission'] as double).compareTo(a['total_commission'] as double));
      final totalCommissions = commissions.fold(0.0, (sum, c) => sum + (c['total_commission'] as double));
      final totalSales = commissions.fold(0.0, (sum, c) => sum + (c['total_sales'] as double));
      setState(() {
        _commissions = commissions;
        _totalCommissions = totalCommissions;
        _totalSales = totalSales;
        _isLoading = false;
      });
    } catch (e) {
      print('Error comisiones: $e');
      setState(() { _isLoading = false; });
    }
  }

  // ===== COMPROBANTE DE PAGO DE COMISION - 80mm =====
  void _showComprobanteDialog(Map<String, dynamic> barber) {
    final name = barber['barber_name'] as String;
    final sales = barber['total_sales'] as double;
    final commission = barber['total_commission'] as double;
    final count = barber['services_count'] as int;
    final rate = sales > 0 ? (commission / sales * 100) : 0.0;
    final period = "${DateFormat('dd/MM/yyyy').format(_startDate)} - ${DateFormat('dd/MM/yyyy').format(_endDate)}";
    final folio = 'COM-${DateTime.now().millisecondsSinceEpoch}';
    showDialog(context: context, builder: (ctx) => Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        width: 340,
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(children: [
            Text((SettingsService.shopName.isNotEmpty ? SettingsService.shopName : 'BBS CLUB').toUpperCase(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
            const Text('COMPROBANTE DE PAGO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.black54)),
            const Text('Comisión de Barbero', style: TextStyle(fontSize: 10, color: Colors.black54)),
            const SizedBox(height: 10),
            const Divider(color: Colors.black26, height: 1),
            const SizedBox(height: 10),
            _comprobanteRow('Folio:', folio),
            _comprobanteRow('Fecha:', DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())),
            _comprobanteRow('Periodo:', period),
            const SizedBox(height: 10),
            const Divider(color: Colors.black26, height: 1),
            const SizedBox(height: 10),
            _comprobanteRow('Barbero:', name),
            _comprobanteRow('Servicios:', '$count servicios'),
            _comprobanteRow('Ventas:', SettingsService.formatCurrency(sales)),
            _comprobanteRow('% Comisión:', '${rate.toStringAsFixed(1)}%'),
            const SizedBox(height: 10),
            Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12), decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('TOTAL A PAGAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)), Text(SettingsService.formatCurrency(commission), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))])),
            const SizedBox(height: 18),
            Row(children: const [Expanded(child: Column(children: [Divider(color: Colors.black54), SizedBox(height: 4), Text('Firma Barbero', style: TextStyle(fontSize: 10, color: Colors.black54))])), SizedBox(width: 16), Expanded(child: Column(children: [Divider(color: Colors.black54), SizedBox(height: 4), Text('Firma Admin', style: TextStyle(fontSize: 10, color: Colors.black54))]))]),
            const SizedBox(height: 6),
            Text('Recibí conforme ${SettingsService.formatCurrency(commission)} por comisiones del periodo.', style: const TextStyle(fontSize: 9, color: Colors.black54), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar'))),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton.icon(onPressed: () { Navigator.pop(ctx); _printComprobante(barber, folio, period); }, icon: const Icon(Icons.print_rounded, size: 16), label: const Text('Imprimir', style: TextStyle(fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)))),
            ]),
          ]),
        ),
      ),
    ));
  }

  Widget _comprobanteRow(String label, String value) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)), Flexible(child: Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black), textAlign: TextAlign.right))]));
  }

  Future<void> _printComprobante(Map<String, dynamic> barber, String folio, String period) async {
    final name = barber['barber_name'] as String;
    final sales = barber['total_sales'] as double;
    final commission = barber['total_commission'] as double;
    final count = barber['services_count'] as int;
    final rate = sales > 0 ? (commission / sales * 100) : 0.0;
    final pdf = pw.Document();
    pdf.addPage(pw.Page(
      pageFormat: const PdfPageFormat(80 * PdfPageFormat.mm, double.infinity, marginLeft: 2 * PdfPageFormat.mm, marginRight: 2 * PdfPageFormat.mm, marginTop: 3 * PdfPageFormat.mm, marginBottom: 3 * PdfPageFormat.mm),
      build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
        pw.Text((SettingsService.shopName.isNotEmpty ? SettingsService.shopName : 'BBS CLUB').toUpperCase(), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
        pw.Text('COMPROBANTE DE PAGO', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        pw.Text('Comisión de Barbero', style: const pw.TextStyle(fontSize: 9)),
        pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Folio:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)), pw.Text(folio, style: const pw.TextStyle(fontSize: 9))]),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Fecha:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)), pw.Text(DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()), style: const pw.TextStyle(fontSize: 10))]),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Periodo:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)), pw.Text(period, style: const pw.TextStyle(fontSize: 9))]),
        pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Barbero:', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)), pw.Text(name, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold))]),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Servicios:', style: const pw.TextStyle(fontSize: 10)), pw.Text('$count servicios', style: const pw.TextStyle(fontSize: 10))]),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Ventas:', style: const pw.TextStyle(fontSize: 10)), pw.Text(SettingsService.formatCurrency(sales), style: const pw.TextStyle(fontSize: 10))]),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('% Comisión:', style: const pw.TextStyle(fontSize: 10)), pw.Text('${rate.toStringAsFixed(1)}%', style: const pw.TextStyle(fontSize: 10))]),
        pw.SizedBox(height: 3 * PdfPageFormat.mm),
        pw.Container(padding: pw.EdgeInsets.symmetric(vertical: 3 * PdfPageFormat.mm, horizontal: 3 * PdfPageFormat.mm), decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)), child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('TOTAL A PAGAR', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)), pw.Text(SettingsService.formatCurrency(commission), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold))])),
        pw.SizedBox(height: 6 * PdfPageFormat.mm),
        pw.Row(children: [pw.Expanded(child: pw.Column(children: [pw.Divider(), pw.Text('Firma Barbero', style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.center)])), pw.SizedBox(width: 4 * PdfPageFormat.mm), pw.Expanded(child: pw.Column(children: [pw.Divider(), pw.Text('Firma Admin', style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.center)]))]),
        pw.SizedBox(height: 3 * PdfPageFormat.mm),
        pw.Text('Recibí conforme ${SettingsService.formatCurrency(commission)} por comisiones del periodo.', style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center),
        pw.SizedBox(height: 2 * PdfPageFormat.mm),
        pw.Text('¡Gracias!', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
      ]),
    ));
    await Printing.layoutPdf(onLayout: (f) async => pdf.save(), name: 'Comprobante-Comision-$name.pdf');
  }

  Future<void> _selectDateRange() async {
    final initialDateRange = DateTimeRange(start: _startDate, end: _endDate);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: initialDateRange,
      locale: const Locale('es'),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF6366F1),
              onPrimary: Colors.white,
              surface: Color(0xFF1E293B),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF0F172A),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadCommissions();
    }
  }

  void _setQuickFilter(String period) {
    final now = DateTime.now();
    DateTime start;
    switch (period) {
      case 'today':
        start = DateTime(now.year, now.month, now.day);
        break;
      case 'week':
        start = now.subtract(Duration(days: now.weekday - 1));
        start = DateTime(start.year, start.month, start.day);
        break;
      case 'month':
        start = DateTime(now.year, now.month, 1);
        break;
      case 'last_month':
        start = DateTime(now.year, now.month - 1, 1);
        _endDate = DateTime(now.year, now.month, 0);
        break;
      default:
        start = now.subtract(const Duration(days: 30));
    }
    setState(() {
      _startDate = start;
      if (period != 'last_month') _endDate = now;
    });
    _loadCommissions();
  }

  bool _isPeriodSelected(String period) {
    final now = DateTime.now();
    switch (period) {
      case 'today':
        return _startDate.year == now.year && _startDate.month == now.month && _startDate.day == now.day;
      case 'week':
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        return _startDate.year == weekStart.year && _startDate.month == weekStart.month && _startDate.day == weekStart.day;
      case 'month':
        return _startDate.year == now.year && _startDate.month == now.month && _startDate.day == 1;
      case 'last_month':
        return _startDate.year == now.year && _startDate.month == now.month - 1 && _startDate.day == 1;
      default:
        return false;
    }
  }

  Widget _buildBarberFilterChip(String id, String label) {
    final selected = _selectedBarberId == id;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label, style: TextStyle(color: selected ? Colors.white : Colors.white70, fontSize: 11, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
        selected: selected,
        onSelected: (_) => setState(() => _selectedBarberId = id),
        backgroundColor: const Color(0xFF0F172A),
        selectedColor: const Color(0xFF6366F1),
        checkmarkColor: Colors.white,
        side: BorderSide(color: selected ? const Color(0xFF6366F1) : Colors.white10),
      ),
    );
  }

  Widget _buildFilterChip(String label, String period) {
    final isSelected = _isPeriodSelected(period);
    return FilterChip(
      label: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.white54, fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      onSelected: (_) => _setQuickFilter(period),
      backgroundColor: const Color(0xFF1E293B),
      selectedColor: const Color(0xFF6366F1),
      checkmarkColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isSelected ? const Color(0xFF6366F1) : Colors.white10)),
    );
  }

  Widget _buildSummaryCards() {
    return Row(children: [
      Expanded(child: _summaryCard('Total Ventas', SettingsService.formatCurrency(_filteredSales), '💰', const Color(0xFF3B82F6))),
      const SizedBox(width: 12),
      Expanded(child: _summaryCard('Comisiones', SettingsService.formatCurrency(_filteredCommissionsTotal), '💸', const Color(0xFF10B981))),
    ]);
  }

  Widget _summaryCard(String title, String value, String icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.05)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: Text(icon, style: const TextStyle(fontSize: 16))), const Spacer(), Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle))]),
        const SizedBox(height: 12),
        Text(title, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      ]),
    );
  }

  Widget _buildBarberCard(Map<String, dynamic> barber, int position) {
    final barberName = barber['barber_name'] as String;
    final totalSales = barber['total_sales'] as double;
    final totalCommission = barber['total_commission'] as double;
    final servicesCount = barber['services_count'] as int;
    final commissionRate = totalSales > 0 ? (totalCommission / totalSales * 100) : 0.0;
    final medals = ['🥇', '🥈', '🥉'];
    final medal = position <= 3 ? medals[position - 1] : '#$position';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.05)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(medal, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(barberName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)), Text('$servicesCount servicios', style: const TextStyle(color: Colors.white54, fontSize: 11))])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3))), child: Text('${commissionRate.toStringAsFixed(1)}%', style: const TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold, fontSize: 11))),
        ]),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Ventas', style: TextStyle(fontSize: 10, color: Colors.white38)), const SizedBox(height: 2), Text(SettingsService.formatCurrency(totalSales), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white))]),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [const Text('Comision a pagar', style: TextStyle(fontSize: 10, color: Colors.white38)), const SizedBox(height: 2), Text(SettingsService.formatCurrency(totalCommission), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF10B981)))]),
        ]),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, height: 40, child: ElevatedButton.icon(onPressed: () => _showComprobanteDialog(barber), icon: const Icon(Icons.print_rounded, size: 16), label: const Text('Imprimir comprobante para pagar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))))),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateRangeText = "${DateFormat('dd/MM/yyyy').format(_startDate)} - ${DateFormat('dd/MM/yyyy').format(_endDate)}";
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: const Text('Comisiones Premium', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [IconButton(icon: const Icon(Icons.sync_rounded, color: Colors.white), onPressed: _loadCommissions)],
      ),
      body: Column(children: [
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF1E293B), Color(0xFF312E81)]), borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 8))]),
          child: Column(children: [
            Row(children: [
              const Text('📅', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(child: FittedBox(alignment: Alignment.centerLeft, fit: BoxFit.scaleDown, child: Text(dateRangeText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)))),
              Container(decoration: BoxDecoration(color: const Color(0xFF6366F1), borderRadius: BorderRadius.circular(10)), child: TextButton.icon(onPressed: _selectDateRange, icon: const Icon(Icons.calendar_month_rounded, size: 16, color: Colors.white), label: const Text('Rango', style: TextStyle(color: Colors.white, fontSize: 12)), style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)))),
            ]),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [_buildFilterChip('Hoy', 'today'), _buildFilterChip('Esta semana', 'week'), _buildFilterChip('Este mes', 'month'), _buildFilterChip('Mes anterior', 'last_month'), _buildFilterChip('Ultimos 30 dias', 'last_30')]),
          ]),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.05))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text('💈 Filtrar por barbero', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              const Spacer(),
              if (_selectedBarberId != 'all') TextButton(onPressed: () => setState(() => _selectedBarberId = 'all'), child: const Text('Limpiar ✕', style: TextStyle(color: Colors.white54, fontSize: 11))),
            ]),
            const SizedBox(height: 8),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10), decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(10)), child: DropdownButtonHideUnderline(child: DropdownButton<String>(
              value: _selectedBarberId,
              dropdownColor: const Color(0xFF1E293B),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              isExpanded: true,
              items: [
                const DropdownMenuItem(value: 'all', child: Text('👥 Todos los barberos')),
                ..._commissions.map((b) => DropdownMenuItem(value: b['barber_id'].toString(), child: Text('💈 ${b['barber_name']}  •  ${SettingsService.formatCurrency(b['total_commission'] as double)}'))),
              ],
              onChanged: (v) => setState(() => _selectedBarberId = v ?? 'all'),
            ))),
            const SizedBox(height: 8),
            SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
              _buildBarberFilterChip('all', 'Todos'),
              ..._commissions.map((b) => _buildBarberFilterChip(b['barber_id'].toString(), b['barber_name'] as String)),
            ])),
            if (_selectedBarberId != 'all' && _filteredCommissions.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => _showComprobanteDialog(_filteredCommissions.first), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.print_rounded, size: 16, color: Colors.white), const SizedBox(width: 8), Expanded(child: Column(mainAxisSize: MainAxisSize.min, children: [Text('Imprimir comprobante de ${_filteredCommissions.first['barber_name']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis), Text(SettingsService.formatCurrency(_filteredCommissionsTotal), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white), textAlign: TextAlign.center)]))]))),
            ],
          ]),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
              : _commissions.isEmpty
                  ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('💰', style: TextStyle(fontSize: 56)), SizedBox(height: 12), Text('No hay comisiones en este periodo', style: TextStyle(color: Colors.white54, fontSize: 14))]))
                  : ListView(padding: const EdgeInsets.symmetric(horizontal: 16), children: [_buildSummaryCards(), const SizedBox(height: 16), const Text('Detalle por Barbero', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)), const SizedBox(height: 10), ..._filteredCommissions.asMap().entries.map((e) => _buildBarberCard(e.value, e.key + 1))]),
        ),
      ]),
    );
  }
}
