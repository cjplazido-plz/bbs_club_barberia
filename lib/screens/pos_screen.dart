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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [Text('💈', style: TextStyle(fontSize: 24)), SizedBox(width: 8), Text('Selecciona un barbero', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))]),
        content: const Text('Para agregar servicios, primero selecciona un barbero.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          Container(
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF818CF8)]), borderRadius: BorderRadius.circular(10)),
            child: ElevatedButton(onPressed: () { Navigator.pop(context); _showBarberSelector(); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent), child: const Text('Elegir')),
          ),
        ],
      ),
    );
  }

  void _showBarberSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(color: Color(0xFF1E293B), borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            const Text('✂️ Elige Barbero', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 16),
            ..._barbers.map((b) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: _selectedBarber?.remoteId == b.remoteId ? const Color(0xFF6366F1).withOpacity(0.2) : const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _selectedBarber?.remoteId == b.remoteId ? const Color(0xFF6366F1) : Colors.white10),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(backgroundColor: const Color(0xFF6366F1).withOpacity(0.2), child: Text(b.name[0], style: const TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold))),
                    title: Text(b.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Text('Comisión ${b.commissionValue}%', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    trailing: _selectedBarber?.remoteId == b.remoteId ? const Icon(Icons.check_circle_rounded, color: Color(0xFF6366F1)) : null,
                    onTap: () { setState(() { _selectedBarber = b; }); Navigator.pop(context); _showSnackbar('✂️ ${b.name} seleccionado', const Color(0xFF6366F1)); },
                  ),
                )),
          ],
        ),
      ),
    );
  }

  void _showClientSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(color: Color(0xFF1E293B), borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('👤 Elige Cliente', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 16),
            SizedBox(height: 300, child: ListView.builder(itemCount: _clients.length, itemBuilder: (c, i) {
              final cl = _clients[i];
              return ListTile(title: Text(cl.name, style: const TextStyle(color: Colors.white)), subtitle: Text(cl.phone ?? '', style: const TextStyle(color: Colors.white54)), onTap: () { setState(() { _selectedClient = cl; }); Navigator.pop(context); });
            })),
          ],
        ),
      ),
    );
  }

  void _showAppointmentSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(color: Color(0xFF1E293B), borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📅 Citas de Hoy', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 16),
            if (_todayAppointments.isEmpty) const Text('No hay citas pendientes', style: TextStyle(color: Colors.white54)),
            ..._todayAppointments.map((a) => ListTile(title: Text(a.clientName ?? 'Cliente', style: const TextStyle(color: Colors.white)), subtitle: Text('${a.appointmentDate.hour.toString().padLeft(2, '0')}:${a.appointmentDate.minute.toString().padLeft(2, '0')} - ${a.serviceName ?? ''}', style: const TextStyle(color: Colors.white54, fontSize: 12)), onTap: () { setState(() { _selectedAppointment = a; if (_clients.isNotEmpty) { _selectedClient = _clients.firstWhere((c) => c.name == a.clientName, orElse: () => _clients.first); } }); Navigator.pop(context); })),
          ],
        ),
      ),
    );
  }

  double get _subtotal => _cart.fold(0, (sum, item) => sum + (item.priceAtMoment * item.quantity));
  double get _total => _subtotal - _discount;

  void _updateQuantity(int index, int qty) {
    setState(() {
      if (qty <= 0) { _cart.removeAt(index); } else { _cart[index].quantity = qty; }
    });
  }

  void _showSnackbar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
  }

  Future<void> _processPayment() async {
    // Lógica original de pago - mantenida
    try {
      final supabase = Supabase.instance.client;
      final total = _total;
      final transactionData = {
        'total': total,
        'subtotal': _subtotal,
        'discount': _discount,
        'payment_method': _paymentMethod,
        'cashier_name': supabase.auth.currentUser?.email ?? 'Cajero',
        'barber_name': _selectedBarber?.name,
        'client_name': _selectedClient?.name,
        'status': 'completed',
      };
      final transRes = await supabase.from('transactions').insert(transactionData).select().single();
      final transId = transRes['id'];
      for (var item in _cart) {
        await supabase.from('transaction_items').insert({
          'transaction_id': transId,
          'type': item.type,
          'service_id': (item.serviceId == null || item.serviceId!.isEmpty) ? null : item.serviceId,
          'product_id': (item.productId == null || item.productId!.isEmpty) ? null : item.productId,
          'service_name': item.serviceName,
          'product_name': item.productName,
          'barber_id': item.barberId,
          'barber_name': item.barberName,
          'price_at_moment': item.priceAtMoment,
          'quantity': item.quantity,
          'commission_earned': item.commissionEarned,
        });
      }
      setState(() { _cart.clear(); _discount = 0; _selectedClient = null; _selectedAppointment = null; });
      _showSnackbar('✅ Venta completada ${SettingsService.formatCurrency(total)}', Colors.green);
    } catch (e) {
      _showSnackbar('❌ Error: $e', Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = true;
    final bgColor = const Color(0xFF0F172A);
    final cardColor = const Color(0xFF1E293B);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF818CF8)]), borderRadius: BorderRadius.circular(10)), child: const Text('💈', style: TextStyle(fontSize: 18))),
          const SizedBox(width: 10),
          const Text('POS Premium', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
        ]),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF6366F1),
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          tabs: const [Tab(icon: Text('✂️'), text: 'Servicios'), Tab(icon: Text('📦'), text: 'Productos')],
        ),
      ),
      drawer: _buildPremiumDrawer(),
      body: Row(
        children: [
          Expanded(flex: 2, child: TabBarView(controller: _tabController, children: [_buildServicesTab(cardColor), _buildProductsTab(cardColor)])),
          Container(width: 1, color: Colors.white10),
          Expanded(flex: 1, child: _buildPremiumCart()),
        ],
      ),
    );
  }

