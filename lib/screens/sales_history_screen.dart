import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/local_transaction.dart';

class SalesHistoryScreen extends StatefulWidget {
  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() { _isLoading = true; });
    try {
      final response = await Supabase.instance.client
          .from('transactions')
          .select('*, transaction_items(*)')
          .order('created_at', ascending: false)
          .limit(50);

      setState(() {
        _transactions = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error al cargar historial: $e');
      setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Ventas'),
        backgroundColor: Colors.indigo[700],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _transactions.isEmpty
              ? const Center(child: Text('No hay ventas registradas'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _transactions.length,
                  itemBuilder: (context, index) {
                    final t = _transactions[index];
                    final items = List<Map<String, dynamic>>.from(t['transaction_items'] ?? []);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        title: Text('Venta #${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text('Items: ${items.length}'),
                            Text('Método: ${t['payment_method'] ?? 'N/A'}'),
                            Text('Fecha: ${t['created_at'] ?? 'N/A'}'),
                          ],
                        ),
                        trailing: Text(
                          '\$${(t['total'] as num).toStringAsFixed(2)}',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green[700]),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}