import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/settings_service.dart';

class ReportsScreen extends StatefulWidget {
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  double _dayTotal = 0.0;
  int _dayTransactions = 0;
  Map<String, double> _barberTotals = {};
  Map<String, int> _paymentMethods = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() { _isLoading = true; });
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    try {
      final response = await Supabase.instance.client.from('transactions').select('*, transaction_items(*)').gte('created_at', startOfDay.toIso8601String()).lt('created_at', endOfDay.toIso8601String());
      final transactions = List<Map<String, dynamic>>.from(response);
      double total = 0.0;
      Map<String, double> barberTotals = {};
      Map<String, int> paymentMethods = {};
      for (final t in transactions) {
        total += (t['total'] as num).toDouble();
        final items = List<Map<String, dynamic>>.from(t['transaction_items'] ?? []);
        for (final item in items) {
          if (item['item_type'] == 'service') {
            final barberName = item['barber_name'] ?? '';
            if (barberName.isNotEmpty) {
              barberTotals[barberName] = (barberTotals[barberName] ?? 0) + ((item['price_at_moment'] as num).toDouble() * (item['quantity'] as int));
            }
          }
        }
        final method = t['payment_method'] ?? 'cash';
        paymentMethods[method] = (paymentMethods[method] ?? 0) + 1;
      }
      setState(() {
        _dayTotal = total;
        _dayTransactions = transactions.length;
        _barberTotals = barberTotals;
        _paymentMethods = paymentMethods;
        _isLoading = false;
      });
    } catch (e) {
      print('Error reportes: $e');
      setState(() { _isLoading = false; });
    }
  }

  String _formatPaymentMethod(String method) {
    switch (method) { case 'cash': return 'Efectivo'; case 'card': return 'Tarjeta'; case 'transfer': return 'Transferencia'; default: return method; }
  }

  @override
  Widget build(BuildContext context) {
    final transaccionesText = "${_dayTransactions}";
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: const Text('Reportes Premium', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [IconButton(icon: const Icon(Icons.sync_rounded, color: Colors.white), onPressed: _loadReports)],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: _SummaryCard(title: 'Total del dia', value: SettingsService.formatCurrency(_dayTotal), icon: '💵', color: const Color(0xFF10B981))),
                  const SizedBox(width: 12),
                  Expanded(child: _SummaryCard(title: 'Ventas', value: transaccionesText, icon: '💲', color: const Color(0xFF3B82F6))),
                ]),
                const SizedBox(height: 24),
                const Text('Ventas por Barbero', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 12),
                if (_barberTotals.isEmpty)
                  Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white10)), child: const Text('No hay datos', style: TextStyle(color: Colors.white54)))
                else
                  ..._barberTotals.entries.map((entry) => Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withOpacity(0.05)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))]),
                        child: ListTile(
                          leading: CircleAvatar(backgroundColor: const Color(0xFF6366F1).withOpacity(0.15), child: Text(entry.key.isNotEmpty ? entry.key[0].toUpperCase() : '?', style: const TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold))),
                          title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 14)),
                          trailing: Text(SettingsService.formatCurrency(entry.value), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                        ),
                      )),
                const SizedBox(height: 24),
                const Text('Metodos de Pago', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 12),
                if (_paymentMethods.isEmpty)
                  Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white10)), child: const Text('No hay datos', style: TextStyle(color: Colors.white54)))
                else
                  ..._paymentMethods.entries.map((entry) {
                        final countText = "${entry.value} ventas";
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withOpacity(0.05))),
                          child: ListTile(
                            leading: Text(entry.key == 'cash' ? '💵' : entry.key == 'card' ? '💳' : '💳', style: const TextStyle(fontSize: 22)),
                            title: Text(_formatPaymentMethod(entry.key), style: const TextStyle(color: Colors.white, fontSize: 14)),
                            trailing: Text(countText, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white70)),
                          ),
                        );
                      }),
              ]),
            ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final String icon;
  final Color color;
  const _SummaryCard({required this.title, required this.value, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withOpacity(0.05)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))]),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: Text(icon, style: const TextStyle(fontSize: 18))), const Spacer(), Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle))]),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(color: Colors.white54, fontSize: 11)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        ]),
      ),
    );
  }
}
