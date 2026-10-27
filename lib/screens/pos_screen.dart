import 'commissions_screen.dart' hide SalesHistoryScreen;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/local_service.dart';
import '../models/local_transaction.dart';
import '../models/local_barber.dart';
import '../models/local_client.dart';
import '../models/local_product.dart';
import '../models/local_appointment.dart';
import '../repositories/service_repository.dart';
import '../repositories/barber_repository.dart';
import '../repositories/client_repository.dart';
import '../repositories/product_repository.dart';
import '../repositories/appointment_repository.dart';
import '../services/printer_service.dart';
import '../services/settings_service.dart';
import '../main.dart';
import 'clients_screen.dart';
import 'sales_history_screen.dart';
import 'reports_screen.dart';
import 'barbers_screen.dart';
import 'services_screen.dart';
import 'products_screen.dart';
import 'users_screen.dart';
import 'appointments_screen.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';
import 'settings_screen.dart';
import 'advanced_reports_screen.dart';

class PosScreen extends StatefulWidget {
  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> with SingleTickerProviderStateMixin {
  final _serviceRepo = ServiceRepository();
  final _barberRepo = BarberRepository();
  final _clientRepo = ClientRepository();
  final _productRepo = ProductRepository();
  final _appointmentRepo = AppointmentRepository();
  final _printer = PrinterService();
  late TabController _tabController;
  List<LocalService> _services = [];
  List<LocalBarber> _barbers = [];
  List<LocalClient> _clients = [];
  List<LocalProduct> _products = [];
  List<LocalAppointment> _todayAppointments = [];
  List<LocalTransactionItem> _cart = [];
  String _paymentMethod = 'cash';
  LocalBarber? _selectedBarber;
  LocalClient? _selectedClient;
  LocalAppointment? _selectedAppointment;
  double _discount = 0.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final services = await _serviceRepo.getAllServices();
    final barbers = await _barberRepo.getAllBarbers();
    final clients = await _clientRepo.getAllClients();
    final products = await _productRepo.getAllProducts();
    final today = DateTime.now();
    final appointments = await _appointmentRepo.getAppointmentsByDate(today);
    final pendingAppointments = appointments.where((a) =>
        a.status == 'pending' || a.status == 'confirmed' || a.status == 'in_progress'
    ).toList();

    setState(() {
      _services = services;
      _barbers = barbers;
      _clients = clients;
      _products = products;
      _todayAppointments = pendingAppointments;
    });
  }

  void _addServiceToCart(LocalService service) {
    if (_selectedBarber == null) {
      _showBarberRequiredDialog();
      return;
    }
    setState(() {
      final existingIndex = _cart.indexWhere((item) =>
          item.type == 'service' && item.serviceId == service.remoteId);
      if (existingIndex >= 0) {
        _cart[existingIndex].quantity++;
      } else {
        _cart.add(LocalTransactionItem()
          ..type = 'service'
          ..serviceId = service.remoteId ?? ''
          ..serviceName = service.name
          ..barberId = _selectedBarber!.remoteId ?? ''
          ..barberName = _selectedBarber!.name
          ..priceAtMoment = service.price
          ..quantity = 1
          ..commissionEarned = (service.price * service.commissionValue) / 100);
      }
    });
    _showSnackbar('✅ ${service.name} agregado', Colors.green);
  }

  void _addProductToCart(LocalProduct product) {
    setState(() {
      final existingIndex = _cart.indexWhere((item) =>
          item.type == 'product' && item.productId == product.remoteId);
      if (existingIndex >= 0) {
        _cart[existingIndex].quantity++;
      } else {
        _cart.add(LocalTransactionItem()
          ..type = 'product'
          ..productId = product.remoteId ?? ''
          ..productName = product.name
          ..priceAtMoment = product.price
          ..quantity = 1);
      }
    });
    _showSnackbar('✅ ${product.name} agregado', Colors.green);
  }

