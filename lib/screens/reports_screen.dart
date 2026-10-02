import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
      final response = await Supabase.instance.client
          .from('transactions')
          .select('*, transaction_items(*)')
          .gte('created_at', startOfDay.toIso8601String())
          .lt('created_at', endOfDay.toIso8601String());

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
              barberTotals[barberName] =
                  (barberTotals[barberName] ?? 0) +
                  ((item['price_at_moment'] as num).toDouble() * (item['quantity'] as int));
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
      print('❌ Error al cargar reportes: $e');
      setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes del Día'),
        backgroundColor: Colors.indigo[700],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryCard(
                          title: 'Total del día',
                          value: '\$${_dayTotal.toStringAsFixed(2)}',
                          icon: Icons.attach_money,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryCard(
                          title: 'Ventas',
                          value: '$_dayTransactions',
                          icon: Icons.receipt,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text('Ventas por Barbero', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  if (_barberTotals.isEmpty)
                    const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No hay datos')))
                  else
                    ..._barberTotals.entries.map((entry) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.indigo[100],
                              child: Text(
                                entry.key.isNotEmpty ? entry.key[0].toUpperCase() : '?',
                                style: TextStyle(color: Colors.indigo[700]),
                              ),
                            ),
                            title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w600)),
                            trailing: Text('\$${entry.value.toStringAsFixed(2)}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green[700])),
                          ),
                        )),
                  const SizedBox(height: 24),
                  const Text('Métodos de Pago', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  if (_paymentMethods.isEmpty)
                    const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No hay datos')))
                  else
                    ..._paymentMethods.entries.map((entry) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Icon(
                              entry.key == 'cash' ? Icons.money : entry.key == 'card' ? Icons.credit_card : Icons.phone_android,
                              color: Colors.indigo,
                            ),
                            title: Text(_formatPaymentMethod(entry.key)),
                            trailing: Text('${entry.value} ventas', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        )),
                ],
              ),
            ),
    );
  }

  String _formatPaymentMethod(String method) {
    switch (method) {
      case 'cash': return 'Efectivo';
      case 'card': return 'Tarjeta';
      case 'transfer': return 'Transferencia';
      default: return method;
    }
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  const _SummaryCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 12),
            Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}