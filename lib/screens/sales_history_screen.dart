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

  @override
  void initState() {
    super.initState();
    _loadTransactions();
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
      print('❌ Error al cargar ventas: $e');
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _showTransactionDetail(Map<String, dynamic> transaction) async {
    final transactionId = transaction['id'];
    
    // Cargar items de la transacción
    final itemsResponse = await Supabase.instance.client
        .from('transaction_items')
        .select('*')
        .eq('transaction_id', transactionId);
    
    final items = List<Map<String, dynamic>>.from(itemsResponse);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.indigo[700],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const Text('🧾', style: TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Detalle de Venta', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                        Text(
                          DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(transaction['created_at'])),
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Text('️🖨️', style: TextStyle(fontSize: 20)),
                    onPressed: () {
                      Navigator.pop(context);
                      _printTicket(transaction, items);
                    },
                  ),
                ],
              ),
            ),
            // Contenido
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  // Info de la transacción
                  Card(
                    color: Colors.indigo[50],
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _infoRow('ID', (transaction['id']?.toString() ?? 'N/A').length > 20 
                              ? '${transaction['id'].toString().substring(0, 20)}...' 
                              : transaction['id']?.toString() ?? 'N/A'),
                          const Divider(),
                          _infoRow('Cajero', transaction['cashier_name'] ?? 'N/A'),
                          if (transaction['barber_name'] != null && transaction['barber_name'].toString().isNotEmpty)
                            _infoRow('Barbero', transaction['barber_name']),
                          _infoRow('Método de pago', _formatPaymentMethod(transaction['payment_method'])),
                          if (transaction['payment_method'] == 'cash') ...[
                            _infoRow('Recibido', SettingsService.formatCurrency((transaction['cash_received'] as num?)?.toDouble() ?? 0.0)),
                            if (((transaction['change_amount'] as num?)?.toDouble() ?? 0.0) > 0)
                              _infoRow('Vuelto', SettingsService.formatCurrency((transaction['change_amount'] as num?)?.toDouble() ?? 0.0)),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('ITEMS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  // Lista de items
                  ...items.map((item) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                item['item_type'] == 'service' ? '✂️' : '',
                                style: const TextStyle(fontSize: 20),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item['service_name'] ?? item['product_name'] ?? 'Sin nombre',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ),
                              Text(
                                '${SettingsService.formatCurrency((item['price_at_moment'] as num?)?.toDouble() ?? 0.0)} x${item['quantity']}',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                          if (item['barber_name'] != null && item['barber_name'].toString().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 28, top: 4),
                              child: Text(
                                'Barbero: ${item['barber_name']}',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                            ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                SettingsService.formatCurrency(
                                  ((item['price_at_moment'] as num?)?.toDouble() ?? 0.0) * (item['quantity'] as num? ?? 1),
                                ),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.indigo),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )),
                  const SizedBox(height: 16),
                  // Totales
                  Card(
                    color: Colors.green[50],
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          _totalRow('Subtotal', SettingsService.formatCurrency((transaction['subtotal'] as num?)?.toDouble() ?? 0.0)),
                          const SizedBox(height: 8),
                          _totalRow('TOTAL', SettingsService.formatCurrency((transaction['total'] as num?)?.toDouble() ?? 0.0), isTotal: true),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

Widget _infoRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Text('$label:', style: TextStyle(color: Colors.grey[700], fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(width: 8),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87))),
      ],
    ),
  );
}

