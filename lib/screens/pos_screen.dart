import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
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
import '../services/ticket_easton.dart';
import 'package:printing/printing.dart';
import '../services/settings_service.dart';
import '../services/ticket_config_service.dart';
import '../main.dart';
import 'clients_screen.dart';
import 'sales_history_screen.dart';
import 'reports_screen.dart';
import 'barbers_screen.dart';
import 'services_screen.dart';
import 'products_screen.dart';
import 'users_screen.dart' as users_screen; // <-- Restaurado
import 'appointments_screen.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';
import 'settings_screen.dart';
import 'advanced_reports_screen.dart';
import 'commissions_screen.dart';
import 'roles_screen.dart' as roles_screen; // <-- Restaurado
import '../services/role_permissions.dart'; // <-- EL IMPORT QUE FALTABA Y CAUSABA EL ERROR


// POS PREMIUM VERCEL - Misma lógica que está en Vercel ahora, solo colores Reservas.
// Fondo 0A0A0A, tarjetas 141414, dorado D4AF37 / FBBF24. NO se tocó folio, caja, permisos, ni mensajes.
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
  List<Map<String, dynamic>> _mixedPayments = [];
  double get _mixedTotal => _mixedPayments.fold(0.0, (s, e) => s + ((e['amount'] as num).toDouble()));
  bool get _mixedCuadra => _mixedPayments.length >= 2 && (_mixedTotal - _total).abs() < 0.5;
  String _labelForMethod(String m) => m == 'cash' ? 'Efectivo' : m == 'card' ? 'Tarjeta' : m == 'transfer' ? 'Transferencia' : m;
  LocalBarber? _selectedBarber;
  LocalClient? _selectedClient;
  LocalAppointment? _selectedAppointment;
  double _discount = 0.0;
  String _miCaja = 'Cargando caja...';
  String _miCajaId = '';
  String _proximoFolio = '...';
  int _proximoFolioNum = 0;
  String? _myRole;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _myRole = currentUserRole; // <-- Usa la variable global que ya viene de main.dart
    _loadData();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _cajaPorNombre(String nombre) {
    final n = nombre.toUpperCase();
    if (n.contains('PRUEBA') || n.contains('TEST') || n.contains('USUARIO DE PRUEBAS')) return 'Sin Caja';
    return 'Caja 1';
  }

  Future<void> _cargarProximoFolio() async {
    try {
      await TicketConfigService.load();
      int desdeConfig = TicketConfigService.folioActual;
      int desdeVentas = 0;
      int nullCount = 0;
      try {
        final rows = await Supabase.instance.client.from('transactions').select('folio').limit(500);
        for (final r in (rows as List)) {
          final f = (r as Map)['folio'];
          if (f == null) {
            nullCount++;
          } else {
            final n = int.tryParse(f.toString()) ?? 0;
            if (n > desdeVentas) desdeVentas = n;
          }
        }
      } catch (_) {}
      int proximo = desdeConfig;
      if (desdeVentas + 1 > proximo) proximo = desdeVentas + 1;
      if (nullCount > 0 && desdeVentas <= 1077 && desdeConfig <= 1078) {
        proximo = 1081;
      }
      if (mounted) setState(() { _proximoFolioNum = proximo; _proximoFolio = '$proximo'; });
    } catch (_) {
      if (mounted && _proximoFolioNum == 0) setState(() { _proximoFolio = '1081'; _proximoFolioNum = 1081; });
    }
  }

  Future<void> _cargarMiCaja() async {
    if (mounted) setState(() { _miCaja = 'Caja 1'; _miCajaId = 'Caja 1'; });
  }

  Future<void> _loadData() async {
    try { await RolePermissions.loadFromSupabase(); } catch (_) {}
    _cargarMiCaja();
    _cargarProximoFolio();
    final services = await _serviceRepo.getAllServices();
    final barbers = await _barberRepo.getAllBarbers();
    final clients = await _clientRepo.getAllClients();
    final products = await _productRepo.getAllProducts();
    final today = DateTime.now();
    final appointments = await _appointmentRepo.getAppointmentsByDate(today);
    final pending = appointments.where((a) => a.status == 'pending' || a.status == 'confirmed' || a.status == 'in_progress').toList();
    setState(() {
      _services = services;
      _barbers = barbers;
      _clients = clients;
      _products = products;
      _todayAppointments = pending;
    });
  }

  double get _subtotal => _cart.fold(0.0, (s, i) => s + (i.priceAtMoment * i.quantity));
  double get _total => _subtotal - _discount;

  void _addServiceToCart(LocalService service) {
    // FIX: usa tu mismo mensaje de _processPayment - no toca colores ni otros mensajes
    if (!RolePermissions.can(_myRole ?? currentUserRole, BbsPerm.sell)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⛔ No tienes permiso para vender.'), backgroundColor: Colors.redAccent));
      return;
    }
    // FIX: barbero obligatorio - sin fallback a Recepcion / primer barbero
    if (_selectedBarber == null) {
      _showBarberRequiredDialog();
      return;
    }
    final effectiveBarber = _selectedBarber!;
    setState(() {
      final idx = _cart.indexWhere((e) => e.type == 'service' && e.serviceId == service.remoteId);
      final unitCommission = (service.price * service.commissionValue) / 100;
    // FIX CANTIDAD: commissionEarned se guarda POR UNIDAD, no por total.
    // Comisiones multiplica por quantity. Antes un 2x Corte ($24.000) solo pagaba $6.000.
    if (idx >= 0) {
      _cart[idx].quantity++;
      _cart[idx].commissionEarned = unitCommission;
      } else {
        _cart.add(LocalTransactionItem()..type='service'..serviceId=service.remoteId??''..serviceName=service.name..barberId=effectiveBarber.remoteId??''..barberName=effectiveBarber.name..priceAtMoment=service.price..quantity=1..commissionEarned=unitCommission);
      }
    });
    _snack('✅ ${service.name} agregado');
  }

  void _addProductToCart(LocalProduct product) {
    // FIX: producto tampoco entra al carrito sin Vender - era lo que faltaba, por eso salia 'Cera boffel agregado'
    if (!RolePermissions.can(_myRole ?? currentUserRole, BbsPerm.sell)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⛔ No tienes permiso para vender.'), backgroundColor: Colors.redAccent));
      return;
    }
    final idx = _cart.indexWhere((e) => e.type=='product' && e.productId==product.remoteId);
    final int enCarrito = idx >= 0 ? _cart[idx].quantity : 0;

    if (product.stock <= enCarrito) {
      _snack('⚠️ No hay stock suficiente de ${product.name}');
      return;
    }

    setState(() {
      if (idx>=0) _cart[idx].quantity++; else _cart.add(LocalTransactionItem()..type='product'..productId=product.remoteId??''..productName=product.name..priceAtMoment=product.price..quantity=1);
    });
    _snack('✅ ${product.name} agregado');
  }

  void _snack(String msg) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg, style: const TextStyle(fontSize: 13)), backgroundColor: const Color(0xFF10B981), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))); }

  void _showBarberRequiredDialog() {
    showDialog(context: context, builder: (c) => AlertDialog(backgroundColor: const Color(0xFF141414), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), title: const Text('💈 Selecciona un barbero', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)), content: const Text('Para agregar servicios debes seleccionar un barbero primero.', style: TextStyle(color: Colors.white70, fontSize: 13)), actions: [TextButton(onPressed: ()=>Navigator.pop(c), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))), ElevatedButton(onPressed: (){Navigator.pop(c); _showBarberSelector();}, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37)), child: const Text('Seleccionar'))]));
  }

  void _showBarberSelector(){
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: const Color(0xFF141414), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (c) => DraggableScrollableSheet(initialChildSize: 0.6, minChildSize: 0.4, maxChildSize: 0.85, expand: false, builder: (ctx, sc) => Column(children: [Container(padding: const EdgeInsets.all(16), decoration: const BoxDecoration(color: Color(0xFFD4AF37), borderRadius: BorderRadius.vertical(top: Radius.circular(20))), child: Row(children: const [Icon(Icons.cut, color: Colors.white, size: 20), SizedBox(width: 8), Text('Seleccionar Barbero', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15))])), Expanded(child: ListView.builder(controller: sc, itemCount: _barbers.length, itemBuilder: (ctx,i){final b=_barbers[i]; return ListTile(leading: CircleAvatar(backgroundColor: const Color(0xFFD4AF37).withOpacity(0.15), child: Text(b.name[0].toUpperCase(), style: const TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold))), title: Text(b.name, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)), subtitle: Text('Comisión ${b.commissionValue}%', style: const TextStyle(color: Colors.white54, fontSize: 11)), onTap: (){setState((){_selectedBarber=b;}); Navigator.pop(c);});}))]))); 
  }

  void _showClientSelector() {
    final search = TextEditingController();
    List<LocalClient> filtered = _clients;
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: const Color(0xFF141414), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (c) => StatefulBuilder(builder: (ctx,setModal){return DraggableScrollableSheet(initialChildSize: 0.7, minChildSize: 0.5, maxChildSize: 0.9, expand: false, builder: (ctx,sc)=>Column(children: [Container(padding: const EdgeInsets.all(16), decoration: const BoxDecoration(color: Color(0xFFD4AF37), borderRadius: BorderRadius.vertical(top: Radius.circular(20))), child: Row(children: const [Icon(Icons.person, color: Colors.white, size: 20), SizedBox(width: 8), Text('Seleccionar Cliente', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15))])), Padding(padding: const EdgeInsets.all(12), child: TextField(controller: search, style: const TextStyle(color: Colors.white, fontSize: 13), decoration: InputDecoration(hintText: 'Buscar cliente...', hintStyle: const TextStyle(color: Colors.white38, fontSize: 12), prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 18), filled: true, fillColor: const Color(0xFF0A0A0A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)), onChanged: (q){setModal((){filtered = _clients.where((cl)=> cl.name.toLowerCase().contains(q.toLowerCase()) || (cl.phone??'').contains(q)).toList();});})), Expanded(child: ListView.builder(controller: sc, itemCount: filtered.length, itemBuilder: (ctx,i){final cl=filtered[i]; return ListTile(leading: CircleAvatar(backgroundColor: const Color(0xFFD4AF37).withOpacity(0.15), child: Text(cl.name[0].toUpperCase(), style: const TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold, fontSize: 12))), title: Text(cl.name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)), subtitle: Text(cl.phone??'', style: const TextStyle(color: Colors.white54, fontSize: 11)), onTap: (){setState((){_selectedClient=cl;}); Navigator.pop(c);});})), Padding(padding: const EdgeInsets.all(12), child: SizedBox(width: double.infinity, child: OutlinedButton(onPressed: (){setState((){_selectedClient=null;}); Navigator.pop(c);}, child: const Text('Sin cliente', style: TextStyle(color: Colors.white70, fontSize: 12)))))]));}));
  }

  void _showAppointmentSelector() {
    showModalBottomSheet(context: context, backgroundColor: const Color(0xFF141414), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (c) => Column(mainAxisSize: MainAxisSize.min, children: [
      Container(padding: const EdgeInsets.all(16), decoration: const BoxDecoration(color: Color(0xFFD4AF37), borderRadius: BorderRadius.vertical(top: Radius.circular(20))), child: Row(children: const [Icon(Icons.calendar_month, color: Colors.white, size: 20), SizedBox(width: 8), Text('Citas de Hoy', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15))])),
      _todayAppointments.isEmpty ? const Padding(padding: EdgeInsets.all(24), child: Text('No hay citas pendientes hoy', style: TextStyle(color: Colors.white54, fontSize: 13))) : ListView.builder(shrinkWrap: true, itemCount: _todayAppointments.length, itemBuilder: (ctx,i){
        final ap=_todayAppointments[i];
        final timeStr = DateFormat('HH:mm').format(ap.appointmentDate);
        return ListTile(
          title: Text(ap.clientName??'Cliente', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          subtitle: Text('${ap.serviceName??''} - $timeStr', style: const TextStyle(color: Colors.white54, fontSize: 11)),
          onTap: (){
            setState((){
              _selectedAppointment=ap;
              _selectedClient=_clients.firstWhere((cl)=>cl.remoteId==ap.clientId, orElse: ()=> LocalClient()..name=ap.clientName??''..phone=ap.clientPhone??'');
            });
            Navigator.pop(c);
          }
        );
      })
    ]));
  }

  void _updateQuantity(int index, int qty) {
    setState(() {
      if (qty <= 0) {
        _cart.removeAt(index);
      } else {
        final item = _cart[index];
        final oldQty = item.quantity;
        if (item.type == 'service') {
      // FIX CANTIDAD CORREGIDO: en el carrito commissionEarned YA esta POR UNIDAD (6.000 para un corte de 12.000).
      // No dividir por oldQty, porque si estaba en 2x y lo bajas a 3x, dividirlo lo deja en 3.000 y paga la mitad.
      // Se deja tal cual, Comisiones / Reportes ya hacen la correccion al total con la logica hibrida.
    }
        item.quantity = qty;
      }
    });
  }

  Future<void> _processPayment() async {
    // NEGACION VENDER: Si Patricio quita Vender en Roles, NO puede cobrar aunque aprete el boton
    if (!RolePermissions.can(_myRole ?? currentUserRole, BbsPerm.sell)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⛔ No tienes permiso para vender.'), backgroundColor: Colors.redAccent));
      return;
    }
    if(_cart.isEmpty) return;
    if(_paymentMethod=='mixed'){
      final result = await _showMixedDialog();
      if(result==null) return;
      _mixedPayments = result;
      await _completeTransaction(cashReceived: _total, change: 0, mixedPayments: List.from(_mixedPayments));
      return;
    }
    String method = _paymentMethod;
    if(method=='cash'){
      final result = await _showCashDialog();
      if(result==null) return;
      await _completeTransaction(cashReceived: result['received']!, change: result['change']!);
    } else {
      await _completeTransaction(cashReceived: _total, change: 0);
    }
  }

  Future<List<Map<String, dynamic>>?> _showMixedDialog() async {
    List<Map<String, dynamic>> pagos = _mixedPayments.isNotEmpty ? List<Map<String, dynamic>>.from(_mixedPayments.map((e)=> Map<String, dynamic>.from(e))) : [
      {'method': 'cash', 'amount': (_total / 2).roundToDouble()},
      {'method': 'transfer', 'amount': _total - (_total / 2).roundToDouble()},
    ];
    if (_mixedPayments.isEmpty && pagos.length == 2) {
      pagos[1]['amount'] = _total - (pagos[0]['amount'] as double);
    }
    final List<TextEditingController> ctrls = pagos.map((p) => TextEditingController(text: (p['amount'] as num).toStringAsFixed(0))).toList();
    final List<FocusNode> focusNodes = List.generate(pagos.length, (_) => FocusNode());
    try {
    return await showDialog<List<Map<String, dynamic>>>(context: context, builder: (c) {
      return StatefulBuilder(builder: (ctx, setSt) {
        double sum = pagos.fold(0.0, (s, e) => s + ((e['amount'] as num).toDouble()));
        double diff = _total - sum;
        bool cuadra = pagos.length >= 2 && diff.abs() < 0.5;
        return Dialog(
          backgroundColor: const Color(0xFF141414),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(18),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Cobrar - ${SettingsService.formatCurrency(_total)}', style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text('Subtotal ${SettingsService.formatCurrency(_subtotal)}  Total ${SettingsService.formatCurrency(_total)}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                const SizedBox(height: 14),
                Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12), decoration: BoxDecoration(color: const Color(0xFF0A0A0A), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.5))), child: Row(children: const [Text('Mixto', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)), Spacer(), Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white54, size: 18)])),
                const SizedBox(height: 12),
                Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF0A0A0A), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Pago Mixto - Elige 2 o más formas', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  ...List.generate(pagos.length, (i) {
                    final p = pagos[i];
                    final ctrl = ctrls[i];
                    final focusNode = focusNodes[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        Expanded(
                          flex: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(color: const Color(0xFF141414), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white10)),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: p['method'] as String,
                                dropdownColor: const Color(0xFF141414),
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                                isExpanded: true,
                                items: const [
                                  DropdownMenuItem(value: 'cash', child: Text('Efectivo')),
                                  DropdownMenuItem(value: 'card', child: Text('Tarjeta')),
                                  DropdownMenuItem(value: 'transfer', child: Text('Transferencia')),
                                ],
                                onChanged: (v) { setSt(() => pagos[i]['method'] = v!); },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: ctrl,
                            focusNode: focusNode,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xFF141414),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            ),
                            onTap: () {
                              ctrl.selection = TextSelection(baseOffset: 0, extentOffset: ctrl.text.length);
                            },
                            onChanged: (v) {
                              pagos[i]['amount'] = double.tryParse(v) ?? 0;
                              setSt(() {});
                            },
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(onTap: (){ if(pagos.length>1) setSt((){ ctrls[i].dispose(); focusNodes[i].dispose(); ctrls.removeAt(i); focusNodes.removeAt(i); pagos.removeAt(i); }); }, child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.red.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.close, size: 14, color: Colors.redAccent))),
                      ]),
                    );
                  }),
                  const SizedBox(height: 4),
                  SizedBox(width: double.infinity, child: OutlinedButton(onPressed: (){ setSt((){ pagos.add({'method': 'cash', 'amount': 0.0}); ctrls.add(TextEditingController(text: '0')); focusNodes.add(FocusNode()); }); }, style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text('+ Agregar otro pago', style: TextStyle(color: Colors.white70, fontSize: 12)))),
                  const SizedBox(height: 10),
                  Center(child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: cuadra ? const Color(0xFFD4AF37).withOpacity(0.15) : Colors.red.withOpacity(0.15), borderRadius: BorderRadius.circular(20)), child: Text(cuadra ? '✓ Cuadra ${SettingsService.formatCurrency(_total)}' : (diff > 0 ? 'Falta ${SettingsService.formatCurrency(diff)}' : 'Sobra ${SettingsService.formatCurrency(diff.abs())}'), style: TextStyle(color: cuadra ? const Color(0xFFD4AF37) : Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)))),
                ])),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: SizedBox(height: 44, child: ElevatedButton(onPressed: cuadra ? ()=> Navigator.pop(c, pagos) : null, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37), foregroundColor: Colors.black, disabledBackgroundColor: Colors.white10, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: Text('Confirmar Mixto\n${SettingsService.formatCurrency(_total)}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white))))),
                  const SizedBox(width: 10),
                  Expanded(child: SizedBox(height: 44, child: ElevatedButton(onPressed: ()=> Navigator.pop(c), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E1E1E), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text('Cancelar', style: TextStyle(fontSize: 12, color: Colors.white))))),
                ]),
              ]),
            ),
          ),
        );
      });
    });
    } finally {
      for (final cc in ctrls) { try { cc.dispose(); } catch (_) {} }
      for (final ff in focusNodes) { try { ff.dispose(); } catch (_) {} }
    }
  }

  Widget _buildPaymentMethodSelector({VoidCallback? onChanged}) {
    Widget btn(String value, IconData icon, String label) {
      final selected = _paymentMethod == value;
      return Expanded(child: InkWell(onTap: (){ setState(()=> _paymentMethod = value); if(value=='mixed'){ _mixedPayments = []; } onChanged?.call(); }, child: Container(padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: selected ? const Color(0xFFD4AF37) : const Color(0xFF0A0A0A), borderRadius: BorderRadius.circular(10), border: Border.all(color: selected ? const Color(0xFFFBBF24) : Colors.white10)), child: Column(children: [Icon(icon, size: 18, color: selected ? Colors.white : Colors.white70), const SizedBox(height: 3), Text(label, style: TextStyle(color: selected ? Colors.white : Colors.white70, fontSize: 10, fontWeight: selected ? FontWeight.bold : FontWeight.w500))]))));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Forma de pago', style: TextStyle(color: Colors.white54, fontSize: 11)),
      const SizedBox(height: 8),
      Row(children: [btn('cash', Icons.money, 'Efectivo'), const SizedBox(width: 6), btn('card', Icons.credit_card, 'Tarjeta'), const SizedBox(width: 6), btn('transfer', Icons.swap_horiz, 'Transfer'), const SizedBox(width: 6), btn('mixed', Icons.call_split, 'Mixto')]),
      if(_paymentMethod=='mixed' && _mixedPayments.isNotEmpty) ...[const SizedBox(height: 8), Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), decoration: BoxDecoration(color: const Color(0xFFD4AF37).withOpacity(0.12), borderRadius: BorderRadius.circular(8)), child: Text('Mixto: ${_mixedPayments.map((e)=> '${_labelForMethod(e['method'] as String)} ${SettingsService.formatCurrency((e['amount'] as num).toDouble())}').join(' + ')}', style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 10, fontWeight: FontWeight.w600)))],
    ]);
  }

  Future<Map<String,double>?> _showCashDialog() async {
    final ctrl = TextEditingController();
    double change = 0;
    return showDialog<Map<String,double>>(context: context, builder: (c){
      return StatefulBuilder(builder: (ctx,setSt){
        void calc(){ final rec = double.tryParse(ctrl.text)??0; setSt(()=> change = rec - _total); }
        return AlertDialog(backgroundColor: const Color(0xFF141414), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), title: Row(children: const [Icon(Icons.money, color: Colors.white, size: 20), SizedBox(width: 8), Text('Pago en Efectivo', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold))]), content: Column(mainAxisSize: MainAxisSize.min, children: [Container(width: double.infinity, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFF0A0A0A), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)), child: Column(children: [const Text('Total a pagar', style: TextStyle(color: Colors.white54, fontSize: 11)), Text(SettingsService.formatCurrency(_total), style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 22, fontWeight: FontWeight.bold))])), const SizedBox(height: 12), TextField(controller: ctrl, autofocus: true, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Monto recibido', labelStyle: const TextStyle(color: Colors.white54, fontSize: 12), prefixText: '${SettingsService.currencySymbol} ', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 2))), onChanged: (_)=>calc()), const SizedBox(height: 10), Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: change>=0 ? const Color(0xFFD4AF37).withOpacity(0.15) : Colors.red.withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(change>=0 ? 'Vuelto:' : 'Falta:', style: TextStyle(color: change>=0 ? const Color(0xFFD4AF37) : Colors.redAccent, fontSize: 12)), Text(SettingsService.formatCurrency(change.abs()), style: TextStyle(color: change>=0 ? const Color(0xFFD4AF37) : Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold))]))]), actions: [TextButton(onPressed: ()=>Navigator.pop(c), child: const Text('Cancelar', style: TextStyle(color: Colors.grey, fontSize: 12))), ElevatedButton(onPressed: (){ final rec = double.tryParse(ctrl.text)??0; if(rec < _total){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Faltan ${SettingsService.formatCurrency(_total-rec)}'), backgroundColor: Colors.red)); return;} Navigator.pop(c, {'received': rec, 'change': rec-_total}); }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37)), child: const Text('Confirmar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)))]); 
      });
    });
  }

  Future<void> _completeTransaction({required double cashReceived, required double change, List<Map<String, dynamic>>? mixedPayments}) async {
    try {
      final sess = Supabase.instance.client.auth.currentSession;
      final ahora = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      if (sess == null || sess.expiresAt == null || ahora > (sess.expiresAt! - 60)) {
        await Supabase.instance.client.auth.refreshSession();
      }
    } catch (_) {}
    if (_miCaja == 'Sin Caja' || _miCaja == 'Cargando caja...' || _miCajaId.isEmpty) {
      await _cargarMiCaja();
      if (_miCaja == 'Sin Caja' || _miCajaId.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ Este usuario no tiene caja asignada (ej: Usuario de Pruebas). Entra con BRAYAN, ALEX, MATY o PATRICIO para vender. Todos venden a la misma Caja 1.'), backgroundColor: Colors.orange, duration: Duration(seconds: 5)));
        return;
      }
    }
    final _authUser = Supabase.instance.client.auth.currentUser;
    // FIX: sin fallback a user-001 / Recepcion - si no hay sesion, no se inventa un cajero
    if (_authUser == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ Sesion expirada. Vuelve a entrar para vender.'), backgroundColor: Colors.redAccent));
      return;
    }
    final realCashierId = _authUser.id;
    final realCashierName = currentUserName.isNotEmpty ? currentUserName : (_authUser.email?.split('@').first ?? 'Sin nombre');
    int folioUsado = 0;
    String folioStr = '';
    try {
      folioUsado = await TicketConfigService.useNextFolio();
      folioStr = folioUsado.toString();
      if (_proximoFolioNum > 0 && folioUsado < _proximoFolioNum) {
        folioUsado = _proximoFolioNum;
        folioStr = folioUsado.toString();
        try { await TicketConfigService.save({'folio_actual': folioUsado + 1, 'folioActual': folioUsado + 1}); } catch (_) {}
      }
    } catch (e) {
      if (_proximoFolioNum > 0) { folioUsado = _proximoFolioNum; folioStr = folioUsado.toString(); }
      else { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error folio: $e'), backgroundColor: Colors.red)); return; }
    }
    final transaction = LocalTransaction()
      ..remoteId='trans-${DateTime.now().millisecondsSinceEpoch}'
      ..cashRegisterId=_miCajaId
      ..cashierId=realCashierId
      ..cashierName=realCashierName
      ..subtotal=_subtotal
      ..total=_total
      ..paymentMethod=_paymentMethod
      ..cashReceived=cashReceived
      ..changeAmount=change
      ..items=List.from(_cart);
    try {
      try { transaction.folio = folioStr; } catch (_) {}
      // FIX: si es venta solo de productos, barbero queda vacio (Sin asignar en ticket), no primer barbero ni Recepcion.
      // Si hay servicios, _selectedBarber ya es obligatorio por _addServiceToCart, asi que este fallback casi nunca se usa.
      final _firstServiceBarber = transaction.items.firstWhere((e) => e.type == 'service' && e.barberName.isNotEmpty, orElse: () => LocalTransactionItem());
      final effectiveBarberHeader = _selectedBarber ?? ((_firstServiceBarber.barberName.isNotEmpty) ? (LocalBarber()..remoteId = _firstServiceBarber.barberId..name = _firstServiceBarber.barberName) : (LocalBarber()..name = ''));
      final transResponse = await Supabase.instance.client.from('transactions').insert({'id': transaction.remoteId, 'folio': folioStr, 'cash_register_id': transaction.cashRegisterId, 'cashier_id': transaction.cashierId, 'cashier_name': transaction.cashierName, 'barber_id': effectiveBarberHeader.remoteId ?? '', 'barber_name': effectiveBarberHeader.name, 'client_name': (_selectedClient?.name.trim().isEmpty ?? true) ? 'Consumidor Final' : _selectedClient!.name.trim(), 'subtotal': transaction.subtotal, 'total': transaction.total, 'payment_method': transaction.paymentMethod, 'cash_received': cashReceived, 'change_amount': change, 'status': 'completed', 'created_at': DateTime.now().toIso8601String()}).select().single();
      final transactionId = transResponse['id'] as String;
      final itemsData = transaction.items.map((item)=>{'transaction_id': transactionId, 'item_type': item.type, 'service_id': item.type=='service'?item.serviceId:null, 'service_name': item.type=='service'?item.serviceName:null, 'product_id': item.type=='product'?item.productId:null, 'product_name': item.type=='product'?item.productName:null, 'barber_id': item.barberId.isNotEmpty?item.barberId:null, 'barber_name': item.barberName.isNotEmpty?item.barberName:null, 'price_at_moment': item.priceAtMoment, 'quantity': item.quantity, 'commission_earned': item.commissionEarned}).toList();
      await Supabase.instance.client.from('transaction_items').insert(itemsData);
      for(final item in transaction.items){
        if(item.type=='product'){
          final pid = item.productId;
          if(pid!=null && pid.isNotEmpty){
            try{
              final prodResp = await Supabase.instance.client.from('products').select('stock').eq('id', pid).single();
              final cur = (prodResp['stock'] as num).toInt();
              final newStock = cur - item.quantity;
              await Supabase.instance.client.from('products').update({'stock': newStock}).eq('id', pid);
            }catch(_){}
          }
        }
      }
      if(mixedPayments!=null && mixedPayments.isNotEmpty){
        try{
          for(final p in mixedPayments){
            await Supabase.instance.client.from('transaction_payments').insert({'transaction_id': transactionId, 'payment_method': p['method'], 'amount': p['amount']});
          }
        }catch(_){}
      }
      try {
        final barberName = _selectedBarber?.name ?? (transaction.items.isNotEmpty ? transaction.items.first.barberName : '');
        final clientName = _selectedClient?.name ?? 'Consumidor Final';
        final data = EastonTicketData(
          shopName: SettingsService.shopName.isNotEmpty ? SettingsService.shopName : 'BBS CLUB BARBERIA',
          shopRif: SettingsService.shopRif,
          shopAddress: SettingsService.shopAddress,
          shopPhone: SettingsService.shopPhone,
          folio: folioStr,
          date: DateTime.now(),
          clientName: clientName,
          cashierName: realCashierName,
          cashRegister: _miCaja,
          barberName: barberName.isEmpty ? 'Sin asignar' : barberName,
          items: transaction.items.map((it) => EastonTicketItem(
            name: it.serviceName.isNotEmpty ? it.serviceName : (it.productName ?? 'Item'),
            qty: it.quantity,
            price: it.priceAtMoment,
          )).toList(),
          subtotal: _subtotal,
          discount: _discount,
          total: _total,
          paymentLabel: _labelForMethod(_paymentMethod),
          cashReceived: cashReceived,
          change: change,
          mixedPayments: mixedPayments,
          footer: SettingsService.ticketFooter.isNotEmpty ? SettingsService.ticketFooter : '¡Gracias por su visita!',
          isReprint: false,
          logoUrl: SettingsService.ticketLogoUrl.isNotEmpty ? SettingsService.ticketLogoUrl : SettingsService.shopLogoUrl,
        );
        final bytes = await EastonTicket.build(data: data);
        await Printing.sharePdf(bytes: bytes, filename: 'Ticket_$folioStr');
      } catch (e) {
        debugPrint('Error ticket Easton: $e');
        try { await _printer.printTicket(transaction); } catch (_) {}
      }
      if(mounted){ setState((){ _cart.clear(); _selectedClient=null; _selectedAppointment=null; _discount=0; _mixedPayments.clear(); }); _snack('✅ Venta registrada - Folio $folioStr'); await _loadData(); }
    }catch(e){ if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red)); }
  }

  // --- COLORES DORADOS Y ROJOS APLICADOS AQUI ---
  Widget _buildServiceCard(LocalService s) {
    final price = SettingsService.formatCurrency(s.price);
    final goldColor = const Color(0xFFFBBF24);
    return InkWell(onTap: ()=>_addServiceToCart(s), child: Container(decoration: BoxDecoration(color: const Color(0xFF141414), borderRadius: BorderRadius.circular(16), border: Border.all(color: goldColor.withOpacity(0.2)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0,3))]), child: Padding(padding: const EdgeInsets.all(10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: goldColor.withOpacity(0.15), shape: BoxShape.circle), child: Icon(Icons.content_cut_rounded, size: 16, color: goldColor)), const Spacer(), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: goldColor.withOpacity(0.15), borderRadius: BorderRadius.circular(20)), child: Text(price, style: TextStyle(color: goldColor, fontSize: 11, fontWeight: FontWeight.bold)))]),
      const SizedBox(height: 8),
      Flexible(child: Text(s.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, height: 1.05))),
      const SizedBox(height: 3),
      Text('${s.durationMinutes} min • ${s.commissionValue.toStringAsFixed(0)}%', style: const TextStyle(color: Colors.white38, fontSize: 10)),
    ]))));
  }

  Widget _buildProductCard(LocalProduct p) {
    final price = SettingsService.formatCurrency(p.price);
    final isLow = p.stock <= p.minStock;
    final redColor = const Color(0xFFEF4444);
    return InkWell(onTap: ()=>_addProductToCart(p), child: Container(decoration: BoxDecoration(color: const Color(0xFF141414), borderRadius: BorderRadius.circular(16), border: Border.all(color: isLow ? redColor : redColor.withOpacity(0.2))), child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: redColor.withOpacity(0.15), shape: BoxShape.circle), child: Icon(Icons.inventory_2_rounded, size: 16, color: redColor)), const Spacer(), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: redColor.withOpacity(0.15), borderRadius: BorderRadius.circular(20)), child: Text(price, style: TextStyle(color: redColor, fontSize: 11, fontWeight: FontWeight.bold)))]),
      const SizedBox(height: 8),
      Flexible(child: Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, height: 1.05))),
      const SizedBox(height: 4),
      Text('Stock: ${p.stock}', style: TextStyle(color: isLow ? redColor : Colors.white38, fontSize: 10, fontWeight: FontWeight.w600)),
    ]))));
  }

  Widget _buildDesktopCart() {
    return Container(width: 360, decoration: const BoxDecoration(color: Color(0xFF141414), border: Border(left: BorderSide(color: Colors.white10))), child: Column(children: [
      Container(padding: const EdgeInsets.all(14), decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF1E1E1E), Color(0xFF141414)]), border: Border(bottom: BorderSide(color: Colors.white10))), child: Row(children: [const Icon(Icons.shopping_cart, color: Colors.white, size: 20), const SizedBox(width: 8), Text('Carrito (${_cart.length})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)), const SizedBox(width: 6), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFD4AF37).withOpacity(0.2), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFD4AF37))), child: Text('Folio $_proximoFolio', style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 11, fontWeight: FontWeight.bold))), const Spacer(), if(_cart.isNotEmpty) InkWell(onTap: ()=>setState(()=>_cart.clear()), child: const Text('Vaciar', style: TextStyle(color: Colors.redAccent, fontSize: 11)))])),
      Expanded(child: _cart.isEmpty ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.shopping_cart_outlined, size: 48, color: Colors.white24), SizedBox(height: 12), Text('Carrito vacio', style: TextStyle(color: Colors.white54, fontSize: 13))])) : ListView.builder(padding: const EdgeInsets.all(10), itemCount: _cart.length, itemBuilder: (c,i){ final it=_cart[i]; return Container(margin: const EdgeInsets.only(bottom: 8), decoration: BoxDecoration(color: const Color(0xFF0A0A0A), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)), child: ListTile(dense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), title: Text(it.serviceName.isNotEmpty?it.serviceName:it.productName??'', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis), subtitle: Text('${SettingsService.formatCurrency(it.priceAtMoment)} x ${it.quantity}', style: const TextStyle(color: Colors.white54, fontSize: 10)), trailing: Row(mainAxisSize: MainAxisSize.min, children: [IconButton(icon: const Icon(Icons.remove_circle_outline, size: 18, color: Colors.white54), onPressed: ()=>_updateQuantity(i, it.quantity-1), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 28, minHeight: 28)), Text('${it.quantity}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)), IconButton(icon: const Icon(Icons.add_circle_outline, size: 18, color: Color(0xFFD4AF37)), onPressed: ()=>_updateQuantity(i, it.quantity+1), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 28, minHeight: 28))]))); })),
      Container(padding: const EdgeInsets.all(14), decoration: const BoxDecoration(color: Color(0xFF0A0A0A), border: Border(top: BorderSide(color: Colors.white10))), child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Subtotal:', style: TextStyle(color: Colors.white54, fontSize: 12)), Text(SettingsService.formatCurrency(_subtotal), style: const TextStyle(color: Colors.white, fontSize: 12))]),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('TOTAL:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)), Text(SettingsService.formatCurrency(_total), style: const TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold, fontSize: 20))]),
        const SizedBox(height: 12),
        _buildOptionButton(icon: Icons.calendar_month, label: _selectedAppointment?.clientName ?? 'Cita (opcional)', onTap: _showAppointmentSelector),
        const SizedBox(height: 8),
        _buildOptionButton(icon: Icons.person, label: _selectedClient?.name ?? 'Cliente (opcional)', onTap: _showClientSelector),
        const SizedBox(height: 8),
        _buildPaymentMethodSelector(),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, height: 48, child: ElevatedButton(onPressed: (_cart.isEmpty || !RolePermissions.can(_myRole ?? currentUserRole, BbsPerm.sell))?null:_processPayment, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37), foregroundColor: Colors.black, disabledBackgroundColor: Colors.white10, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text(!RolePermissions.can(_myRole ?? currentUserRole, BbsPerm.sell) ? 'SIN PERMISO PARA VENDER' : _cart.isEmpty ? 'COBRAR' : 'COBRAR ${SettingsService.formatCurrency(_total)}${_paymentMethod=='mixed' ? ' - MIXED' : _paymentMethod=='cash' ? ' - CASH' : ''}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white))))
      ]))
    ]));
  }

  Widget _buildOptionButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(onTap: onTap, child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), decoration: BoxDecoration(color: const Color(0xFF0A0A0A), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white10)), child: Row(children: [Icon(icon, size: 16, color: Colors.white70), const SizedBox(width: 8), Expanded(child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)), const Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 16)])));
  }

  Widget _buildMobileBottomBar() {
    // Banner si no tiene permiso para vender
    if (!RolePermissions.can(_myRole ?? currentUserRole, BbsPerm.sell)) {
      return Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.red.withOpacity(0.12), border: Border(top: BorderSide(color: Colors.red.withOpacity(0.4)))), child: Row(children: const [Icon(Icons.block_rounded, color: Colors.redAccent, size: 20), SizedBox(width: 8), Expanded(child: Text('Solo lectura no puedes cobrar.', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)))]));
    }
    return Container(padding: const EdgeInsets.fromLTRB(12,10,12,12), decoration: BoxDecoration(color: const Color(0xFF141414), border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 12, offset: const Offset(0,-4))]), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Subtotal: ${SettingsService.formatCurrency(_subtotal)}', style: const TextStyle(color: Colors.white54, fontSize: 11)), Text(SettingsService.formatCurrency(_total), style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 2), Text('Folio $_proximoFolio  •  ${_miCaja}', style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold))])), const SizedBox(width: 10), Expanded(child: OutlinedButton.icon(onPressed: ()=>_showCartModal(), icon: const Icon(Icons.shopping_cart, size: 16), label: Text('Carrito (${_cart.length})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white24), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))))]),
      const SizedBox(height: 8),
      Row(children: [Expanded(child: _buildOptionButton(icon: Icons.calendar_month, label: _selectedAppointment?.clientName ?? 'Cita', onTap: _showAppointmentSelector)), const SizedBox(width: 8), Expanded(child: _buildOptionButton(icon: Icons.person, label: _selectedClient?.name ?? 'Cliente', onTap: _showClientSelector))]),
      const SizedBox(height: 8),
      SizedBox(width: double.infinity, height: 48, child: ElevatedButton(onPressed: (_cart.isEmpty || !RolePermissions.can(_myRole ?? currentUserRole, BbsPerm.sell))?null:_processPayment, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37), foregroundColor: Colors.black, disabledBackgroundColor: Colors.white10, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text(!RolePermissions.can(_myRole ?? currentUserRole, BbsPerm.sell) ? 'SIN PERMISO PARA VENDER' : _cart.isEmpty ? 'CARRITO VACIO' : 'COBRAR ${SettingsService.formatCurrency(_total)}${_paymentMethod=='mixed' ? ' - MIXED' : _paymentMethod=='cash' ? ' - CASH' : ''}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white))))
    ]));
  }

  void _showCartModal() {
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: const Color(0xFF141414), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (c){
      return StatefulBuilder(builder: (ctx,setModal){
        return DraggableScrollableSheet(initialChildSize: 0.7, minChildSize: 0.5, maxChildSize: 0.9, expand: false, builder: (ctx,sc){
          return Column(children: [
            Container(padding: const EdgeInsets.all(16), decoration: const BoxDecoration(color: Color(0xFFD4AF37), borderRadius: BorderRadius.vertical(top: Radius.circular(20))), child: Row(children: [Text('Carrito (${_cart.length})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)), const Spacer(), if(_cart.isNotEmpty) TextButton(onPressed: (){ setState(()=>_cart.clear()); setModal((){}); }, child: const Text('Vaciar', style: TextStyle(color: Colors.white70, fontSize: 12)))])),
            Expanded(child: _cart.isEmpty ? const Center(child: Text('Carrito vacio', style: TextStyle(color: Colors.white54, fontSize: 13))) : ListView.builder(controller: sc, padding: const EdgeInsets.all(12), itemCount: _cart.length, itemBuilder: (ctx,i){ final it=_cart[i]; return Container(margin: const EdgeInsets.only(bottom: 8), decoration: BoxDecoration(color: const Color(0xFF0A0A0A), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)), child: ListTile(dense: true, title: Text(it.serviceName.isNotEmpty?it.serviceName:it.productName??'', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)), subtitle: Text('${SettingsService.formatCurrency(it.priceAtMoment)} x ${it.quantity} = ${SettingsService.formatCurrency(it.priceAtMoment*it.quantity)}', style: const TextStyle(color: Colors.white54, fontSize: 10)), trailing: Row(mainAxisSize: MainAxisSize.min, children: [IconButton(icon: const Icon(Icons.remove_circle_outline, size: 18, color: Colors.white54), onPressed: (){ setState(()=> _updateQuantity(i, it.quantity-1)); setModal((){}); }, padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 28, minHeight: 28)), Text('${it.quantity}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)), IconButton(icon: const Icon(Icons.add_circle_outline, size: 18, color: Color(0xFFD4AF37)), onPressed: (){ setState(()=> it.quantity++); setModal((){}); }, padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 28, minHeight: 28)), IconButton(icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent), onPressed: (){ setState(()=>_cart.removeAt(i)); setModal((){}); })]))); })),
            Container(padding: const EdgeInsets.all(16), decoration: const BoxDecoration(color: Color(0xFF0A0A0A), border: Border(top: BorderSide(color: Colors.white10))), child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Subtotal:', style: TextStyle(color: Colors.white54, fontSize: 12)), Text(SettingsService.formatCurrency(_subtotal), style: const TextStyle(color: Colors.white, fontSize: 12))]),
              const SizedBox(height: 6),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('TOTAL:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)), Text(SettingsService.formatCurrency(_total), style: const TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold, fontSize: 20))]),
              const SizedBox(height: 12),
              _buildPaymentMethodSelector(onChanged: (){ setModal((){}); }),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, height: 48, child: ElevatedButton(onPressed: (_cart.isEmpty || !RolePermissions.can(_myRole ?? currentUserRole, BbsPerm.sell))?null:(){ Navigator.pop(c); _processPayment(); }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37), foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text(!RolePermissions.can(_myRole ?? currentUserRole, BbsPerm.sell) ? 'SIN PERMISO PARA VENDER' : 'COBRAR ${SettingsService.formatCurrency(_total)}${_paymentMethod=='mixed' ? ' - MIXED' : _paymentMethod=='cash' ? ' - CASH' : ''}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white))))
            ]))
          ]);
        });
      });
    });
  }

  void _showMobileMenu() {
    showModalBottomSheet(
      context: context, 
      isScrollControlled: true, 
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), 
      backgroundColor: const Color(0xFF141414), 
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9, 
        minChildSize: 0.5, 
        maxChildSize: 0.95, 
        expand: false, 
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController, 
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(20), 
              decoration: const BoxDecoration(color: Color(0xFFD4AF37), borderRadius: BorderRadius.vertical(top: Radius.circular(20))), 
              child: Row(children: const [Icon(Icons.menu, color: Colors.white, size: 28), SizedBox(width: 12), Text('Menú', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white))])
            ),
            Column(children: [
              // FIX: El menú ahora obedece a los permisos reales de cada rol
              if (RolePermissions.can(_myRole ?? currentUserRole, BbsPerm.viewDashboard))
                _buildMenuItem(Icons.dashboard, 'Dashboard', () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => DashboardScreen())); }),
              if (RolePermissions.can(_myRole ?? currentUserRole, BbsPerm.viewAdvancedReports))
                _buildMenuItem(Icons.analytics, 'Reportes Avanzados', () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => AdvancedReportsScreen())); }),
              if (RolePermissions.can(_myRole ?? currentUserRole, BbsPerm.viewReports))
                _buildMenuItem(Icons.trending_up, 'Reporte Caja', () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => ReportsScreen())); }),   
              if (RolePermissions.can(_myRole ?? currentUserRole, BbsPerm.viewCommissions))
                _buildMenuItem(Icons.monetization_on, 'Comisiones', () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => CommissionsScreen())); }),
              if (RolePermissions.can(_myRole ?? currentUserRole, BbsPerm.viewAgenda))
                _buildMenuItem(Icons.calendar_month, 'Agenda', () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => AppointmentsScreen())); }),  
              if (RolePermissions.can(_myRole ?? currentUserRole, BbsPerm.viewHistory))
                _buildMenuItem(Icons.receipt_long, 'Historial', () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => SalesHistoryScreen())); }),
                const Divider(color: Colors.white10),
              if (RolePermissions.can(_myRole ?? currentUserRole, BbsPerm.viewBarbers))
                _buildMenuItem(Icons.cut, 'Barberos', () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => BarbersScreen())).then((_) => _loadData()); }),
              if (RolePermissions.can(_myRole ?? currentUserRole, BbsPerm.viewServices))
                _buildMenuItem(Icons.content_cut, 'Servicios', () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => ServicesScreen())).then((_) => _loadData()); }),
              if (RolePermissions.can(_myRole ?? currentUserRole, BbsPerm.viewProducts))
                _buildMenuItem(Icons.inventory_2, 'Productos', () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => ProductsScreen())).then((_) => _loadData()); }),
                const Divider(color: Colors.white10),                                
              if (RolePermissions.can(_myRole ?? currentUserRole, BbsPerm.viewClients))
                _buildMenuItem(Icons.person, 'Clientes', () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => ClientsScreen())).then((_) => _loadData()); }),
              if (RolePermissions.can(_myRole ?? currentUserRole, BbsPerm.viewUsers))
                _buildMenuItem(Icons.group, 'Usuarios', () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => users_screen.UsersScreen())); }),
              if (RolePermissions.can(_myRole ?? currentUserRole, BbsPerm.manageRoles))
                _buildMenuItem(Icons.security, 'Roles', () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => roles_screen.RolesScreen())); }),
              if (RolePermissions.can(_myRole ?? currentUserRole, BbsPerm.viewSettings))
                _buildMenuItem(Icons.settings, 'Configuración', () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => SettingsScreen())); }),
                const Divider(color: Colors.white10),
              _buildMenuItem(Icons.logout, 'Cerrar sesión', () { Navigator.pop(context); _handleLogout(); }, isLogout: true),
            ]),
            const SizedBox(height: 20),
          ])
        )
      )
    );
  }
  
  Widget _buildMenuItem(IconData icon, String text, VoidCallback onTap, {bool isLogout = false}) {
    return ListTile(leading: Icon(icon, color: isLogout ? Colors.redAccent : Colors.white, size: 20), title: Text(text, style: TextStyle(fontSize: 14, color: isLogout ? Colors.redAccent : Colors.white, fontWeight: FontWeight.w500)), onTap: onTap);
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(context: context, builder: (context) => AlertDialog(backgroundColor: const Color(0xFF141414), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), title: const Text('Cerrar sesión', style: TextStyle(color: Colors.white, fontSize: 14)), content: const Text('¿Seguro que deseas cerrar sesión?', style: TextStyle(color: Colors.white70, fontSize: 12)), actions: [TextButton(onPressed: ()=>Navigator.pop(context,false), child: const Text('Cancelar', style: TextStyle(color: Colors.grey, fontSize: 12))), ElevatedButton(onPressed: ()=>Navigator.pop(context,true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Cerrar', style: TextStyle(fontSize: 12))) ]));
    if(confirm==true){ await Supabase.instance.client.auth.signOut(); if(mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (c)=>LoginScreen())); }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141414),
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.menu_rounded, color: Colors.white), onPressed: _showMobileMenu),
        title: Row(children: [
          Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: const Color(0xFFD4AF37), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.storefront, color: Colors.white, size: 18)),
          const SizedBox(width: 8),
          Text(isMobile ? 'POS' : 'POS Premium', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red)),
          const SizedBox(width: 8),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: _miCaja == 'Sin Caja' ? Colors.red.withOpacity(0.2) : const Color(0xFFD4AF37).withOpacity(0.2), borderRadius: BorderRadius.circular(20), border: Border.all(color: _miCaja == 'Sin Caja' ? Colors.red : const Color(0xFFD4AF37))), child: Text('Caja: $_miCaja', style: TextStyle(color: _miCaja == 'Sin Caja' ? Colors.redAccent : const Color(0xFFD4AF37), fontSize: 11, fontWeight: FontWeight.bold))),
          if(!isMobile && _selectedBarber!=null) ...[
            const SizedBox(width: 10),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFD4AF37).withOpacity(0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3))), child: Text('Barbero: ${_selectedBarber!.name}', style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 11, fontWeight: FontWeight.bold))),
          ]
        ]),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Row(children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: const Color(0xFFD4AF37),
                child: Text(
                  currentUserName.isNotEmpty ? currentUserName.trim()[0].toUpperCase() : '?',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
              if (!isMobile) ...[
                const SizedBox(width: 7),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 130,
                      child: Text(
                        currentUserName.isNotEmpty ? currentUserName : 'Usuario',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      currentUserRole.toUpperCase() == 'ADMIN' ? 'ADMIN' : currentUserRole.toUpperCase() == 'BARBER_CASHIER' ? 'BARBERO/CAJERO' : currentUserRole.toUpperCase() == 'BARBER' ? 'BARBERO' : currentUserRole.toUpperCase() == 'CASHIER' ? 'CAJERO' : currentUserRole.toUpperCase(),
                      style: const TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ]),
          ),
          IconButton(icon: const Icon(Icons.person_rounded, color: Colors.white70), onPressed: _showBarberSelector),
        ],
        bottom: TabBar(controller: _tabController, indicatorColor: const Color(0xFFFBBF24), indicatorWeight: 3, labelColor: Colors.white, unselectedLabelColor: Colors.white54, labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), tabs: const [Tab(icon: Icon(Icons.content_cut_rounded, size: 16), text: 'Servicios'), Tab(icon: Icon(Icons.inventory_2_rounded, size: 16), text: 'Productos')]),
      ),
      body: isMobile
          ? Column(children: [
              Expanded(child: TabBarView(controller: _tabController, children: [
                _services.isEmpty ? const Center(child: Text('No hay servicios', style: TextStyle(color: Colors.white54, fontSize: 13))) : GridView.builder(padding: const EdgeInsets.all(10), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 1.02, crossAxisSpacing: 10, mainAxisSpacing: 10), itemCount: _services.length, itemBuilder: (c,i)=>_buildServiceCard(_services[i])),
                _products.isEmpty ? const Center(child: Text('No hay productos', style: TextStyle(color: Colors.white54, fontSize: 13))) : GridView.builder(padding: const EdgeInsets.all(10), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 1.02, crossAxisSpacing: 10, mainAxisSpacing: 10), itemCount: _products.length, itemBuilder: (c,i)=>_buildProductCard(_products[i])),
              ])),
              _buildMobileBottomBar(),
            ])
          : Row(children: [
              Expanded(child: Column(children: [
                Expanded(child: TabBarView(controller: _tabController, children: [
                  _services.isEmpty ? const Center(child: Text('No hay servicios', style: TextStyle(color: Colors.white54))) : GridView.builder(padding: const EdgeInsets.all(16), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 1.08, crossAxisSpacing: 12, mainAxisSpacing: 12), itemCount: _services.length, itemBuilder: (c,i)=>_buildServiceCard(_services[i])),
                  _products.isEmpty ? const Center(child: Text('No hay productos', style: TextStyle(color: Colors.white54))) : GridView.builder(padding: const EdgeInsets.all(16), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 1.08, crossAxisSpacing: 12, mainAxisSpacing: 12), itemCount: _products.length, itemBuilder: (c,i)=>_buildProductCard(_products[i])),
                ]))
              ])),
              _buildDesktopCart(),
            ]),
    );
  }
}