Widget _buildPremiumDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF1E293B),
      child: ListView(padding: EdgeInsets.zero, children: [
        DrawerHeader(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF1E293B), Color(0xFF312E81)])), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(14)), child: const Text('💈', style: TextStyle(fontSize: 32))), const SizedBox(height: 12), const Text('BBS CLUB', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: 1)), Text('Barbería Premium', style: TextStyle(color: Colors.white60, fontSize: 12))])),
        _drawerItem('📊', 'Dashboard', () => Navigator.push(context, MaterialPageRoute(builder: (_) => DashboardScreen()))),
        _drawerItem('📅', 'Agenda', () => Navigator.push(context, MaterialPageRoute(builder: (_) => AppointmentsScreen()))),
        _drawerItem('👥', 'Clientes', () => Navigator.push(context, MaterialPageRoute(builder: (_) => ClientsScreen()))),
        _drawerItem('✂️', 'Barberos', () => Navigator.push(context, MaterialPageRoute(builder: (_) => BarbersScreen()))),
        _drawerItem('💈', 'Servicios', () => Navigator.push(context, MaterialPageRoute(builder: (_) => ServicesScreen()))),
        _drawerItem('📦', 'Productos', () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductsScreen()))),
        _drawerItem('🧾', 'Historial', () => Navigator.push(context, MaterialPageRoute(builder: (_) => SalesHistoryScreen()))),
        const Divider(color: Colors.white10, height: 1),
        _drawerItem('💰', 'Comisiones', () => Navigator.push(context, MaterialPageRoute(builder: (_) => CommissionsScreen()))),
        _drawerItem('📈', 'Reportes', () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReportsScreen()))),
        _drawerItem('📊', 'Reportes Avanzados', () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdvancedReportsScreen()))),
        _drawerItem('👑', 'Usuarios', () => Navigator.push(context, MaterialPageRoute(builder: (_) => UsersScreen()))),
        _drawerItem('⚙️', 'Ajustes', () => Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen()))),
        const Divider(color: Colors.white10, height: 1),
        _drawerItem('🚪', 'Salir', () async { await Supabase.instance.client.auth.signOut(); if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => LoginScreen()), (route) => false); }),
      ]),
    );
  }

  Widget _drawerItem(String icon, String title, VoidCallback onTap) {
    return ListTile(leading: Text(icon, style: const TextStyle(fontSize: 20)), title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)), onTap: onTap, hoverColor: const Color(0xFF6366F1).withOpacity(0.1));
  }

  Widget _buildServicesTab(Color cardColor) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 1.4, crossAxisSpacing: 12, mainAxisSpacing: 12),
      itemCount: _services.length,
      itemBuilder: (context, index) {
        final s = _services[index];
        return InkWell(
          onTap: () => _addServiceToCart(s),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withOpacity(0.05)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))]),
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: const Text('✂️', style: TextStyle(fontSize: 18))), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.15), borderRadius: BorderRadius.circular(20)), child: Text(SettingsService.formatCurrency(s.price), style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold)))]),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(s.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis), const SizedBox(height: 2), Text('${s.durationMinutes} min • ${s.commissionValue}%', style: const TextStyle(color: Colors.white54, fontSize: 11))]),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildProductsTab(Color cardColor) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 1.4, crossAxisSpacing: 12, mainAxisSpacing: 12),
      itemCount: _products.length,
      itemBuilder: (context, index) {
        final p = _products[index];
        return InkWell(
          onTap: () => _addProductToCart(p),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withOpacity(0.05)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))]),
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFF59E0B).withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: const Text('📦', style: TextStyle(fontSize: 18))), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.15), borderRadius: BorderRadius.circular(20)), child: Text(SettingsService.formatCurrency(p.price), style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold)))]),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(p.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis), Text('Stock: ${p.stock}', style: const TextStyle(color: Colors.white54, fontSize: 11))]),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildPremiumCart() {
    return Container(
      color: const Color(0xFF1E293B),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF1E293B), Color(0xFF312E81)]), border: Border(bottom: BorderSide(color: Colors.white10))),
            child: Row(children: [const Text('🛒', style: TextStyle(fontSize: 20)), const SizedBox(width: 8), const Text('Carrito', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)), const Spacer(), Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.2), borderRadius: BorderRadius.circular(20)), child: Text('${_cart.length}', style: const TextStyle(color: Color(0xFF818CF8), fontWeight: FontWeight.bold)))]),
          ),
          Expanded(
            child: _cart.isEmpty
                ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('🛒', style: TextStyle(fontSize: 48)), SizedBox(height: 12), Text('Carrito vacío', style: TextStyle(color: Colors.white54))]))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _cart.length,
                    itemBuilder: (context, index) {
                      final item = _cart[index];
                      final isService = item.type == 'service';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withOpacity(0.05))),
                        child: Row(
                          children: [
                            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: isService ? const Color(0xFF6366F1).withOpacity(0.15) : const Color(0xFFF59E0B).withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: Text(isService ? '✂️' : '📦', style: const TextStyle(fontSize: 14))),
                            const SizedBox(width: 10),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text((item.serviceName?.isNotEmpty == true ? item.serviceName : item.productName) ?? 'Item', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis), Text('${SettingsService.formatCurrency(item.priceAtMoment)} x ${item.quantity}', style: const TextStyle(color: Colors.white54, fontSize: 11)), if (item.barberName?.isNotEmpty == true) Text('✂️ ${item.barberName}', style: const TextStyle(color: Colors.white38, fontSize: 10))])),
                            Row(children: [
                              InkWell(onTap: () => _updateQuantity(index, item.quantity - 1), child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.remove_rounded, size: 14, color: Colors.white))),
                              Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('${item.quantity}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                              InkWell(onTap: () => _updateQuantity(index, item.quantity + 1), child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.add_rounded, size: 14, color: Color(0xFF818CF8)))),
                            ]),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(color: Color(0xFF0F172A), border: Border(top: BorderSide(color: Colors.white10))),
            child: Column(
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Subtotal:', style: TextStyle(color: Colors.white54, fontSize: 13)), Text(SettingsService.formatCurrency(_subtotal), style: const TextStyle(color: Colors.white, fontSize: 13))]),
                if (_discount > 0) Padding(padding: const EdgeInsets.only(top: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Descuento:', style: TextStyle(color: Colors.red, fontSize: 13)), Text('-${SettingsService.formatCurrency(_discount)}', style: const TextStyle(color: Colors.red, fontSize: 13))])),
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('TOTAL:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1)), Text(SettingsService.formatCurrency(_total), style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w900, fontSize: 26))]),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _showAppointmentSelector,
                    icon: const Text('📅'),
                    label: Text(_selectedAppointment?.clientName ?? 'Cita (opcional)', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 12)),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _showClientSelector,
                    icon: const Text('👤'),
                    label: Text(_selectedClient?.name ?? 'Cliente (opcional)', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 12)),
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _paymentMethod,
                  dropdownColor: const Color(0xFF1E293B),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white10)), filled: true, fillColor: const Color(0xFF1E293B), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                  items: const [DropdownMenuItem(value: 'cash', child: Text('💵 Efectivo')), DropdownMenuItem(value: 'card', child: Text('💳 Tarjeta')), DropdownMenuItem(value: 'transfer', child: Text('📱 Transferencia'))],
                  onChanged: (v) => setState(() => _paymentMethod = v!),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: Container(
                    decoration: BoxDecoration(gradient: LinearGradient(colors: _cart.isEmpty ? [Colors.grey, Colors.grey] : [const Color(0xFF10B981), const Color(0xFF059669)]), borderRadius: BorderRadius.circular(14), boxShadow: _cart.isEmpty ? [] : [BoxShadow(color: const Color(0xFF10B981).withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 6))]),
                    child: ElevatedButton(
                      onPressed: _cart.isEmpty ? null : _processPayment,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                      child: Text('COBRAR ${SettingsService.formatCurrency(_total)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                    ),
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
