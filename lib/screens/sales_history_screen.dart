import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../services/settings_service.dart';
import '../main.dart'; 
import '../services/role_permissions.dart'; 

class SalesHistoryScreen extends StatefulWidget {
  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> with TickerProviderStateMixin {
  bool _isLoading = true;
  List<Map<String, dynamic>> _transactions = [];
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();
  String _searchQuery = '';
  String _filterBarber = 'all';
  String _filterMethod = 'all';
  String _filterStatus = 'all';
  
  List<Map<String, dynamic>> get _filteredTransactions {
    var list = _transactions;
    if (_filterBarber != 'all') list = list.where((tr) => (tr['barber_name'] ?? '').toString() == _filterBarber).toList();
    if (_filterMethod != 'all') list = list.where((tr) => (tr['payment_method'] ?? '').toString() == _filterMethod).toList();
    if (_filterStatus != 'all') list = list.where((tr) => (tr['status'] ?? 'completed').toString() == _filterStatus).toList();
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list.where((tr) => (tr['id'] ?? '').toString().toLowerCase().contains(q) || (tr['barber_name'] ?? '').toString().toLowerCase().contains(q) || (tr['cashier_name'] ?? '').toString().toLowerCase().contains(q) || _formatPayment(tr['payment_method']?.toString()).toLowerCase().contains(q)).toList();
    }
    return list;
  }
  
