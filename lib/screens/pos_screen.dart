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
      if (barbers.isNotEmpty) _selectedBarber = barbers.first;
    });
  }

  void _addServiceToCart(LocalService service) {
    if (_selectedBarber == null) {
      _showSnackbar('Selecciona un barbero primero', Colors.orange);
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

  void _removeFromCart(int index) {
    setState(() { _cart.removeAt(index); });
  }

  void _updateQuantity(int index, int newQuantity) {
    if (newQuantity <= 0) {
      _removeFromCart(index);
      return;
    }
    setState(() {
      _cart[index].quantity = newQuantity;
    });
  }

  double get _subtotal => _cart.fold(0.0, (sum, item) => sum + (item.priceAtMoment * item.quantity));
  double get _total => _subtotal - _discount;

  Future<void> _processPayment() async {
    if (_cart.isEmpty) {
      _showSnackbar('Agrega servicios o productos al carrito', Colors.orange);
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar venta'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total: ${SettingsService.formatCurrency(_total)}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Método de pago: ${_formatPaymentMethod(_paymentMethod)}',
                style: TextStyle(color: Colors.grey[700])),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
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
            title: const Row(
              children: [
                Text('💵', style: TextStyle(fontSize: 24)),
                SizedBox(width: 8),
                Text('Pago en Efectivo'),
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
                      color: Colors.indigo[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.indigo[200]!),
                    ),
                    child: Column(
                      children: [
                        const Text('Total a pagar', style: TextStyle(color: Colors.grey, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text(
                          SettingsService.formatCurrency(_total),
                          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.indigo[700]),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: receivedController,
                    autofocus: true,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Monto recibido',
                      hintText: '0',
                      prefixText: '${SettingsService.currencySymbol} ',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.green[700]!, width: 2),
                      ),
                    ),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    onChanged: (_) => calculateChange(),
                  ),
                  const SizedBox(height: 12),
                  const Text('Billetes rápidos:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [10000, 20000, 50000, 100000, 200000].map((amount) {
                      return ElevatedButton(
                        onPressed: () {
                          receivedController.text = amount.toString();
                          calculateChange();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[50],
                          foregroundColor: Colors.green[700],
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
                      color: change >= 0 ? Colors.green[50] : Colors.red[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: change >= 0 ? Colors.green[300]! : Colors.red[300]!,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          change >= 0 ? 'Cambio a devolver' : 'Falta por pagar',
                          style: TextStyle(
                            color: change >= 0 ? Colors.green[700] : Colors.red[700],
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          SettingsService.formatCurrency(change.abs()),
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: change >= 0 ? Colors.green[700] : Colors.red[700],
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
                child: const Text('Cancelar'),
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

    final printed = await _printer.printTicket(transaction);
    if (!printed) {
      if (!mounted) return;
      final shouldSave = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Impresión cancelada'),
          content: const Text('¿Desea registrar la venta de todas formas?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No, cancelar venta')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sí, registrar venta')),
          ],
        ),
      );
      if (shouldSave != true) {
        _showSnackbar('Venta cancelada', Colors.orange);
        return;
      }
    }

    try {
      print('🔄 Subiendo transacción a Supabase...');
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
      })
          .select()
          .single();

      final transactionId = transResponse['id'];
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
      print('✅ ${itemsData.length} items subidos a Supabase');

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
      print('⚠️ ERROR DETALLADO al subir a Supabase: $e');
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
      await _clientRepo.incrementVisits(_selectedClient!.remoteId!, _total);
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
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Text('✅', style: TextStyle(fontSize: 24)),
                SizedBox(width: 8),
                Text('¡Pago Exitoso!'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Text('Cambio a entregar', style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text(
                        SettingsService.formatCurrency(change),
                        style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.green[700]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Recibido: ${SettingsService.formatCurrency(cashReceived)}',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green[600]),
                child: const Text('Entregar cambio'),
              ),
            ],
          ),
        );
      }
    } else {
      _showSnackbar(printed ? '✅ Venta registrada y ticket impreso' : '✅ Venta registrada', Colors.green);
    }
  }

  void _showClientSelector() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seleccionar Cliente'),
        content: SizedBox(
          width: 400, height: 400,
          child: _clients.isEmpty
              ? const Center(child: Text('No hay clientes registrados'))
              : ListView.builder(
            itemCount: _clients.length,
            itemBuilder: (context, index) {
              final client = _clients[index];
              return ListTile(
                leading: CircleAvatar(
                    backgroundColor: Colors.indigo[100],
                    child: Text(client.name[0].toUpperCase(), style: TextStyle(color: Colors.indigo[700]))),
                title: Text(client.name),
                subtitle: Text(client.phone ?? 'Sin teléfono'),
                onTap: () { setState(() { _selectedClient = client; }); Navigator.pop(context); },
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () { setState(() { _selectedClient = null; }); Navigator.pop(context); }, child: const Text('Sin cliente')),
        ],
      ),
    );
  }

  void _showAppointmentSelector() {
    if (_todayAppointments.isEmpty) {
      _showSnackbar('No hay citas pendientes para hoy', Colors.orange);
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seleccionar Cita'),
        content: SizedBox(
          width: 400, height: 400,
          child: ListView.builder(
            itemCount: _todayAppointments.length,
            itemBuilder: (context, index) {
              final apt = _todayAppointments[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: apt.status == 'pending' ? Colors.orange[100] : Colors.green[100],
                  child: Text('📅', style: TextStyle(fontSize: 20, color: apt.status == 'pending' ? Colors.orange[700] : Colors.green[700])),
                ),
                title: Text(apt.clientName ?? 'Sin cliente'),
                subtitle: Text('${apt.serviceName ?? ''} - ${apt.barberName ?? ''}\n${apt.appointmentDate.hour.toString().padLeft(2, '0')}:${apt.appointmentDate.minute.toString().padLeft(2, '0')}'),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (apt.status == 'pending' ? Colors.orange : Colors.green).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    apt.status == 'pending' ? 'Pendiente' : 'Confirmada',
                    style: TextStyle(color: apt.status == 'pending' ? Colors.orange[700] : Colors.green[700], fontSize: 12, fontWeight: FontWeight.bold),
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
          TextButton(onPressed: () { setState(() { _selectedAppointment = null; }); Navigator.pop(context); }, child: const Text('Sin cita')),
        ],
      ),
    );
  }

  void _showSnackbar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Estás seguro que deseas cerrar sesión?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Cerrar sesión')),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${SettingsService.shopName} POS', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.indigo[700],
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Text('✂️', style: TextStyle(fontSize: 20)), text: 'Servicios'),
            Tab(icon: Text('📦', style: TextStyle(fontSize: 20)), text: 'Productos'),
          ],
        ),
        actions: [
          if (currentUserRole == 'admin') ...[
            IconButton(icon: const Text('💈', style: TextStyle(fontSize: 20)), tooltip: 'Barberos', onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (context) => BarbersScreen())).then((_) => _loadData()); }),
            IconButton(icon: const Text('✂️', style: TextStyle(fontSize: 20)), tooltip: 'Servicios', onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (context) => ServicesScreen())).then((_) => _loadData()); }),
            IconButton(icon: const Text('📦', style: TextStyle(fontSize: 20)), tooltip: 'Productos', onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (context) => ProductsScreen())).then((_) => _loadData()); }),
            IconButton(icon: const Text('👥', style: TextStyle(fontSize: 20)), tooltip: 'Usuarios', onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (context) => UsersScreen())); }),
            IconButton(icon: const Text('📅', style: TextStyle(fontSize: 20)), tooltip: 'Agenda de Citas', onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (context) => AppointmentsScreen())); }),
            IconButton(icon: const Text('📊', style: TextStyle(fontSize: 20)), tooltip: 'Dashboard', onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (context) => DashboardScreen())); }),
            IconButton(icon: const Text('📈', style: TextStyle(fontSize: 20)), tooltip: 'Reportes', onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (context) => ReportsScreen())); }),
            IconButton(icon: const Text('⚙️', style: TextStyle(fontSize: 20)), tooltip: 'Configuración', onPressed: () {Navigator.push(context, MaterialPageRoute(builder: (context) => SettingsScreen()));},),
          ],
          if (currentUserRole == 'cashier') ...[
            IconButton(icon: const Text('📜', style: TextStyle(fontSize: 20)), tooltip: 'Historial', onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (context) => SalesHistoryScreen())); }),
            IconButton(icon: const Text('📅', style: TextStyle(fontSize: 20)), tooltip: 'Agenda de Citas', onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (context) => AppointmentsScreen())); }),
            IconButton(icon: const Text('📊', style: TextStyle(fontSize: 20)), tooltip: 'Dashboard', onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (context) => DashboardScreen())); }),
          ],
          if (currentUserRole == 'barber') ...[
            IconButton(icon: const Text('📜', style: TextStyle(fontSize: 20)), tooltip: 'Historial', onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (context) => SalesHistoryScreen())); }),
            IconButton(icon: const Text('📅', style: TextStyle(fontSize: 20)), tooltip: 'Agenda de Citas', onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (context) => AppointmentsScreen())); }),
          ],
          IconButton(icon: const Text('👥', style: TextStyle(fontSize: 20)), tooltip: 'Clientes', onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (context) => ClientsScreen())).then((_) => _loadData()); }),
          IconButton(icon: const Text('👋', style: TextStyle(fontSize: 20)), tooltip: 'Cerrar sesión', onPressed: _handleLogout),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.grey[50],
              child: Column(
                children: [
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // PESTAÑA SERVICIOS
                        Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))]),
                              child: Row(
                                children: [
                                  Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.indigo[50], borderRadius: BorderRadius.circular(8)), child: const Text('👤', style: TextStyle(fontSize: 20))),
                                  const SizedBox(width: 12),
                                  const Text('Barbero:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: DropdownButtonFormField<LocalBarber>(
                                      value: _selectedBarber,
                                      decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                                      items: _barbers.map((barber) => DropdownMenuItem(value: barber, child: Text(barber.name))).toList(),
                                      onChanged: (value) { setState(() { _selectedBarber = value; }); },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: GridView.builder(
                                padding: const EdgeInsets.all(16),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.1),
                                itemCount: _services.length,
                                itemBuilder: (context, index) {
                                  final service = _services[index];
                                  return Card(
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    child: InkWell(
                                      onTap: () => _addServiceToCart(service),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.indigo[50]!, Colors.white])),
                                        child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.indigo[100], shape: BoxShape.circle), child: const Text('✂️', style: TextStyle(fontSize: 32))),
                                              const SizedBox(height: 12),
                                              Text(service.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                                              const SizedBox(height: 8),
                                              Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: Colors.green[100], borderRadius: BorderRadius.circular(20)), child: Text(SettingsService.formatCurrency(service.price), style: TextStyle(fontSize: 16, color: Colors.green[700], fontWeight: FontWeight.bold))),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        // PESTAÑA PRODUCTOS
                        GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.1),
                          itemCount: _products.length,
                          itemBuilder: (context, index) {
                            final product = _products[index];
                            final isLowStock = product.stock <= product.minStock;
                            return Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: InkWell(
                                onTap: product.stock > 0 ? () => _addProductToCart(product) : null,
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.orange[50]!, Colors.white]),
                                    border: isLowStock ? Border.all(color: Colors.red, width: 2) : null,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.orange[100], shape: BoxShape.circle), child: const Text('🛍️', style: TextStyle(fontSize: 32))),
                                        const SizedBox(height: 12),
                                        Text(product.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                                        const SizedBox(height: 8),
                                        Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: Colors.green[100], borderRadius: BorderRadius.circular(20)), child: Text(SettingsService.formatCurrency(product.price), style: TextStyle(fontSize: 16, color: Colors.green[700], fontWeight: FontWeight.bold))),
                                        const SizedBox(height: 4),
                                        Text('Stock: ${product.stock}', style: TextStyle(fontSize: 12, color: isLowStock ? Colors.red : Colors.grey[600], fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // CARRITO
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.white,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.indigo[700], boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))]),
                    child: Row(children: [const Text('🛒', style: TextStyle(fontSize: 20)), const SizedBox(width: 8), Text('Carrito (${_cart.length})', style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold))]),
                  ),
                  if (_selectedAppointment != null)
                    Container(
                      padding: const EdgeInsets.all(8),
                      color: Colors.blue[50],
                      child: Row(children: [
                        const Text('', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Cita: ${_selectedAppointment!.clientName}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
                        IconButton(icon: const Text('✕', style: TextStyle(fontSize: 14)), onPressed: () { setState(() { _selectedAppointment = null; }); }),
                      ]),
                    ),
                  if (_selectedClient != null)
                    Container(
                      padding: const EdgeInsets.all(8),
                      color: Colors.green[50],
                      child: Row(children: [const Text('👤', style: TextStyle(fontSize: 16)), const SizedBox(width: 8), Expanded(child: Text(_selectedClient!.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))), IconButton(icon: const Text('✕', style: TextStyle(fontSize: 14)), onPressed: () { setState(() { _selectedClient = null; }); })]),
                    ),
                  Expanded(
                    child: _cart.isEmpty
                        ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Text('', style: TextStyle(fontSize: 64)), const SizedBox(height: 16), Text('Carrito vacío', style: TextStyle(color: Colors.grey[400], fontSize: 16)), const SizedBox(height: 8), Text('Agrega servicios o productos', style: TextStyle(color: Colors.grey[400], fontSize: 12))]))
                        : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _cart.length,
                      itemBuilder: (context, index) {
                        final item = _cart[index];
                        final isService = item.type == 'service';
                        return Card(
                          elevation: 1, margin: const EdgeInsets.only(bottom: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            leading: Text(isService ? '✂️' : '🛍️', style: TextStyle(fontSize: 24)),
                            title: Text(item.serviceName.isNotEmpty ? item.serviceName : (item.productName ?? ''), style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${SettingsService.formatCurrency(item.priceAtMoment)} x ${item.quantity}', style: const TextStyle(fontSize: 12)),
                                if (isService && item.barberName.isNotEmpty) Text('Barbero: ${item.barberName}', style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                              IconButton(icon: const Text('➖', style: TextStyle(fontSize: 16)), onPressed: () => _updateQuantity(index, item.quantity - 1)),
                              Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              IconButton(icon: const Text('➕', style: TextStyle(fontSize: 16)), onPressed: () => _updateQuantity(index, item.quantity + 1)),
                              const SizedBox(width: 8),
                              Text(SettingsService.formatCurrency(item.priceAtMoment * item.quantity), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.indigo)),
                            ]),
                          ),
                        );
                      },
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.grey[50], border: Border(top: BorderSide(color: Colors.grey[300]!)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, -2))]),
                    child: Column(
                      children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Subtotal:', style: TextStyle(fontSize: 14, color: Colors.grey)), Text(SettingsService.formatCurrency(_subtotal), style: const TextStyle(fontSize: 14))]),
                        if (_discount > 0) Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Descuento:', style: TextStyle(fontSize: 14, color: Colors.red)), Text('-${SettingsService.formatCurrency(_discount)}', style: const TextStyle(fontSize: 14, color: Colors.red))]),
                        const SizedBox(height: 8),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('TOTAL:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), Text(SettingsService.formatCurrency(_total), style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green[700]))]),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(onPressed: _showAppointmentSelector, icon: const Text('📅', style: TextStyle(fontSize: 16)), label: Text(_selectedAppointment?.clientName ?? 'Seleccionar cita (opcional)'), style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 40), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)))),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(onPressed: _showClientSelector, icon: const Text('👤', style: TextStyle(fontSize: 16)), label: Text(_selectedClient?.name ?? 'Seleccionar cliente'), style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 40), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)))),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _paymentMethod,
                          decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                          items: const [DropdownMenuItem(value: 'cash', child: Text('💵 Efectivo')), DropdownMenuItem(value: 'card', child: Text('💳 Tarjeta')), DropdownMenuItem(value: 'transfer', child: Text('📱 Transferencia'))],
                          onChanged: (value) { setState(() { _paymentMethod = value!; }); },
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity, height: 52,
                          child: ElevatedButton(onPressed: _cart.isEmpty ? null : _processPayment, style: ElevatedButton.styleFrom(backgroundColor: Colors.green[600], disabledBackgroundColor: Colors.grey[300], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 2), child: const Text('COBRAR', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}