  void _showBarberRequiredDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('💈', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 8),
              Text(
                'Selecciona un barbero',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
        content: Text(
          'Para agregar servicios al carrito, primero debes seleccionar un barbero.',
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.grey[300] : Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showBarberSelector();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text(
              'Seleccionar',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showBarberSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_barbers.isEmpty) {
      _showSnackbar('No hay barberos registrados', Colors.orange);
      return;
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'Seleccionar Barbero',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.85,
          height: 300,
          child: ListView.builder(
            itemCount: _barbers.length,
            itemBuilder: (context, index) {
              final barber = _barbers[index];
              final isSelected = _selectedBarber?.remoteId == barber.remoteId;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: isSelected
                      ? const Color(0xFF6366F1).withOpacity(0.2)
                      : (isDark ? Colors.grey[800] : Colors.grey[200]),
                  child: Text(
                    barber.name[0].toUpperCase(),
                    style: TextStyle(
                      color: isSelected ? const Color(0xFF6366F1) : (isDark ? Colors.grey[300] : Colors.grey[700]),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  barber.name,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_circle, color: Color(0xFF6366F1), size: 20)
                    : null,
                onTap: () {
                  setState(() {
                    _selectedBarber = barber;
                  });
                  Navigator.pop(context);
                  _showSnackbar('✅ Barbero seleccionado: ${barber.name}', Colors.green);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
          ),
        ],
      ),
    );
  }

  void _removeFromCart(int index) {
    setState(() { _cart.removeAt(index); });
  }

  void _updateQuantity(int index, int newQuantity) {
    setState(() {
      if (newQuantity <= 0) {
        _cart.removeAt(index);
      } else {
        _cart[index].quantity = newQuantity;
      }
    });
  }

  double get _subtotal => _cart.fold(0.0, (sum, item) => sum + (item.priceAtMoment * item.quantity));
  double get _total => _subtotal - _discount;

  Future<void> _processPayment() async {
    if (_cart.isEmpty) {
      _showSnackbar('Agrega servicios o productos al carrito', Colors.orange);
      return;
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Text('Confirmar venta', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total: ${SettingsService.formatCurrency(_total)}',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 8),
            Text('Método de pago: ${_formatPaymentMethod(_paymentMethod)}',
                style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700])),
            if (_selectedBarber != null) ...[
              const SizedBox(height: 8),
              Text('Barbero: ${_selectedBarber!.name}',
                  style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700])),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green[600]),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    if (_paymentMethod == 'cash') {
      final cashResult = await _showCashPaymentDialog();
      if (cashResult == null) return;
      await _completeTransaction(
          cashReceived: cashResult['received'] as double,
          change: cashResult['change'] as double
      );
    } else {
      await _completeTransaction(cashReceived: _total, change: 0.0);
    }
  }

  String _formatPaymentMethod(String method) {
    switch (method) {
      case 'cash': return '💵 Efectivo';
      case 'card': return '💳 Tarjeta';
      case 'transfer': return '📱 Transferencia';
      default: return method;
    }
  }

