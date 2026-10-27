import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:http/http.dart' as http;
import '../services/settings_service.dart';

class SalesHistoryScreen extends StatefulWidget {
  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _transactions = [];
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredTransactions {
    if (_searchQuery.trim().isEmpty) return _transactions;
    final q = _searchQuery.trim().toLowerCase();
    return _transactions.where((t) {
      final id = (t['id'] ?? '').toString().toLowerCase();
      final cashier = (t['cashier_name'] ?? '').toString().toLowerCase();
      final barber = (t['barber_name'] ?? '').toString().toLowerCase();
      final method = _formatPaymentMethod(t['payment_method'] ?? '').toLowerCase();
      return id.contains(q) || cashier.contains(q) || barber.contains(q) || method.contains(q);
    }).toList();
  }

  Future<void> _loadTransactions() async {
    setState(() { _isLoading = true; });
    try {
      final startStr = _startDate.toIso8601String();
      final endStr = _endDate.add(const Duration(days: 1)).toIso8601String();
      final response = await Supabase.instance.client
          .from('transactions')
          .select('*')
          .gte('created_at', startStr)
          .lte('created_at', endStr)
          .eq('status', 'completed')
          .order('created_at', ascending: false);
      setState(() {
        _transactions = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      print('Error al cargar ventas: $e');
      setState(() { _isLoading = false; });
    }
  }

  IconData _paymentIcon(String? method) {
    switch (method) {
      case 'cash': return Icons.payments;
      case 'card': return Icons.credit_card;
      case 'transfer': return Icons.phone_android;
      default: return Icons.receipt_long;
    }
  }

  String _formatPaymentMethod(String method) {
    switch (method) {
      case 'cash': return 'Efectivo';
      case 'card': return 'Tarjeta';
      case 'transfer': return 'Transferencia';
      default: return method;
    }
  }

  Future<void> _showTransactionDetail(Map<String, dynamic> transaction) async {
    final transactionId = transaction['id'];
    final itemsResponse = await Supabase.instance.client
        .from('transaction_items')
        .select('*')
        .eq('transaction_id', transactionId);
    final items = List<Map<String, dynamic>>.from(itemsResponse);
    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(color: Color(0xFF1E293B), borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Detalle de Venta', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                        Text(DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(transaction['created_at'])), style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.print, color: Colors.white),
                    onPressed: () { Navigator.pop(context); _printTicket(transaction, items); },
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  _detailRow('ID', (transaction['id']?.toString() ?? 'N/A').length > 20 ? '${transaction['id'].toString().substring(0, 20)}...' : transaction['id']?.toString() ?? 'N/A'),
                  _detailRow('Cajero', transaction['cashier_name'] ?? 'N/A'),
                  if (transaction['barber_name'] != null && transaction['barber_name'].toString().isNotEmpty) _detailRow('Barbero', transaction['barber_name']),
                  _detailRow('Método de pago', _formatPaymentMethod(transaction['payment_method'] ?? '')),
                  if (transaction['payment_method'] == 'cash') ...[
                    _detailRow('Recibido', SettingsService.formatCurrency((transaction['cash_received'] as num?)?.toDouble() ?? 0.0)),
                    if (((transaction['change_amount'] as num?)?.toDouble() ?? 0.0) > 0) _detailRow('Vuelto', SettingsService.formatCurrency((transaction['change_amount'] as num?)?.toDouble() ?? 0.0)),
                  ],
                  const SizedBox(height: 16),
                  const Text('ITEMS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...items.map((item) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(item['item_type'] == 'service' ? Icons.content_cut : Icons.shopping_bag, size: 20),
                    title: Text(item['service_name'] ?? item['product_name'] ?? 'Sin nombre', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text(
                      '${SettingsService.formatCurrency((item['price_at_moment'] as num?)?.toDouble() ?? 0.0)} x${item['quantity']}${item['barber_name'] != null && item['barber_name'].toString().isNotEmpty ? ' · ${item['barber_name']}' : ''}',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Text(SettingsService.formatCurrency(((item['price_at_moment'] as num?)?.toDouble() ?? 0.0) * (item['quantity'] as num? ?? 1)), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.indigo)),
                  )),
                  const SizedBox(height: 16),
                  _totalRow('Subtotal', SettingsService.formatCurrency((transaction['subtotal'] as num?)?.toDouble() ?? 0.0)),
                  const SizedBox(height: 8),
                  _totalRow('TOTAL', SettingsService.formatCurrency((transaction['total'] as num?)?.toDouble() ?? 0.0), isTotal: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text('$label:', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey))),
          Expanded(child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _totalRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: isTotal ? 18 : 14, fontWeight: isTotal ? FontWeight.bold : FontWeight.w600)),
        Text(value, style: TextStyle(fontSize: isTotal ? 20 : 14, fontWeight: FontWeight.bold, color: isTotal ? Colors.green[700] : Colors.black87)),
      ],
    );
  }

  Future<void> _printTicket(Map<String, dynamic> transaction, List<Map<String, dynamic>> items) async {
    final pdf = pw.Document();
    final logoUrl = SettingsService.ticketLogoUrl.isNotEmpty ? SettingsService.ticketLogoUrl : SettingsService.shopLogoUrl;
    pw.MemoryImage? logoImage;
    if (logoUrl.isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(logoUrl));
        if (response.statusCode == 200) logoImage = pw.MemoryImage(response.bodyBytes);
      } catch (e) { print('Error al descargar logo: $e'); }
    }
    final double heightMm = 100 + (items.length * 16);
    final pageFormat = PdfPageFormat(66 * PdfPageFormat.mm, heightMm * PdfPageFormat.mm, marginAll: 2 * PdfPageFormat.mm);
    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (logoImage != null) pw.Center(child: pw.Container(width: 70, height: 70, child: pw.Image(logoImage, fit: pw.BoxFit.contain))),
              pw.SizedBox(height: 3),
              pw.Center(child: pw.Text(SettingsService.ticketHeader, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold))),
              pw.SizedBox(height: 2),
              if (SettingsService.shopRif.isNotEmpty) pw.Center(child: pw.Text('RUT: ${SettingsService.shopRif}', style: pw.TextStyle(fontSize: 9))),
              if (SettingsService.shopAddress.isNotEmpty) pw.Center(child: pw.Text(SettingsService.shopAddress, style: pw.TextStyle(fontSize: 9))),
              if (SettingsService.shopPhone.isNotEmpty) pw.Center(child: pw.Text('Tel: ${SettingsService.shopPhone}', style: pw.TextStyle(fontSize: 9))),
              pw.SizedBox(height: 2),
              pw.Divider(),
              pw.SizedBox(height: 2),
              pw.Center(child: pw.Text('ID: ${transaction['id']}', style: pw.TextStyle(fontSize: 9))),
              pw.Center(child: pw.Text('Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(transaction['created_at']))}', style: pw.TextStyle(fontSize: 9))),
              pw.Center(child: pw.Text('Cajero: ${transaction['cashier_name']}', style: pw.TextStyle(fontSize: 9))),
              pw.SizedBox(height: 2),
              pw.Divider(),
              pw.SizedBox(height: 2),
              pw.Text('ITEMS:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 2),
              ...items.map((item) {
                final name = item['service_name'] ?? item['product_name'] ?? 'Producto';
                final icon = item['item_type'] == 'service' ? '*' : '-';
                final price = (item['price_at_moment'] as num?)?.toDouble() ?? 0.0;
                final qty = (item['quantity'] as num?)?.toInt() ?? 1;
                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('$icon $name', style: pw.TextStyle(fontSize: 7)),
                    pw.Container(alignment: pw.Alignment.centerRight, child: pw.Text('${SettingsService.formatCurrency(price)} x$qty = ${SettingsService.formatCurrency(price * qty)}', style: pw.TextStyle(fontSize: 10))),
                    if (item['barber_name'] != null && item['barber_name'].toString().isNotEmpty) pw.Text('Barbero: ${item['barber_name']}', style: pw.TextStyle(fontSize: 10)),
                    pw.SizedBox(height: 2),
                  ],
                );
              }),
              pw.Divider(),
              pw.SizedBox(height: 2),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Subtotal:', style: pw.TextStyle(fontSize: 10)), pw.Text(SettingsService.formatCurrency((transaction['subtotal'] as num?)?.toDouble() ?? 0.0), style: pw.TextStyle(fontSize: 10))]),
              pw.SizedBox(height: 2),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('TOTAL:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)), pw.Text(SettingsService.formatCurrency((transaction['total'] as num?)?.toDouble() ?? 0.0), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))]),
              pw.SizedBox(height: 2),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Pago:', style: pw.TextStyle(fontSize: 8)), pw.Text(_formatPaymentMethod(transaction['payment_method'] ?? ''), style: pw.TextStyle(fontSize: 8))]),
              if (transaction['payment_method'] == 'cash') ...[
                pw.SizedBox(height: 2),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Recibido:', style: pw.TextStyle(fontSize: 8)), pw.Text(SettingsService.formatCurrency((transaction['cash_received'] as num?)?.toDouble() ?? 0.0), style: pw.TextStyle(fontSize: 8))]),
                if (((transaction['change_amount'] as num?)?.toDouble() ?? 0.0) > 0) ...[
                  pw.SizedBox(height: 2),
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Vuelto:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)), pw.Text(SettingsService.formatCurrency((transaction['change_amount'] as num?)?.toDouble() ?? 0.0), style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))]),
                ],
              ],
              pw.SizedBox(height: 3),
              pw.Divider(),
              pw.SizedBox(height: 2),
              pw.Center(child: pw.Text(SettingsService.ticketFooter, style: pw.TextStyle(fontSize: 7, fontStyle: pw.FontStyle.italic))),
            ],
          );
        },
      ),
    );
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save(), name: 'Ticket_${transaction['id']}.pdf');
  }

  Future<void> _selectDateRange() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: isDark
              ? const ColorScheme.dark(primary: Color(0xFF6366F1), onPrimary: Colors.white, surface: Color(0xFF1E293B), onSurface: Colors.white, outline: Color(0xFF334155), onSurfaceVariant: Colors.white)
              : const ColorScheme.light(primary: Color(0xFF6366F1), onPrimary: Colors.white, surface: Colors.white, onSurface: Colors.black87),
          dialogBackgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        ),
        child: Localizations.override(context: context, child: child!),
      ),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadTransactions();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _filteredTransactions;
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.receipt_long, size: 22),
            SizedBox(width: 8),
            Expanded(child: Text('Historial de Ventas', overflow: TextOverflow.ellipsis)),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.date_range), tooltip: 'Filtrar por fecha', onPressed: _selectDateRange),
          IconButton(icon: const Icon(Icons.refresh), tooltip: 'Actualizar', onPressed: _loadTransactions),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: isDark ? const Color(0xFF1E293B) : Colors.indigo[50],
            child: Row(
              children: [
                Icon(Icons.date_range, size: 20, color: isDark ? const Color(0xFF818CF8) : Colors.indigo[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${DateFormat('dd/MM/yyyy').format(_startDate)} - ${DateFormat('dd/MM/yyyy').format(_endDate)}',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : Colors.black87),
                  ),
                ),
                Text('${filtered.length} ventas', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                hintText: 'Buscar por ID, cajero, barbero o método...',
                hintStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[500], fontSize: 13),
                prefixIcon: Icon(Icons.search, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(icon: Icon(Icons.clear, color: isDark ? Colors.grey[400] : Colors.grey[600]), onPressed: () { _searchController.clear(); setState(() => _searchQuery = ''); })
                    : null,
                filled: true,
                fillColor: isDark ? const Color(0xFF334155) : Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF6366F1))),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off, size: 64, color: isDark ? Colors.grey[600] : Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(_searchQuery.isNotEmpty ? 'Sin resultados para "$_searchQuery"' : 'No hay ventas en este período', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[400], fontSize: 16)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final t = filtered[index];
                          final total = (t['total'] as num?)?.toDouble() ?? 0.0;
                          final date = DateTime.parse(t['created_at']);
                          final method = (t['payment_method'] ?? 'cash').toString();
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            child: ListTile(
                              onTap: () => _showTransactionDetail(t),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              leading: CircleAvatar(
                                backgroundColor: isDark ? const Color(0xFF312E81) : Colors.indigo[100],
                                child: Icon(_paymentIcon(method), size: 20, color: isDark ? const Color(0xFF818CF8) : Colors.indigo[700]),
                              ),
                              title: Text(
                                DateFormat('dd/MM/yyyy HH:mm').format(date),
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black87),
                              ),
                              subtitle: Text(
                                '${_formatPaymentMethod(method)} · Cajero: ${t['cashier_name'] ?? '-'}',
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                              ),
                              trailing: Text(
                                SettingsService.formatCurrency(total),
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.green[300] : Colors.green[700]),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}