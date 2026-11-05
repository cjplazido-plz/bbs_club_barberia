import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../services/settings_service.dart';
import '../services/printer_service.dart';

class SalesHistoryScreen extends StatefulWidget {
  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _transactions = [];
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 35));
  DateTime _endDate = DateTime.now();
  final _printer = PrinterService();

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);
    try {
      final startStr = DateTime(_startDate.year, _startDate.month, _startDate.day).toIso8601String();
      final endStr = DateTime(_endDate.year, _endDate.month, _endDate.day).add(const Duration(days: 1)).toIso8601String();
      final response = await Supabase.instance.client.from('transactions').select('*').gte('created_at', startStr).lte('created_at', endStr).eq('status', 'completed').order('created_at', ascending: false);
      setState(() { _transactions = List<Map<String, dynamic>>.from(response); _isLoading = false; });
    } catch (e) {
      print('Error ventas: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _loadItems(String transactionId) async {
    final itemsResponse = await Supabase.instance.client.from('transaction_items').select('*').eq('transaction_id', transactionId);
    return List<Map<String, dynamic>>.from(itemsResponse);
  }

  Future<void> _showTransactionDetail(Map<String, dynamic> transaction) async {
    final items = await _loadItems(transaction['id']);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85, minChildSize: 0.5, maxChildSize: 0.95, expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(color: Color(0xFF6366F1), borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              child: Row(children: [
                const Text('🧾', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Detalle de Venta', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(transaction['created_at'])), style: const TextStyle(color: Colors.white70, fontSize: 11))
                ])),
                IconButton(onPressed: (){ Navigator.pop(context); _printer.printTicketFromMap(transaction, items); }, icon: const Icon(Icons.print_rounded, color: Colors.white)),
              ]),
            ),
            Expanded(child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _infoRow('ID', (transaction['id'] as String).length > 22 ? '${(transaction['id'] as String).substring(0,22)}...' : transaction['id']),
                  const Divider(color: Colors.white10, height: 20),
                  _infoRow('Cajero', transaction['cashier_name'] ?? 'N/A'),
                  if (transaction['barber_name'] != null && (transaction['barber_name'] as String).isNotEmpty) _infoRow('Barbero', transaction['barber_name']),
                  _infoRow('Pago', _formatPaymentMethod(transaction['payment_method'])),
                  if (transaction['payment_method'] == 'cash') ...[
                    _infoRow('Recibido', SettingsService.formatCurrency((transaction['cash_received'] as num?)?.toDouble() ?? 0.0)),
                    _infoRow('Vuelto', SettingsService.formatCurrency((transaction['change_amount'] as num?)?.toDouble() ?? 0.0)),
                  ]
                ])),
                const SizedBox(height: 16),
                const Text('ITEMS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70, letterSpacing: 1.2)),
                const SizedBox(height: 10),
                ...items.map((item) => Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)), child: Row(children: [
                  Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.15), shape: BoxShape.circle), child: Text(item['item_type']=='service'?'✂️':'📦', style: const TextStyle(fontSize: 14))),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item['service_name'] ?? item['product_name'] ?? 'Item', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                    if (item['barber_name'] != null) Text('Barbero: ${item['barber_name']}', style: const TextStyle(color: Colors.white38, fontSize: 10))
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('${SettingsService.formatCurrency((item['price_at_moment'] as num).toDouble())} x${item['quantity']}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    Text(SettingsService.formatCurrency((item['price_at_moment'] as num).toDouble() * (item['quantity'] as int)), style: const TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold))
                  ])
                ]))),
                const SizedBox(height: 16),
                Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3))), child: Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Subtotal:', style: TextStyle(color: Colors.white54, fontSize: 12)), Text(SettingsService.formatCurrency((transaction['subtotal'] as num?)?.toDouble() ?? (transaction['total'] as num).toDouble()), style: const TextStyle(color: Colors.white, fontSize: 12))]),
                  const SizedBox(height: 6),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('TOTAL:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)), Text(SettingsService.formatCurrency((transaction['total'] as num).toDouble()), style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 18))]),
                ])),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(child: OutlinedButton.icon(onPressed: () async { Navigator.pop(context); await _printer.printTicketFromMap(transaction, items); }, icon: const Icon(Icons.print_rounded, size: 16), label: const Text('Imprimir 80mm', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white24), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)))),
                  const SizedBox(width: 10),
                  Expanded(child: ElevatedButton.icon(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.check_rounded, size: 16), label: const Text('Cerrar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)))),
                ]),
              ],
            )),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w600)),
      Flexible(child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.right, overflow: TextOverflow.ellipsis)),
    ]));
  }

  String _formatPaymentMethod(String? method) {
    switch (method) { case 'cash': return 'Efectivo'; case 'card': return 'Tarjeta'; case 'transfer': return 'Transferencia'; default: return method ?? 'Efectivo'; }
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(context: context, firstDate: DateTime(2023), lastDate: DateTime.now().add(const Duration(days: 1)), initialDateRange: DateTimeRange(start: _startDate, end: _endDate), builder: (context, child) => Theme(data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: Color(0xFF6366F1), surface: Color(0xFF1E293B)), dialogBackgroundColor: const Color(0xFF0F172A)), child: child!));
    if (picked != null) setState(() { _startDate = picked.start; _endDate = picked.end; });
    await _loadTransactions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: const Text('Historial Premium', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded, color: Colors.white70), onPressed: _loadTransactions), IconButton(icon: const Icon(Icons.calendar_month_rounded, color: Colors.white70), onPressed: _pickDateRange)],
      ),
      body: Column(
        children: [
          InkWell(onTap: _pickDateRange, child: Container(margin: const EdgeInsets.all(12), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF312E81), Color(0xFF4338CA)]), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.08))), child: Row(children: [
            Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: const Text('📅', style: TextStyle(fontSize: 14))),
            const SizedBox(width: 10),
            Expanded(child: Text('${DateFormat('dd/MM/yyyy').format(_startDate)} - ${DateFormat('dd/MM/yyyy').format(_endDate)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(20)), child: Text('${_transactions.length} ventas', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)))
          ]))),
          Expanded(
            child: _isLoading ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1))) : _transactions.isEmpty ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Text('🧾', style: TextStyle(fontSize: 48)), const SizedBox(height: 12), const Text('No hay ventas en este periodo', style: TextStyle(color: Colors.white54, fontSize: 13)), const SizedBox(height: 12), ElevatedButton(onPressed: _loadTransactions, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)), child: const Text('Recargar', style: TextStyle(fontSize: 12))) ])) : ListView.builder(padding: const EdgeInsets.fromLTRB(12, 0, 12, 12), itemCount: _transactions.length, itemBuilder: (context, index) {
              final t = _transactions[index];
              final total = (t['total'] as num).toDouble();
              final date = DateTime.parse(t['created_at']);
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withOpacity(0.06))),
                child: InkWell(onTap: () => _showTransactionDetail(t), borderRadius: BorderRadius.circular(14), child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
                  Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFF312E81), shape: BoxShape.circle), child: const Text('🧾', style: TextStyle(fontSize: 16))),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(DateFormat('dd/MM/yyyy HH:mm').format(date), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 2),
                    Text('${_formatPaymentMethod(t['payment_method'])} • ${t['cashier_name'] ?? 'N/A'}${t['barber_name'] != null ? ' • ${t['barber_name']}' : ''}', style: const TextStyle(color: Colors.white38, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis)
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(SettingsService.formatCurrency(total), style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      InkWell(onTap: () => _showTransactionDetail(t), child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.15), borderRadius: BorderRadius.circular(20)), child: const Text('Ver', style: TextStyle(color: Color(0xFF10B981), fontSize: 9, fontWeight: FontWeight.bold)))),
                      const SizedBox(width: 6),
                      InkWell(onTap: () async { final items = await _loadItems(t['id']); await _printer.printTicketFromMap(t, items); }, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.15), borderRadius: BorderRadius.circular(20)), child: const Text('Imprimir', style: TextStyle(color: Color(0xFF818CF8), fontSize: 9, fontWeight: FontWeight.bold)))),
                    ])
                  ])
                ]))),
              );
            }),
          )
        ],
      ),
    );
  }
}