  List<String> get _allBarbersHist { final s = <String>{}; for (final tr in _transactions) { final b = (tr['barber_name'] ?? '').toString(); if (b.isNotEmpty) s.add(b); } final l = s.toList()..sort(); return l; }
  double get _filteredTotal => _filteredTransactions.fold(0.0, (s, tr) => s + ((tr['total'] as num?)?.toDouble() ?? 0.0));
  void _clearHistFilters() { setState(() { _searchQuery = ''; _filterBarber = 'all'; _filterMethod = 'all'; _filterStatus = 'all'; }); }
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _loadTransactions();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);
    try {
      final startStr = DateTime(_startDate.year, _startDate.month, _startDate.day).toIso8601String();
      final endStr = DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59).toIso8601String();
      final res = await Supabase.instance.client.from('transactions').select('*').gte('created_at', startStr).lte('created_at', endStr).order('created_at', ascending: false);
      setState(() {
        _transactions = List<Map<String, dynamic>>.from(res);
        _isLoading = false;
      });
      _ctrl.forward(from: 0);
    } catch (e) {
      debugPrint('❌ Error: $e');
      setState(() => _isLoading = false);
    }
  }

  String _formatPayment(String? p) {
    switch (p) {
      case 'cash': return 'Efectivo';
      case 'card': return 'Tarjeta';
      case 'transfer': return 'Transferencia';
      case 'debito': return 'Débito';
      case 'mixto':
      case 'mixed': return 'Mixto';
      default: return p ?? 'Efectivo';
    }
  }

  Future<void> _showTransactionDetail(Map<String, dynamic> transaction) async {
    final transactionId = transaction['id'];
    List<Map<String, dynamic>> items = [];
    try {
      final itemsResponse = await Supabase.instance.client.from('transaction_items').select('*').eq('transaction_id', transactionId);
      items = List<Map<String, dynamic>>.from(itemsResponse);
    } catch (_) {}

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.88,
        decoration: const BoxDecoration(color: Color(0xFF0F172A), borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(color: Color(0xFF6366F1), borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            child: Row(children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 18)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Detalle de Venta', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                Text(DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(transaction['created_at'])), style: const TextStyle(color: Colors.white70, fontSize: 11)),
              ])),
              Container(decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: IconButton(icon: const Icon(Icons.print_rounded, color: Colors.white, size: 20), tooltip: 'Imprimir 80mm', onPressed: () => _printTicket(transaction, items))),
            ]),
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.all(16), children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.06))),
                child: Column(children: [
                  _infoRow('ID', transaction['id'].toString().length > 26 ? '${transaction['id'].toString().substring(0, 26)}...' : transaction['id'].toString()),
                  const Divider(color: Colors.white10, height: 18),
                  _infoRow('Cajero', transaction['cashier_name']?.toString() ?? 'N/A'),
                  _infoRow('Barbero', transaction['barber_name']?.toString() ?? 'N/A'),
                  _infoRow('Pago', _formatPayment(transaction['payment_method']?.toString())),
                  if ((transaction['cash_received'] as num?) != null && (transaction['cash_received'] as num) > 0) _infoRow('Recibido', SettingsService.formatCurrency((transaction['cash_received'] as num).toDouble())),
                  if ((transaction['change_amount'] as num?) != null && (transaction['change_amount'] as num) > 0) _infoRow('Vuelto', SettingsService.formatCurrency((transaction['change_amount'] as num).toDouble())),
                  if (transaction['status'] != null && transaction['status'] != 'completed') _infoRow('Estado', transaction['status'].toString(), isStatus: true),
                ]),
              ),
              const SizedBox(height: 18),
              const Text('ITEMS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.2)),
              const SizedBox(height: 10),
              ...items.map((item) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.04))),
                child: Row(children: [
                  Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(8)), child: Icon(item['item_type'] == 'service' ? Icons.content_cut_rounded : Icons.inventory_2_rounded, size: 14, color: Colors.white54)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(item['service_name'] ?? item['product_name'] ?? 'Item', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('\$${item['price_at_moment']} x${item['quantity']}', style: const TextStyle(color: Colors.white54, fontSize: 10)),
                    Text(SettingsService.formatCurrency((item['price_at_moment'] as num).toDouble() * (item['quantity'] as num).toInt()), style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12)),
                  ]),
                ]),
              )),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withOpacity(0.06))),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('TOTAL:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                  Text(SettingsService.formatCurrency((transaction['total'] as num).toDouble()), style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w900, fontSize: 22)),
                ]),
              ),
              const SizedBox(height: 20),
              
              if (RolePermissions.isAdmin(currentUserRole)) ...[
                Row(children: [
                  Expanded(child: OutlinedButton.icon(onPressed: () { Navigator.pop(context); _showEditPaymentDialog(transaction); }, icon: const Icon(Icons.edit_rounded, size: 16, color: Color(0xFF818CF8)), label: const Text('Editar Pago', style: TextStyle(color: Color(0xFF818CF8), fontSize: 12, fontWeight: FontWeight.bold)), style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF6366F1)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 13)))),
                  const SizedBox(width: 8),
                  Expanded(child: OutlinedButton.icon(onPressed: transaction['status'] == 'cancelled' ? null : () { Navigator.pop(context); _showAnularDialog(transaction, items); }, icon: const Icon(Icons.cancel_rounded, size: 16, color: Colors.redAccent), label: const Text('Anular', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)), style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 13)))),
                ]),
                const SizedBox(height: 10),
              ],
              
              Row(children: [
                Expanded(child: OutlinedButton.icon(onPressed: () => _printTicket(transaction, items), icon: const Icon(Icons.print_rounded, size: 18, color: Colors.white70), label: const Text('Imprimir 80mm', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)), style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white24), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)))),
                const SizedBox(width: 10),
                Expanded(child: Container(decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF818CF8)]), borderRadius: BorderRadius.circular(12)), child: ElevatedButton.icon(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.check_rounded, size: 16), label: const Text('Cerrar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14))))),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _infoRow(String label, String value, {bool isStatus = false}) {
    Color valColor = Colors.white;
    if (isStatus) {
      if (value == 'cancelled' || value == 'anulado') valColor = Colors.redAccent;
      else valColor = const Color(0xFF10B981);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        Flexible(child: Text(value, style: TextStyle(color: valColor, fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.right, overflow: TextOverflow.ellipsis)),
      ]),
    );
  }

  Future<void> _showEditPaymentDialog(Map<String, dynamic> transaction) async {
    String selected = transaction['payment_method']?.toString() ?? 'cash';
    if (selected == 'mixed') selected = 'mixto';

    await showDialog(context: context, builder: (c) => AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Editar Pago', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      content: StatefulBuilder(builder: (ctx, setSt) => DropdownButtonFormField<String>(
        value: selected,
        dropdownColor: const Color(0xFF1E293B),
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        decoration: InputDecoration(filled: true, fillColor: const Color(0xFF0F172A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), labelText: 'Método', labelStyle: const TextStyle(color: Colors.white54)),
        items: const [
          DropdownMenuItem(value: 'cash', child: Text('Efectivo')),
          DropdownMenuItem(value: 'transfer', child: Text('Transferencia')),
          DropdownMenuItem(value: 'card', child: Text('Tarjeta')),
          DropdownMenuItem(value: 'debito', child: Text('Débito')),
          DropdownMenuItem(value: 'mixto', child: Text('Mixto')),
        ],
        onChanged: (v) => setSt(() => selected = v!),
      )),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
        Container(decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF818CF8)]), borderRadius: BorderRadius.circular(10)), child: ElevatedButton(onPressed: () async {
          Navigator.pop(c);
          try {
            await Supabase.instance.client.from('transactions').update({'payment_method': selected}).eq('id', transaction['id']);
            await _loadTransactions();
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Pago actualizado'), backgroundColor: Color(0xFF10B981)));
          } catch (e) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ $e'), backgroundColor: Colors.red));
          }
        }, style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent), child: const Text('Guardar'))),
      ],
    ));
  }

  Future<void> _showAnularDialog(Map<String, dynamic> transaction, List<Map<String, dynamic>> items) async {
    final motivoCtrl = TextEditingController();
    bool devolverStock = true;
    await showDialog(context: context, builder: (c) => StatefulBuilder(builder: (ctx, setSt) => AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(children: [Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.red.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.warning_rounded, color: Colors.redAccent, size: 18)), const SizedBox(width: 10), const Text('Anular Venta', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))]),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('¿Anular ${SettingsService.formatCurrency((transaction['total'] as num).toDouble())}?', style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 14),
        TextField(controller: motivoCtrl, style: const TextStyle(color: Colors.white, fontSize: 13), maxLines: 2, decoration: InputDecoration(labelText: 'Motivo *', labelStyle: const TextStyle(color: Colors.white54, fontSize: 12), filled: true, fillColor: const Color(0xFF0F172A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
        const SizedBox(height: 10),
        Material(
          type: MaterialType.transparency,
          child: CheckboxListTile(value: devolverStock, onChanged: (v) => setSt(() => devolverStock = v!), title: const Text('Devolver stock', style: TextStyle(color: Colors.white70, fontSize: 12)), activeColor: const Color(0xFF10B981), contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
        Container(decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)), child: ElevatedButton(onPressed: () async {
          if (motivoCtrl.text.trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ Motivo obligatorio'), backgroundColor: Colors.orange));
            return;
          }
          Navigator.pop(c);
          try {
            await Supabase.instance.client.from('transactions').update({'status': 'cancelled', 'cancel_reason': motivoCtrl.text.trim(), 'cancelled_at': DateTime.now().toIso8601String()}).eq('id', transaction['id']);
            if (devolverStock) {
              for (final item in items) {
                if (item['item_type'] == 'product' && item['product_id'] != null) {
                  try {
                    final prod = await Supabase.instance.client.from('products').select('stock').eq('id', item['product_id']).single();
                    final cur = (prod['stock'] as num).toInt();
                    final qty = (item['quantity'] as num).toInt();
                    await Supabase.instance.client.from('products').update({'stock': cur + qty}).eq('id', item['product_id']);
                  } catch (_) {}
                }
              }
            }
            await _loadTransactions();
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Anulada'), backgroundColor: Colors.orange));
          } catch (e) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ $e'), backgroundColor: Colors.red));
          }
        }, style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent), child: const Text('Anular'))),
      ],
    )));
  }

  Future<void> _printTicket(Map<String, dynamic> transaction, List<Map<String, dynamic>> items) async {
    try {
      const businessName = 'BBS CLUB';
      const businessAddress = 'Manuel Montt #460, local 6 - Coronel';
      const businessPhone = 'Tel: +569 6106 9670';

      final pdf = pw.Document();
      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat(80 * PdfPageFormat.mm, double.infinity, marginAll: 4 * PdfPageFormat.mm),
        build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
          pw.Container(
            decoration: pw.BoxDecoration(border: pw.Border.all(width: 2)),
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: pw.Text('BBSCLUB\'\nBARBERIA', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12), textAlign: pw.TextAlign.center),
          ),
          pw.SizedBox(height: 6),
          pw.Text(businessName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
          pw.Text(businessAddress, style: const pw.TextStyle(fontSize: 7), textAlign: pw.TextAlign.center),
          pw.Text(businessPhone, style: const pw.TextStyle(fontSize: 7), textAlign: pw.TextAlign.center),
          pw.SizedBox(height: 6), pw.Divider(),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Fecha:', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)), pw.Text(DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(transaction['created_at'])), style: const pw.TextStyle(fontSize: 7))]),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Cajero:', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)), pw.Text(transaction['cashier_name']?.toString() ?? '', style: const pw.TextStyle(fontSize: 7))]),
          pw.Divider(),
          ...items.map((it) => pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 2), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(it['service_name'] ?? it['product_name'] ?? 'Item', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('${it['quantity']} x ${SettingsService.formatCurrency((it['price_at_moment'] as num).toDouble())}', style: const pw.TextStyle(fontSize: 7)), pw.Text(SettingsService.formatCurrency((it['price_at_moment'] as num).toDouble() * (it['quantity'] as num).toInt()), style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))]),
          ]))),
          pw.Divider(),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('TOTAL:', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)), pw.Text(SettingsService.formatCurrency((transaction['total'] as num).toDouble()), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold))]),
          pw.SizedBox(height: 4),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Pago:', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)), pw.Text(_formatPayment(transaction['payment_method']?.toString()), style: const pw.TextStyle(fontSize: 7))]),
          pw.SizedBox(height: 10),
          pw.Text('¡Gracias por su visita!', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
        ]),
      ));
      await Printing.layoutPdf(onLayout: (_) async => pdf.save(), name: 'Ticket', format: PdfPageFormat(80 * PdfPageFormat.mm, double.infinity));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(context: context, firstDate: DateTime(2023), lastDate: DateTime.now().add(const Duration(days: 1)), initialDateRange: DateTimeRange(start: _startDate, end: _endDate), builder: (c, child) => Theme(data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: Color(0xFF6366F1))), child: child!));
    if (picked != null) {
      setState(() { _startDate = picked.start; _endDate = picked.end; });
      await _loadTransactions();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: const Text('Historial Premium', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
        centerTitle: true,
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 20), onPressed: _loadTransactions),
          IconButton(icon: const Icon(Icons.calendar_month_rounded, color: Colors.white70, size: 20), onPressed: _selectDateRange),
        ],
      ),
      body: Column(children: [
        Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFF312E81), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.2))),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.2), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF818CF8))),
            const SizedBox(width: 10),
            Text('${DateFormat('dd/MM/yyyy').format(_startDate)} - ${DateFormat('dd/MM/yyyy').format(_endDate)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            const Spacer(),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.2), borderRadius: BorderRadius.circular(20)), child: Text('${_transactions.length} ventas', style: const TextStyle(color: Color(0xFF818CF8), fontSize: 11, fontWeight: FontWeight.bold))),
          ]),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.06))),
          child: Column(children: [
            TextField(onChanged: (v) => setState(() => _searchQuery = v), style: const TextStyle(color: Colors.white, fontSize: 13), decoration: InputDecoration(hintText: 'Buscar folio, barbero, cajero...', hintStyle: const TextStyle(color: Colors.white38, fontSize: 12), prefixIcon: const Icon(Icons.search_rounded, color: Colors.white38, size: 18), filled: true, fillColor: const Color(0xFF0F172A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10))),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: DropdownButtonFormField<String>(value: _filterBarber, dropdownColor: const Color(0xFF1E293B), style: const TextStyle(color: Colors.white, fontSize: 12), decoration: InputDecoration(labelText: 'Barbero', labelStyle: const TextStyle(color: Colors.white54, fontSize: 11), filled: true, fillColor: const Color(0xFF0F172A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)), items: [const DropdownMenuItem(value: 'all', child: Text('Todos')), ..._allBarbersHist.map((b) => DropdownMenuItem(value: b, child: Text(b)))], onChanged: (v) => setState(() => _filterBarber = v ?? 'all'))),
              const SizedBox(width: 8),
              Expanded(child: DropdownButtonFormField<String>(value: _filterMethod, dropdownColor: const Color(0xFF1E293B), style: const TextStyle(color: Colors.white, fontSize: 12), decoration: InputDecoration(labelText: 'Método', labelStyle: const TextStyle(color: Colors.white54, fontSize: 11), filled: true, fillColor: const Color(0xFF0F172A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)), items: const [DropdownMenuItem(value: 'all', child: Text('Todos')), DropdownMenuItem(value: 'cash', child: Text('Efectivo')), DropdownMenuItem(value: 'transfer', child: Text('Transferencia')), DropdownMenuItem(value: 'card', child: Text('Tarjeta')), DropdownMenuItem(value: 'debito', child: Text('Débito')), DropdownMenuItem(value: 'mixto', child: Text('Mixto'))], onChanged: (v) => setState(() => _filterMethod = v ?? 'all'))),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: DropdownButtonFormField<String>(value: _filterStatus, dropdownColor: const Color(0xFF1E293B), style: const TextStyle(color: Colors.white, fontSize: 12), decoration: InputDecoration(labelText: 'Estado', labelStyle: const TextStyle(color: Colors.white54, fontSize: 11), filled: true, fillColor: const Color(0xFF0F172A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)), items: const [DropdownMenuItem(value: 'all', child: Text('Todos')), DropdownMenuItem(value: 'completed', child: Text('Completadas')), DropdownMenuItem(value: 'cancelled', child: Text('Anuladas'))], onChanged: (v) => setState(() => _filterStatus = v ?? 'all'))),
              const SizedBox(width: 8),
              Expanded(child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: Text('${_filteredTransactions.length} de ${_transactions.length} • ${SettingsService.formatCurrency(_filteredTotal)}', style: const TextStyle(color: Color(0xFF818CF8), fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center))),
            ]),
            if (_searchQuery.isNotEmpty || _filterBarber != 'all' || _filterMethod != 'all' || _filterStatus != 'all') Padding(padding: const EdgeInsets.only(top: 10), child: GestureDetector(onTap: _clearHistFilters, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.red.withOpacity(0.15), borderRadius: BorderRadius.circular(20)), child: const Text('Limpiar filtros ✕', style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold))))),
          ]),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
              : _filteredTransactions.isEmpty
                  ? const Center(child: Text('No hay ventas', style: TextStyle(color: Colors.white38)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _filteredTransactions.length,
                      itemBuilder: (c, i) {
                        final t = _filteredTransactions[i];
                        final isCancelled = t['status'] == 'cancelled';
                        return AnimatedBuilder(
                          animation: _ctrl,
                          builder: (context, child) {
                            final delay = i * 0.03;
                            final anim = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _ctrl, curve: Interval(delay, 0.7 + delay, curve: Curves.easeOutCubic)));
                            return FadeTransition(opacity: anim, child: SlideTransition(position: Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(anim), child: child));
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(14), border: Border.all(color: isCancelled ? Colors.red.withOpacity(0.2) : Colors.white.withOpacity(0.05))),
                            child: Material(
                              type: MaterialType.transparency,
                              child: ListTile(
                                onTap: () => _showTransactionDetail(t),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                leading: Container(width: 38, height: 38, decoration: BoxDecoration(color: isCancelled ? Colors.red.withOpacity(0.15) : const Color(0xFF6366F1).withOpacity(0.15), shape: BoxShape.circle), child: Icon(isCancelled ? Icons.cancel_rounded : Icons.receipt_rounded, size: 18, color: isCancelled ? Colors.redAccent : const Color(0xFF818CF8))),
                                title: Text(DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(t['created_at'])), style: TextStyle(fontWeight: FontWeight.bold, color: isCancelled ? Colors.white54 : Colors.white, fontSize: 13, decoration: isCancelled ? TextDecoration.lineThrough : null)),
                                subtitle: Text('${_formatPayment(t['payment_method']?.toString())} • ${t['barber_name'] ?? ''} • ${t['cashier_name'] ?? ''}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                                trailing: Text(SettingsService.formatCurrency((t['total'] as num).toDouble()), style: TextStyle(color: isCancelled ? Colors.white38 : const Color(0xFF10B981), fontWeight: FontWeight.w900, fontSize: 14, decoration: isCancelled ? TextDecoration.lineThrough : null)),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ]),
    );
  }
}