  Future<Map<String, double>?> _showCashPaymentDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final receivedController = TextEditingController();
    double change = 0.0;
    return showDialog<Map<String, double>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          void calculateChange() {
            final received = double.tryParse(receivedController.text) ?? 0.0;
            setDialogState(() {
              change = received - _total;
            });
          }
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            title: Row(
              children: [
                const Text('💵', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 8),
                Text('Pago en Efectivo', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
              ],
            ),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF312E81) : Colors.indigo[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? const Color(0xFF6366F1) : Colors.indigo[200]!),
                    ),
                    child: Column(
                      children: [
                        Text('Total a pagar', style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text(
                          SettingsService.formatCurrency(_total),
                          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF818CF8) : Colors.indigo[700]),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: receivedController,
                    autofocus: true,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Monto recibido',
                      hintText: '0',
                      labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      hintStyle: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[400]),
                      prefixText: '${SettingsService.currencySymbol} ',
                      prefixStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.green[700]!, width: 2),
                      ),
                    ),
                    onChanged: (_) => calculateChange(),
                  ),
                  const SizedBox(height: 12),
                  Text('Billetes rápidos:', style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [10000, 20000, 30000, 40000, 50000].map((amount) {
                      return ElevatedButton(
                        onPressed: () {
                          receivedController.text = amount.toString();
                          calculateChange();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? Colors.green[900] : Colors.green[50],
                          foregroundColor: isDark ? Colors.green[300] : Colors.green[700],
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        child: Text(SettingsService.formatCurrency(amount.toDouble())),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: change >= 0
                          ? (isDark ? Colors.green[900] : Colors.green[50])
                          : (isDark ? Colors.red[900] : Colors.red[50]),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: change >= 0
                            ? (isDark ? Colors.green[700]! : Colors.green[300]!)
                            : (isDark ? Colors.red[700]! : Colors.red[300]!),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          change >= 0 ? 'Vuelto a devolver' : 'Falta por pagar',
                          style: TextStyle(
                            color: change >= 0
                                ? (isDark ? Colors.green[300] : Colors.green[700])
                                : (isDark ? Colors.red[300] : Colors.red[700]),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          SettingsService.formatCurrency(change.abs()),
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: change >= 0
                                ? (isDark ? Colors.green[300] : Colors.green[700])
                                : (isDark ? Colors.red[300] : Colors.red[700]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: Text('Cancelar', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
              ),
              ElevatedButton(
                onPressed: () {
                  final received = double.tryParse(receivedController.text) ?? 0.0;
                  if (received < _total) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('El monto recibido es insuficiente. Faltan ${SettingsService.formatCurrency(_total - received)}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  Navigator.pop(context, {'received': received, 'change': change});
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('Confirmar Pago', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _completeTransaction({required double cashReceived, required double change}) async {
    final transaction = LocalTransaction()
      ..remoteId = 'trans-${DateTime.now().millisecondsSinceEpoch}'
      ..cashRegisterId = 'caja-001'
      ..cashierId = 'user-001'
      ..cashierName = currentUserName.isNotEmpty ? currentUserName : 'Recepcion'
      ..subtotal = _subtotal
      ..total = _total
      ..paymentMethod = _paymentMethod
      ..cashReceived = cashReceived
      ..changeAmount = change
      ..items = List.from(_cart);

    String? transactionId;
    try {
      print('🔄 Guardando transacción en Supabase...');
      final transResponse = await Supabase.instance.client
          .from('transactions')
          .insert({
        'id': transaction.remoteId,
        'cash_register_id': transaction.cashRegisterId,
        'cashier_id': transaction.cashierId,
        'cashier_name': transaction.cashierName,
        'barber_id': _selectedBarber?.remoteId ?? '',
        'subtotal': transaction.subtotal,
        'total': transaction.total,
        'payment_method': transaction.paymentMethod,
        'cash_received': cashReceived,
        'change_amount': change,
        'status': 'completed',
        'created_at': DateTime.now().toIso8601String(),
      })
          .select()
          .single();
      transactionId = transResponse['id'];
      print('✅ Transacción creada en Supabase: $transactionId');

      final itemsData = transaction.items.map((item) => {
        'transaction_id': transactionId,
        'item_type': item.type,
        'service_id': item.type == 'service' ? item.serviceId : null,
        'service_name': item.type == 'service' ? item.serviceName : null,
        'product_id': item.type == 'product' ? item.productId : null,
        'product_name': item.type == 'product' ? item.productName : null,
        'barber_id': item.barberId.isNotEmpty ? item.barberId : null,
        'barber_name': item.barberName.isNotEmpty ? item.barberName : null,
        'price_at_moment': item.priceAtMoment,
        'quantity': item.quantity,
        'commission_earned': item.commissionEarned,
      }).toList();
      await Supabase.instance.client.from('transaction_items').insert(itemsData);
      print('✅ ${itemsData.length} items guardados en Supabase');

      for (final item in transaction.items) {
        if (item.type == 'product' && item.productId != null && item.productId!.isNotEmpty) {
          try {
            final productId = item.productId as String;
            final productResponse = await Supabase.instance.client
                .from('products')
                .select('stock')
                .eq('id', productId)
                .single();
            final currentStock = (productResponse['stock'] as num).toInt();
            final newStock = currentStock - item.quantity;
            await Supabase.instance.client
                .from('products')
                .update({'stock': newStock})
                .eq('id', productId);
            print('📦 Stock actualizado: ${item.productName} ($currentStock → $newStock)');
          } catch (e) {
            print('⚠️ Error al actualizar stock de ${item.productName}: $e');
          }
        }
      }
    } catch (e) {
      print('❌ ERROR al guardar en Supabase: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al guardar venta: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      return;
    }

    final printed = await _printer.printTicket(transaction);
    if (!printed) {
      print('⚠️ No se pudo imprimir el ticket, pero la venta ya está registrada');
    }

    if (_selectedAppointment != null) {
      try {
        _selectedAppointment!.status = 'completed';
        await _appointmentRepo.updateAppointment(_selectedAppointment!);
        await Supabase.instance.client
            .from('appointments')
            .update({'status': 'completed'})
            .eq('id', _selectedAppointment!.remoteId!);
        print('✅ Cita marcada como completada: ${_selectedAppointment!.clientName}');
      } catch (e) {
        print('⚠️ Error al actualizar cita: $e');
      }
    }

    if (_selectedClient != null) {
      try {
        await _clientRepo.incrementVisits(_selectedClient!.remoteId!, _total);
      } catch (e) {
        print('⚠️ Error al incrementar visitas: $e');
      }
    }

    setState(() {
      _cart.clear();
      _discount = 0.0;
      _selectedClient = null;
      _selectedAppointment = null;
    });
    await _loadData();

    if (_paymentMethod == 'cash' && change > 0) {
      if (mounted) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            title: Row(
              children: [
                const Text('✅', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 8),
                Text('¡Pago Exitoso!', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.green[900] : Colors.green[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text('Vuelto a entregar', style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey)),
                      const SizedBox(height: 4),
                      Text(
                        SettingsService.formatCurrency(change),
                        style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: isDark ? Colors.green[300] : Colors.green[700]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Recibido: ${SettingsService.formatCurrency(cashReceived)}',
                  style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : Colors.black87),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green[600]),
                child: const Text('Entregar vuelto'),
              ),
            ],
          ),
        );
      }
    } else {
      _showSnackbar('✅ Venta registrada y guardada', Colors.green);
    }
  }

  void _showClientSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Text('Seleccionar Cliente', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
        content: SizedBox(
          width: 400, height: 400,
          child: _clients.isEmpty
              ? Center(child: Text('No hay clientes registrados', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.black87)))
              : ListView.builder(
            itemCount: _clients.length,
            itemBuilder: (context, index) {
              final client = _clients[index];
              return ListTile(
                leading: CircleAvatar(
                    backgroundColor: const Color(0xFF6366F1).withOpacity(0.2),
                    child: Text(client.name[0].toUpperCase(), style: TextStyle(color: const Color(0xFF6366F1)))),
                title: Text(client.name, style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                subtitle: Text(client.phone ?? 'Sin teléfono', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
                onTap: () { setState(() { _selectedClient = client; }); Navigator.pop(context); },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () { setState(() { _selectedClient = null; }); Navigator.pop(context); },
            child: Text('Sin cliente', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
          ),
        ],
      ),
    );
  }

  void _showAppointmentSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_todayAppointments.isEmpty) {
      _showSnackbar('No hay citas pendientes para hoy', Colors.orange);
      return;
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Text('Seleccionar Cita', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
        content: SizedBox(
          width: 400, height: 400,
          child: ListView.builder(
            itemCount: _todayAppointments.length,
            itemBuilder: (context, index) {
              final apt = _todayAppointments[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: apt.status == 'pending'
                      ? Colors.orange.withOpacity(0.2)
                      : Colors.green.withOpacity(0.2),
                  child: const Text('📅', style: TextStyle(fontSize: 20)),
                ),
                title: Text(apt.clientName ?? 'Sin cliente', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                subtitle: Text(
                  '${apt.serviceName ?? ''} - ${apt.barberName ?? ''} - ${apt.appointmentDate.hour.toString().padLeft(2, '0')}:${apt.appointmentDate.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (apt.status == 'pending' ? Colors.orange : Colors.green).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    apt.status == 'pending' ? 'Pendiente' : 'Confirmada',
                    style: TextStyle(
                      color: apt.status == 'pending' ? Colors.orange[700] : Colors.green[700],
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                onTap: () {
                  setState(() {
                    _selectedAppointment = apt;
                    _selectedClient = _clients.where((c) => c.name == apt.clientName).firstOrNull;
                    _selectedBarber = _barbers.where((b) => b.name == apt.barberName).firstOrNull;
                  });
                  Navigator.pop(context);
                  _showSnackbar('✅ Cita seleccionada: ${apt.clientName}', Colors.green);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () { setState(() { _selectedAppointment = null; }); Navigator.pop(context); },
            child: Text('Sin cita', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
          ),
        ],
      ),
    );
  }

  void _showSnackbar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  Future<void> _handleLogout() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Text('Cerrar sesión', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
        content: Text('¿Estás seguro que deseas cerrar sesión?', style: TextStyle(color: isDark ? Colors.grey[300] : Colors.black87)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => LoginScreen()));
      }
    }
  }

  void _showMobileMenu() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    const Text('☰', style: TextStyle(fontSize: 28, color: Colors.white)),
                    const SizedBox(width: 12),
                    const Text('Menú', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
              ),
              Column(
                children: [
                  if (currentUserRole == 'admin') ...[
                    _buildMenuItem('📝', 'Reportes Avanzados', () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => AdvancedReportsScreen())); }),
                    _buildMenuItem('💰', 'Comisiones', () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => CommissionsScreen())); }),
                    _buildMenuItem('💈', 'Barberos', () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => BarbersScreen())).then((_) => _loadData()); }),
                    _buildMenuItem('✂️', 'Servicios', () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => ServicesScreen())).then((_) => _loadData()); }),
                    _buildMenuItem('📦', 'Productos', () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => ProductsScreen())).then((_) => _loadData()); }),
                    _buildMenuItem('👥', 'Usuarios', () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => UsersScreen())); }),
                    _buildMenuItem('📅', 'Agenda de Citas', () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => AppointmentsScreen())); }),
                    _buildMenuItem('📖', 'Dashboard', () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => DashboardScreen())); }),
                    _buildMenuItem('📈', 'Reportes', () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => ReportsScreen())); }),
                    _buildMenuItem('🧾', 'Historial de Ventas', () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => SalesHistoryScreen())); }),
                    _buildMenuItem('⚙️', 'Configuración', () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => SettingsScreen())); }),
                  ],
                  if (currentUserRole == 'cashier') ...[
                    _buildMenuItem('🧾', 'Historial', () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => SalesHistoryScreen())); }),
                    _buildMenuItem('📅', 'Agenda de Citas', () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => AppointmentsScreen())); }),
                    _buildMenuItem('📊', 'Dashboard', () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => DashboardScreen())); }),
                  ],
                  if (currentUserRole == 'barber') ...[
                    _buildMenuItem('📜', 'Historial', () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => SalesHistoryScreen())); }),
                    _buildMenuItem('📅', 'Agenda de Citas', () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => AppointmentsScreen())); }),
                  ],
                  _buildMenuItem('👨‍💼', 'Clientes', () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => ClientsScreen())).then((_) => _loadData()); }),
                  Divider(color: isDark ? Colors.grey[700] : Colors.grey[300]),
                  _buildMenuItem('🚪', 'Cerrar sesión', () { Navigator.pop(context); _handleLogout(); }, isLogout: true),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(String icon, String text, VoidCallback onTap, {bool isLogout = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      leading: Text(icon, style: const TextStyle(fontSize: 24)),
      title: Text(
        text,
        style: TextStyle(
          fontSize: 16,
          color: isLogout ? Colors.red : (isDark ? Colors.white : Colors.black87),
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    );
  }

  void _showCartBottomSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) => Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(children: [
                  const Text('', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Text('Carrito (${_cart.length})', style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                ]),
              ),
              Expanded(
                child: _cart.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('🛒', style: TextStyle(fontSize: 64)),
                      const SizedBox(height: 16),
                      Text('Carrito vacío', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[400], fontSize: 16)),
                      const SizedBox(height: 8),
                      Text('Agrega servicios o productos', style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[400], fontSize: 12)),
                    ],
                  ),
                )
                    : ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _cart.length,
                  itemBuilder: (context, index) {
                    final item = _cart[index];
                    final isService = item.type == 'service';
                    return Card(
                      elevation: 1,
                      margin: const EdgeInsets.only(bottom: 8),
                      color: isDark ? const Color(0xFF334155) : Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        leading: Text(isService ? '✂️' : '🛍️', style: TextStyle(fontSize: 24)),
                        title: Text(
                          item.serviceName.isNotEmpty ? item.serviceName : (item.productName ?? ''),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${SettingsService.formatCurrency(item.priceAtMoment)} x ${item.quantity}',
                              style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                            ),
                            if (isService && item.barberName.isNotEmpty)
                              Text('Barbero: ${item.barberName}', style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                          ],
                        ),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                            icon: const Text('➖', style: TextStyle(fontSize: 16)),
                            onPressed: () {
                              setModalState(() {
                                if (item.quantity <= 1) {
                                  _cart.removeAt(index);
                                } else {
                                  item.quantity--;
                                }
                              });
                              setState(() {});
                            },
                          ),
                          Text('${item.quantity}', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                          IconButton(
                            icon: const Text('➕', style: TextStyle(fontSize: 16)),
                            onPressed: () {
                              setModalState(() {
                                item.quantity++;
                              });
                              setState(() {});
                            },
                          ),
                          IconButton(
                            icon: const Text('🗑️', style: TextStyle(fontSize: 16)),                            onPressed: () {
                              setModalState(() {
                                _cart.removeAt(index);
                              });
                              setState(() {});
                            },
                          ),
                        ]),
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : Colors.grey[50],
                  border: Border(top: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Subtotal:', style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey)),
                        Text(SettingsService.formatCurrency(_subtotal), style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('TOTAL:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        Text(
                          SettingsService.formatCurrency(_total),
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green[400]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _showAppointmentSelector,
                      icon: const Text('📅', style: TextStyle(fontSize: 16)),
                      label: Text(
                        _selectedAppointment?.clientName ?? 'Seleccionar cita',
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 40),
                        side: BorderSide(color: isDark ? Colors.grey[600]! : Colors.grey[400]!),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _showClientSelector,
                      icon: const Text('👤', style: TextStyle(fontSize: 16)),
                      label: Text(
                        _selectedClient?.name ?? 'Seleccionar cliente',
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 40),
                        side: BorderSide(color: isDark ? Colors.grey[600]! : Colors.grey[400]!),
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _paymentMethod,
                      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF334155) : Colors.white,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'cash', child: Text('💵 Efectivo')),
                        DropdownMenuItem(value: 'card', child: Text('💳 Tarjeta')),
                        DropdownMenuItem(value: 'transfer', child: Text('📱 Transferencia')),
                      ],
                      onChanged: (value) { setState(() { _paymentMethod = value!; }); },
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _cart.isEmpty ? null : _processPayment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[600],
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('COBRAR', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = MediaQuery.of(context).size.width < 700;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(
              child: Text(
                '${SettingsService.shopName} POS',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 14 : 20, color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person, size: 16, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(
                    currentUserName.isNotEmpty ? currentUserName : 'Usuario',
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF6366F1),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Text('✂️', style: TextStyle(fontSize: 20)), text: 'Servicios'),
            Tab(icon: Text('📦', style: TextStyle(fontSize: 20)), text: 'Productos'),
          ],
        ),
        actions: [
          if (isMobile)
            IconButton(
              icon: const Text('☰', style: TextStyle(fontSize: 28, color: Colors.white)),
              onPressed: _showMobileMenu,
            )
          else
            ...[
              if (currentUserRole == 'admin') ...[
                IconButton(icon: const Text('💰', style: TextStyle(fontSize: 20)), tooltip: 'Comisiones', onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (context) => CommissionsScreen())); }),
                IconButton(icon: const Text('💈', style: TextStyle(fontSize: 20)), tooltip: 'Barberos', onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (context) => BarbersScreen())).then((_) => _loadData()); }),
                IconButton(icon: const Text('✂️', style: TextStyle(fontSize: 20)), tooltip: 'Servicios', onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (context) => ServicesScreen())).then((_) => _loadData()); }),
                IconButton(icon: const Text('📦', style: TextStyle(fontSize: 20)), tooltip: 'Productos', onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (context) => ProductsScreen())).then((_) => _loadData()); }),
                IconButton(icon: const Text('👥', style: TextStyle(fontSize: 20)), tooltip: 'Usuarios', onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (context) => UsersScreen())); }),
                IconButton(icon: const Text('📅', style: TextStyle(fontSize: 20)), tooltip: 'Agenda', onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (context) => AppointmentsScreen())); }),
                IconButton(icon: const Text('📊', style: TextStyle(fontSize: 20)), tooltip: 'Dashboard', onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (context) => DashboardScreen())); }),
                IconButton(icon: const Text('📈', style: TextStyle(fontSize: 20)), tooltip: 'Reportes', onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (context) => ReportsScreen())); }),
                IconButton(icon: const Text('🧾', style: TextStyle(fontSize: 20)), tooltip: 'Historial de Ventas', onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (context) => SalesHistoryScreen())); }),
                IconButton(icon: const Text('📝', style: TextStyle(fontSize: 20)), tooltip: 'Reportes Avanzados', onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (context) => AdvancedReportsScreen())); }),
                IconButton(icon: const Text('⚙️', style: TextStyle(fontSize: 20)), tooltip: 'Config', onPressed: () {Navigator.push(context, MaterialPageRoute(builder: (context) => SettingsScreen()));},),
              ],
              if (currentUserRole == 'cashier') ...[
                IconButton(icon: const Text('📜', style: TextStyle(fontSize: 20)), tooltip: 'Historial', onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (context) => SalesHistoryScreen())); }),
                IconButton(icon: const Text('📅', style: TextStyle(fontSize: 20)), tooltip: 'Agenda', onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (context) => AppointmentsScreen())); }),
                IconButton(icon: const Text('📊', style: TextStyle(fontSize: 20)), tooltip: 'Dashboard', onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (context) => DashboardScreen())); }),
              ],
              if (currentUserRole == 'barber') ...[
                IconButton(icon: const Text('📜', style: TextStyle(fontSize: 20)), tooltip: 'Historial', onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (context) => SalesHistoryScreen())); }),
                IconButton(icon: const Text('📅', style: TextStyle(fontSize: 20)), tooltip: 'Agenda', onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (context) => AppointmentsScreen())); }),
              ],
              IconButton(icon: const Text('👨‍💼', style: TextStyle(fontSize: 20)), tooltip: 'Clientes', onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (context) => ClientsScreen())).then((_) => _loadData()); }),
              IconButton(icon: const Text('🚪', style: TextStyle(fontSize: 20)), tooltip: 'Salir', onPressed: _handleLogout),
            ],
        ],
      ),
      body: isMobile ? _buildMobileLayout() : _buildDesktopLayout(),
      floatingActionButton: isMobile && _cart.isNotEmpty
          ? FloatingActionButton.extended(
        onPressed: () => _showCartBottomSheet(),
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        icon: const Text('', style: TextStyle(fontSize: 20)),
        label: Text('${_cart.length} - ${SettingsService.formatCurrency(_total)}', style: const TextStyle(fontWeight: FontWeight.bold)),
      )
          : null,
    );
  }

  Widget _buildMobileLayout() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          child: Row(
            children: [
              const Text('💈', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              const Text('Barbero:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: _showBarberSelector,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: _selectedBarber != null ? const Color(0xFF6366F1) : (isDark ? Colors.grey[700]! : Colors.grey[300]!)),
                      borderRadius: BorderRadius.circular(8),
                      color: _selectedBarber != null
                          ? const Color(0xFF6366F1).withOpacity(0.1)
                          : (isDark ? const Color(0xFF334155) : Colors.white),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _selectedBarber?.name ?? 'Toca para seleccionar',
                            style: TextStyle(
                              fontSize: 14,
                              color: _selectedBarber != null
                                  ? const Color(0xFF818CF8)
                                  : (isDark ? Colors.grey[400] : Colors.grey[600]),
                              fontWeight: _selectedBarber != null ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_drop_down,
                          color: _selectedBarber != null ? const Color(0xFF6366F1) : (isDark ? Colors.grey[500] : Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildServicesGrid(mobile: true),
              _buildProductsGrid(mobile: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Container(
            color: isDark ? const Color(0xFF0F172A) : Colors.grey[50],
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('💈', style: TextStyle(fontSize: 20)),
                      ),
                      const SizedBox(width: 12),
                      const Text('Barbero:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: InkWell(
                          onTap: _showBarberSelector,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: _selectedBarber != null ? const Color(0xFF6366F1) : (isDark ? Colors.grey[700]! : Colors.grey[300]!)),
                              borderRadius: BorderRadius.circular(8),
                              color: _selectedBarber != null
                                  ? const Color(0xFF6366F1).withOpacity(0.1)
                                  : (isDark ? const Color(0xFF334155) : Colors.white),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _selectedBarber?.name ?? 'Toca para seleccionar un barbero',
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: _selectedBarber != null
                                          ? const Color(0xFF818CF8)
                                          : (isDark ? Colors.grey[400] : Colors.grey[600]),
                                      fontWeight: _selectedBarber != null ? FontWeight.w600 : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_drop_down,
                                  color: _selectedBarber != null ? const Color(0xFF6366F1) : (isDark ? Colors.grey[500] : Colors.grey),
                                  size: 24,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildServicesGrid(mobile: false),
                      _buildProductsGrid(mobile: false),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(flex: 1, child: _buildCartPanel()),
      ],
    );
  }

  Widget _buildServicesGrid({required bool mobile}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: mobile ? 2 : 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: mobile ? 0.85 : 1.1,
      ),
      itemCount: _services.length,
      itemBuilder: (context, index) {
        final service = _services[index];
        return Card(
          elevation: 2,
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            onTap: () => _addServiceToCart(service),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [const Color(0xFF312E81), const Color(0xFF1E293B)]
                      : [Colors.indigo[50]!, Colors.white],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Text('✂️', style: TextStyle(fontSize: mobile ? 24 : 32)),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      service.name,
                      style: TextStyle(
                        fontSize: mobile ? 12 : 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        SettingsService.formatCurrency(service.price),
                        style: TextStyle(
                          fontSize: mobile ? 12 : 16,
                          color: Colors.green[400],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProductsGrid({required bool mobile}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: mobile ? 2 : 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: mobile ? 0.85 : 1.1,
      ),
      itemCount: _products.length,
      itemBuilder: (context, index) {
        final product = _products[index];
        final isLowStock = product.stock <= product.minStock;
        return Card(
          elevation: 2,
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            onTap: product.stock > 0 ? () => _addProductToCart(product) : null,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [const Color(0xFF7C2D12), const Color(0xFF1E293B)]
                      : [Colors.orange[50]!, Colors.white],
                ),
                border: isLowStock ? Border.all(color: Colors.red, width: 2) : null,
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Text('🛍️', style: TextStyle(fontSize: mobile ? 24 : 32)),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      product.name,
                      style: TextStyle(
                        fontSize: mobile ? 12 : 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        SettingsService.formatCurrency(product.price),
                        style: TextStyle(
                          fontSize: mobile ? 12 : 16,
                          color: Colors.green[400],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Stock: ${product.stock}',
                      style: TextStyle(
                        fontSize: 10,
                        color: isLowStock ? Colors.red : (isDark ? Colors.grey[400] : Colors.grey[600]),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCartPanel() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))],
            ),
            child: Row(children: [
              const Text('🛒', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text('Carrito (${_cart.length})', style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
            ]),
          ),
          if (_selectedAppointment != null)
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.blue.withOpacity(0.1),
              child: Row(children: [
                const Text('📅', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(child: Text('Cita: ${_selectedAppointment!.clientName}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black87))),
                IconButton(
                  icon: const Text('✕', style: TextStyle(fontSize: 14)),
                  onPressed: () { setState(() { _selectedAppointment = null; }); },
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ]),
            ),
          if (_selectedClient != null)
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.green.withOpacity(0.1),
              child: Row(children: [
                const Text('👤', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(child: Text(_selectedClient!.name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black87))),
                IconButton(
                  icon: const Text('', style: TextStyle(fontSize: 14)),
                  onPressed: () { setState(() { _selectedClient = null; }); },
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ]),
            ),
          Expanded(
            child: _cart.isEmpty
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Text('🛒', style: TextStyle(fontSize: 64)),
                    const SizedBox(height: 16),
                    Text('Carrito vacío', style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[400], fontSize: 16)),
                    const SizedBox(height: 8),
                    Text('Agrega servicios o productos', style: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[400], fontSize: 12)),
                  ]))
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _cart.length,
              itemBuilder: (context, index) {
                final item = _cart[index];
                final isService = item.type == 'service';
                return Card(
                  elevation: 1,
                  color: isDark ? const Color(0xFF334155) : Colors.white,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    leading: Text(isService ? '✂️' : '🛍️', style: TextStyle(fontSize: 24)),
                    title: Text(
                      item.serviceName.isNotEmpty ? item.serviceName : (item.productName ?? ''),
                      style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${SettingsService.formatCurrency(item.priceAtMoment)} x ${item.quantity}', style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                        if (isService && item.barberName.isNotEmpty) Text('Barbero: ${item.barberName}', style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                      ],
                    ),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(icon: const Text('➖', style: TextStyle(fontSize: 16)), onPressed: () => _updateQuantity(index, item.quantity - 1)),
                      Text('${item.quantity}', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                      IconButton(icon: const Text('➕', style: TextStyle(fontSize: 16)), onPressed: () => _updateQuantity(index, item.quantity + 1)),
                      const SizedBox(width: 8),
                      Text(
                        SettingsService.formatCurrency(item.priceAtMoment * item.quantity),
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF818CF8)),
                      ),
                    ]),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.grey[50],
              border: Border(top: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, -2))],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Subtotal:', style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey)),
                    Text(SettingsService.formatCurrency(_subtotal), style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
                  ],
                ),
                if (_discount > 0) Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Descuento:', style: TextStyle(fontSize: 14, color: Colors.red)),
                    Text('-${SettingsService.formatCurrency(_discount)}', style: const TextStyle(fontSize: 14, color: Colors.red)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('TOTAL:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    Text(
                      SettingsService.formatCurrency(_total),
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green[400]),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _showAppointmentSelector,
                  icon: const Text('📅', style: TextStyle(fontSize: 16)),
                  label: Text(
                    _selectedAppointment?.clientName ?? 'Seleccionar cita',
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 40),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    side: BorderSide(color: isDark ? Colors.grey[600]! : Colors.grey[400]!),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _showClientSelector,
                  icon: const Text('👤', style: TextStyle(fontSize: 16)),
                  label: Text(
                    _selectedClient?.name ?? 'Seleccionar cliente',
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 40),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    side: BorderSide(color: isDark ? Colors.grey[600]! : Colors.grey[400]!),
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _paymentMethod,
                  dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF334155) : Colors.white,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('💵 Efectivo')),
                    DropdownMenuItem(value: 'card', child: Text('💳 Tarjeta')),
                    DropdownMenuItem(value: 'transfer', child: Text('📱 Transferencia')),
                  ],
                  onChanged: (value) { setState(() { _paymentMethod = value!; }); },
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _cart.isEmpty ? null : _processPayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      disabledBackgroundColor: Colors.grey[300],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 2,
                    ),
                    child: const Text('COBRAR', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}