Widget _totalRow(String label, String value, {bool isTotal = false}) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: TextStyle(fontSize: isTotal ? 18 : 14, fontWeight: isTotal ? FontWeight.bold : FontWeight.w600, color: Colors.black87)),
      Text(value, style: TextStyle(fontSize: isTotal ? 20 : 14, fontWeight: FontWeight.bold, color: isTotal ? Colors.green[700] : Colors.black87)),
    ],
  );
}

  String _formatPaymentMethod(String method) {
    switch (method) {
      case 'cash': return '💵 Efectivo';
      case 'card': return '💳 Tarjeta';
      case 'transfer': return '📱 Transferencia';
      default: return method;
    }
  }

  Future<void> _printTicket(Map<String, dynamic> transaction, List<Map<String, dynamic>> items) async {
    final pdf = pw.Document();
    final logoUrl = SettingsService.shopLogoUrl;
    pw.MemoryImage? logoImage;

    if (logoUrl.isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(logoUrl));
        if (response.statusCode == 200) {
          logoImage = pw.MemoryImage(response.bodyBytes);
        }
      } catch (e) {
        print('⚠️ Error al descargar logo: $e');
      }
    }

    final pageFormat = PdfPageFormat(66 * PdfPageFormat.mm, 200 * PdfPageFormat.mm);
    
    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.only(left: 2, right: 2, top: 2, bottom: 2),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (logoImage != null)
                pw.Center(child: pw.Container(width: 70, height: 70, child: pw.Image(logoImage, fit: pw.BoxFit.contain))),
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
                final total = price * qty;
                
                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('$icon $name', style: pw.TextStyle(fontSize: 7)),
                    pw.Container(
                      alignment: pw.Alignment.centerRight,
                      child: pw.Text('${SettingsService.formatCurrency(price)} x$qty = ${SettingsService.formatCurrency(total)}', style: pw.TextStyle(fontSize: 10)),
                    ),
                    if (item['barber_name'] != null && item['barber_name'].toString().isNotEmpty)
                      pw.Text('Barbero: ${item['barber_name']}', style: pw.TextStyle(fontSize: 10)),
                    pw.SizedBox(height: 2),
                  ],
                );
              }),
              pw.Divider(),
              pw.SizedBox(height: 2),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('Subtotal:', style: pw.TextStyle(fontSize: 10)),
                pw.Text(SettingsService.formatCurrency((transaction['subtotal'] as num?)?.toDouble() ?? 0.0), style: pw.TextStyle(fontSize: 10)),
              ]),
              pw.SizedBox(height: 2),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('TOTAL:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                pw.Text(SettingsService.formatCurrency((transaction['total'] as num?)?.toDouble() ?? 0.0), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              ]),
              pw.SizedBox(height: 2),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('Pago:', style: pw.TextStyle(fontSize: 7)),
                pw.Text(_formatPaymentMethod(transaction['payment_method']), style: pw.TextStyle(fontSize: 7)),
              ]),
              if (transaction['payment_method'] == 'cash') ...[
                pw.SizedBox(height: 2),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text('Recibido:', style: pw.TextStyle(fontSize: 7)),
                  pw.Text(SettingsService.formatCurrency((transaction['cash_received'] as num?)?.toDouble() ?? 0.0), style: pw.TextStyle(fontSize: 7)),
                ]),
                if (((transaction['change_amount'] as num?)?.toDouble() ?? 0.0) > 0) ...[
                  pw.SizedBox(height: 2),
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                    pw.Text('Vuelto:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    pw.Text(SettingsService.formatCurrency((transaction['change_amount'] as num?)?.toDouble() ?? 0.0), style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  ]),
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

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Ticket_${transaction['id']}.pdf',
    );
  }

Future<void> _selectDateRange() async {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  
  final picked = await showDateRangePicker(
    context: context,
    firstDate: DateTime(2020),
    lastDate: DateTime.now(),
    builder: (context, child) => Theme(
      data: Theme.of(context).copyWith(
        colorScheme: isDark
            ? const ColorScheme.dark(
                primary: Color(0xFF6366F1),
                onPrimary: Colors.white,
                surface: Color(0xFF1E293B),
                onSurface: Colors.white,
                outline: Color(0xFF334155),
                onSurfaceVariant: Colors.white,
              )
            : const ColorScheme.light(
                primary: Color(0xFF6366F1),
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: Colors.black87,
              ),
        dialogBackgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      ),
      child: Localizations.override(
        context: context,
        child: child!,
      ),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('🧾 Historial de Ventas'),
        backgroundColor: Colors.indigo[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Text('📅', style: TextStyle(fontSize: 20)),
            tooltip: 'Filtrar por fecha',
            onPressed: _selectDateRange,
          ),
          IconButton(
            icon: const Text('🔄', style: TextStyle(fontSize: 20)),
            tooltip: 'Actualizar',
            onPressed: _loadTransactions,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtro de fecha
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.indigo[50],
            child: Row(
              children: [
                const Text('📅', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${DateFormat('dd/MM/yyyy').format(_startDate)} - ${DateFormat('dd/MM/yyyy').format(_endDate)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                Text('${_transactions.length} ventas', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              ],
            ),
          ),
          // Lista de transacciones
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _transactions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('📊', style: TextStyle(fontSize: 64)),
                            const SizedBox(height: 16),
                            Text('No hay ventas en este período', style: TextStyle(color: Colors.grey[400], fontSize: 16)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _transactions.length,
                        itemBuilder: (context, index) {
                          final transaction = _transactions[index];
                          final total = (transaction['total'] as num?)?.toDouble() ?? 0.0;
                          final date = DateTime.parse(transaction['created_at']);
                          
                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: InkWell(
                              onTap: () => _showTransactionDetail(transaction),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.indigo[100],
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Text('🧾', style: TextStyle(fontSize: 24)),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            DateFormat('dd/MM/yyyy HH:mm').format(date),
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Text(
                                                _formatPaymentMethod(transaction['payment_method'] ?? 'cash'),
                                                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                              ),
                                              const SizedBox(width: 12),
                                              if (transaction['cashier_name'] != null)
                                                Text(
                                                  'Cajero: ${transaction['cashier_name']}',
                                                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          SettingsService.formatCurrency(total),
                                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                                        ),
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.green[100],
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Text('Ver detalle', style: TextStyle(fontSize: 10, color: Colors.green)),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
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