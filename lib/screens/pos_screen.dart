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
import '../services/settings_service.dart';
import '../services/ticket_config_service.dart';
import '../main.dart';
import 'clients_screen.dart';
import 'sales_history_screen.dart';
import 'reports_screen.dart';
import 'barbers_screen.dart';
import 'services_screen.dart';
import 'products_screen.dart';
import 'users_screen.dart' as users_screen; // FIX: con prefijo para que Text no choque con Flutter
import 'appointments_screen.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';
import 'settings_screen.dart';
import 'advanced_reports_screen.dart';
import 'commissions_screen.dart';
import 'roles_screen.dart' as roles_screen; // FIX: prefijo
import '../services/role_permissions.dart';

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
  String? _myRole; // rol del usuario logeado para permisos

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
    // Cargar rol y permisos (si no hay tabla, usa defaults)
    RolePermissions.loadFromSupabase().then((_) async {
      final r = await RolePermissions.currentRole();
      if (mounted) setState(() => _myRole = r ?? currentUserRole);
    });
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
    if (_selectedBarber == null) { _showBarberRequiredDialog(); return; }
    setState(() {
      final idx = _cart.indexWhere((e) => e.type == 'service' && e.serviceId == service.remoteId);
      if (idx >= 0) _cart[idx].quantity++;
      else _cart.add(LocalTransactionItem()..type='service'..serviceId=service.remoteId??''..serviceName=service.name..barberId=_selectedBarber!.remoteId??''..barberName=_selectedBarber!.name..priceAtMoment=service.price..quantity=1..commissionEarned=(service.price*service.commissionValue)/100);
    });
    _snack('✅ ${service.name} agregado');
  }

  void _addProductToCart(LocalProduct product) {
    setState(() {
      final idx = _cart.indexWhere((e) => e.type=='product' && e.productId==product.remoteId);
      if (idx>=0) _cart[idx].quantity++; else _cart.add(LocalTransactionItem()..type='product'..productId=product.remoteId??''..productName=product.name..priceAtMoment=product.price..quantity=1);
    });
    _snack('✅ ${product.name} agregado');
  }

  void _snack(String msg) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg, style: const TextStyle(fontSize: 13)), backgroundColor: const Color(0xFF10B981), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))); }

  void _showBarberRequiredDialog() {
    showDialog(context: context, builder: (c) => AlertDialog(backgroundColor: const Color(0xFF1E293B), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), title: const Text('💈 Selecciona un barbero', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)), content: const Text('Para agregar servicios debes seleccionar un barbero primero.', style: TextStyle(color: Colors.white70, fontSize: 13)), actions: [TextButton(onPressed: ()=>Navigator.pop(c), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))), ElevatedButton(onPressed: (){Navigator.pop(c); _showBarberSelector();}, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)), child: const Text('Seleccionar'))]));
  }

  void _showBarberSelector(){
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: const Color(0xFF1E293B), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (c) => DraggableScrollableSheet(initialChildSize: 0.6, minChildSize: 0.4, maxChildSize: 0.85, expand: false, builder: (ctx, sc) => Column(children: [Container(padding: const EdgeInsets.all(16), decoration: const BoxDecoration(color: Color(0xFF6366F1), borderRadius: BorderRadius.vertical(top: Radius.circular(20))), child: Row(children: const [Text('💈', style: TextStyle(fontSize: 20)), SizedBox(width: 8), Text('Seleccionar Barbero', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15))])), Expanded(child: ListView.builder(controller: sc, itemCount: _barbers.length, itemBuilder: (ctx,i){final b=_barbers[i]; return ListTile(leading: CircleAvatar(backgroundColor: const Color(0xFF6366F1).withOpacity(0.15), child: Text(b.name[0].toUpperCase(), style: const TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold))), title: Text(b.name, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)), subtitle: Text('Comisión ${b.commissionValue}%', style: const TextStyle(color: Colors.white54, fontSize: 11)), onTap: (){setState((){_selectedBarber=b;}); Navigator.pop(c);});}))])));
  }

  void _showClientSelector() {
    final search = TextEditingController();
    List<LocalClient> filtered = _clients;
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: const Color(0xFF1E293B), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (c) => StatefulBuilder(builder: (ctx,setModal){return DraggableScrollableSheet(initialChildSize: 0.7, minChildSize: 0.5, maxChildSize: 0.9, expand: false, builder: (ctx,sc)=>Column(children: [Container(padding: const EdgeInsets.all(16), decoration: const BoxDecoration(color: Color(0xFF6366F1), borderRadius: BorderRadius.vertical(top: Radius.circular(20))), child: Row(children: const [Text('👥', style: TextStyle(fontSize: 20)), SizedBox(width: 8), Text('Seleccionar Cliente', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15))])), Padding(padding: const EdgeInsets.all(12), child: TextField(controller: search, style: const TextStyle(color: Colors.white, fontSize: 13), decoration: InputDecoration(hintText: 'Buscar cliente...', hintStyle: const TextStyle(color: Colors.white38, fontSize: 12), prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 18), filled: true, fillColor: const Color(0xFF0F172A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)), onChanged: (q){setModal((){filtered = _clients.where((cl)=> cl.name.toLowerCase().contains(q.toLowerCase()) || (cl.phone??'').contains(q)).toList();});})), Expanded(child: ListView.builder(controller: sc, itemCount: filtered.length, itemBuilder: (ctx,i){final cl=filtered[i]; return ListTile(leading: CircleAvatar(backgroundColor: const Color(0xFF10B981).withOpacity(0.15), child: Text(cl.name[0].toUpperCase(), style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12))), title: Text(cl.name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)), subtitle: Text(cl.phone??'', style: const TextStyle(color: Colors.white54, fontSize: 11)), onTap: (){setState((){_selectedClient=cl;}); Navigator.pop(c);});})), Padding(padding: const EdgeInsets.all(12), child: SizedBox(width: double.infinity, child: OutlinedButton(onPressed: (){setState((){_selectedClient=null;}); Navigator.pop(c);}, child: const Text('Sin cliente', style: TextStyle(color: Colors.white70, fontSize: 12)))))]));}));
  }

  void _showAppointmentSelector() {
    showModalBottomSheet(context: context, backgroundColor: const Color(0xFF1E293B), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (c) => Column(mainAxisSize: MainAxisSize.min, children: [
      Container(padding: const EdgeInsets.all(16), decoration: const BoxDecoration(color: Color(0xFF6366F1), borderRadius: BorderRadius.vertical(top: Radius.circular(20))), child: Row(children: const [Text('📅', style: TextStyle(fontSize: 20)), SizedBox(width: 8), Text('Citas de Hoy', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15))])),
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

  void _updateQuantity(int index, int qty) { setState((){ if(qty<=0) _cart.removeAt(index); else _cart[index].quantity=qty; }); }

  Future<void> _processPayment() async {
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

  // ===== PAGO MIXTO - FIX FOCO: controladores FUERA del build, no se recrean por tecla =====
  Future<List<Map<String, dynamic>>?> _showMixedDialog() async {
    List<Map<String, dynamic>> pagos = _mixedPayments.isNotEmpty ? List<Map<String, dynamic>>.from(_mixedPayments.map((e)=> Map<String, dynamic>.from(e))) : [
      {'method': 'cash', 'amount': (_total / 2).roundToDouble()},
      {'method': 'transfer', 'amount': _total - (_total / 2).roundToDouble()},
    ];
    if (_mixedPayments.isEmpty && pagos.length == 2) {
      pagos[1]['amount'] = _total - (pagos[0]['amount'] as double);
    }
    // FIX FOCO: un controller + un FocusNode por fila, creados UNA vez fuera del StatefulBuilder.
    // Antes se hacia TextEditingController(text: ...) DENTRO de List.generate en cada setSt,
    // por eso al escribir "1" se recreaba el campo y se perdia el foco / cursor.
    final List<TextEditingController> ctrls = pagos.map((p) => TextEditingController(text: (p['amount'] as num).toStringAsFixed(0))).toList();
    final List<FocusNode> focusNodes = List.generate(pagos.length, (_) => FocusNode());
    try {
    return await showDialog<List<Map<String, dynamic>>>(context: context, builder: (c) {
      return StatefulBuilder(builder: (ctx, setSt) {
        double sum = pagos.fold(0.0, (s, e) => s + ((e['amount'] as num).toDouble()));
        double diff = _total - sum;
        bool cuadra = pagos.length >= 2 && diff.abs() < 0.5;
        return Dialog(
          backgroundColor: const Color(0xFF1E293B),
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
                Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12), decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.5))), child: Row(children: const [Text('Mixto', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)), Spacer(), Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white54, size: 18)])),
                const SizedBox(height: 12),
                Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                            decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white10)),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: p['method'] as String,
                                dropdownColor: const Color(0xFF1E293B),
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
                              fillColor: const Color(0xFF1E293B),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            ),
                            onTap: () {
                              // Al tocar, seleccionar todo para reemplazar 10000 por 10000 facil sin borrar digito a digito
                              ctrl.selection = TextSelection(baseOffset: 0, extentOffset: ctrl.text.length);
                            },
                            onChanged: (v) {
                              // Solo actualizar el monto, NO recrear controller. setSt solo redibuja el "Cuadra / Falta"
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
                  Center(child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: cuadra ? const Color(0xFF10B981).withOpacity(0.15) : Colors.red.withOpacity(0.15), borderRadius: BorderRadius.circular(20)), child: Text(cuadra ? '✓ Cuadra ${SettingsService.formatCurrency(_total)}' : (diff > 0 ? 'Falta ${SettingsService.formatCurrency(diff)}' : 'Sobra ${SettingsService.formatCurrency(diff.abs())}'), style: TextStyle(color: cuadra ? const Color(0xFF10B981) : Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)))),
                ])),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: SizedBox(height: 44, child: ElevatedButton(onPressed: cuadra ? ()=> Navigator.pop(c, pagos) : null, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), disabledBackgroundColor: Colors.white10, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: Text('Confirmar Mixto\n${SettingsService.formatCurrency(_total)}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white))))),
                  const SizedBox(width: 10),
                  Expanded(child: SizedBox(height: 44, child: ElevatedButton(onPressed: ()=> Navigator.pop(c), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF334155), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text('Cancelar', style: TextStyle(fontSize: 12, color: Colors.white))))),
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
    Widget btn(String value, String icon, String label) {
      final selected = _paymentMethod == value;
      return Expanded(child: InkWell(onTap: (){ setState(()=> _paymentMethod = value); if(value=='mixed'){ _mixedPayments = []; } onChanged?.call(); }, child: Container(padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: selected ? const Color(0xFF6366F1) : const Color(0xFF0F172A), borderRadius: BorderRadius.circular(10), border: Border.all(color: selected ? const Color(0xFF818CF8) : Colors.white10)), child: Column(children: [Text(icon, style: const TextStyle(fontSize: 15)), const SizedBox(height: 3), Text(label, style: TextStyle(color: selected ? Colors.white : Colors.white70, fontSize: 10, fontWeight: selected ? FontWeight.bold : FontWeight.w500))]))));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Forma de pago', style: TextStyle(color: Colors.white54, fontSize: 11)),
      const SizedBox(height: 8),
      Row(children: [btn('cash', '💵', 'Efectivo'), const SizedBox(width: 6), btn('card', '💳', 'Tarjeta'), const SizedBox(width: 6), btn('transfer', '🔁', 'Transfer'), const SizedBox(width: 6), btn('mixed', '🧾', 'Mixto')]),
      if(_paymentMethod=='mixed' && _mixedPayments.isNotEmpty) ...[const SizedBox(height: 8), Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.12), borderRadius: BorderRadius.circular(8)), child: Text('Mixto: ${_mixedPayments.map((e)=> '${_labelForMethod(e['method'] as String)} ${SettingsService.formatCurrency((e['amount'] as num).toDouble())}').join(' + ')}', style: const TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.w600)))],
    ]);
  }

  Future<Map<String,double>?> _showCashDialog() async {
    final ctrl = TextEditingController();
    double change = 0;
    return showDialog<Map<String,double>>(context: context, builder: (c){
      return StatefulBuilder(builder: (ctx,setSt){
        void calc(){ final rec = double.tryParse(ctrl.text)??0; setSt(()=> change = rec - _total); }
        return AlertDialog(backgroundColor: const Color(0xFF1E293B), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), title: const Text('💵 Pago en Efectivo', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)), content: Column(mainAxisSize: MainAxisSize.min, children: [Container(width: double.infinity, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)), child: Column(children: [const Text('Total a pagar', style: TextStyle(color: Colors.white54, fontSize: 11)), Text(SettingsService.formatCurrency(_total), style: const TextStyle(color: Color(0xFF818CF8), fontSize: 22, fontWeight: FontWeight.bold))])), const SizedBox(height: 12), TextField(controller: ctrl, autofocus: true, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Monto recibido', labelStyle: const TextStyle(color: Colors.white54, fontSize: 12), prefixText: '${SettingsService.currencySymbol} ', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF10B981), width: 2))), onChanged: (_)=>calc()), const SizedBox(height: 10), Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: change>=0 ? const Color(0xFF10B981).withOpacity(0.15) : Colors.red.withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(change>=0 ? 'Vuelto:' : 'Falta:', style: TextStyle(color: change>=0 ? const Color(0xFF10B981) : Colors.redAccent, fontSize: 12)), Text(SettingsService.formatCurrency(change.abs()), style: TextStyle(color: change>=0 ? const Color(0xFF10B981) : Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold))]))]), actions: [TextButton(onPressed: ()=>Navigator.pop(c), child: const Text('Cancelar', style: TextStyle(color: Colors.grey, fontSize: 12))), ElevatedButton(onPressed: (){ final rec = double.tryParse(ctrl.text)??0; if(rec < _total){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Faltan ${SettingsService.formatCurrency(_total-rec)}'), backgroundColor: Colors.red)); return;} Navigator.pop(c, {'received': rec, 'change': rec-_total}); }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)), child: const Text('Confirmar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)))]);
      });
    });
  }

  Future<void> _completeTransaction({required double cashReceived, required double change, List<Map<String, dynamic>>? mixedPayments}) async {
    final transaction = LocalTransaction()
      ..remoteId='trans-${DateTime.now().millisecondsSinceEpoch}'
      ..cashRegisterId='caja-001'
      ..cashierId='user-001'
      ..cashierName=currentUserName.isNotEmpty ? currentUserName : 'Recepcion'
      ..subtotal=_subtotal
      ..total=_total
      ..paymentMethod=_paymentMethod
      ..cashReceived=cashReceived
      ..changeAmount=change
      ..items=List.from(_cart);
    try{
      final transResponse = await Supabase.instance.client.from('transactions').insert({'id': transaction.remoteId, 'cash_register_id': transaction.cashRegisterId, 'cashier_id': transaction.cashierId, 'cashier_name': transaction.cashierName, 'barber_id': _selectedBarber?.remoteId??'', 'subtotal': transaction.subtotal, 'total': transaction.total, 'payment_method': transaction.paymentMethod, 'cash_received': cashReceived, 'change_amount': change, 'status': 'completed', 'created_at': DateTime.now().toIso8601String()}).select().single();
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
      await _printer.printTicket(transaction);
      if(mounted){ setState((){ _cart.clear(); _selectedClient=null; _selectedAppointment=null; _discount=0; _mixedPayments.clear(); }); _snack('✅ Venta registrada'); await _loadData(); }
    }catch(e){ if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red)); }
  }

  Widget _buildServiceCard(LocalService s) {
    final price = SettingsService.formatCurrency(s.price);
    return InkWell(onTap: ()=>_addServiceToCart(s), child: Container(decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.06)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0,3))]), child: Padding(padding: const EdgeInsets.all(10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.15), shape: BoxShape.circle), child: const Text('✂️', style: TextStyle(fontSize: 15))), const Spacer(), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.15), borderRadius: BorderRadius.circular(20)), child: Text(price, style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold)))]),
      const SizedBox(height: 8),
      Flexible(child: Text(s.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, height: 1.05))),
      const SizedBox(height: 3),
      Text('${s.durationMinutes} min • ${s.commissionValue.toStringAsFixed(0)}%', style: const TextStyle(color: Colors.white38, fontSize: 10)),
    ]))));
  }

  Widget _buildProductCard(LocalProduct p) {
    final price = SettingsService.formatCurrency(p.price);
    final isLow = p.stock <= p.minStock;
    return InkWell(onTap: ()=>_addProductToCart(p), child: Container(decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16), border: Border.all(color: isLow ? Colors.red.withOpacity(0.2) : Colors.white.withOpacity(0.06))), child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: isLow ? Colors.red.withOpacity(0.15) : const Color(0xFFF59E0B).withOpacity(0.15), shape: BoxShape.circle), child: const Text('📦', style: TextStyle(fontSize: 16))), const Spacer(), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.15), borderRadius: BorderRadius.circular(20)), child: Text(price, style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold)))]),
      const SizedBox(height: 8),
      Flexible(child: Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, height: 1.05))),
      const SizedBox(height: 4),
      Text('Stock: ${p.stock}', style: TextStyle(color: isLow ? Colors.redAccent : Colors.white38, fontSize: 10, fontWeight: FontWeight.w600)),
    ]))));
  }

  Widget _buildDesktopCart() {
    return Container(width: 360, decoration: const BoxDecoration(color: Color(0xFF1E293B), border: Border(left: BorderSide(color: Colors.white10))), child: Column(children: [
      Container(padding: const EdgeInsets.all(14), decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF312E81), Color(0xFF1E293B)]), border: Border(bottom: BorderSide(color: Colors.white10))), child: Row(children: [const Text('🛒', style: TextStyle(fontSize: 20)), const SizedBox(width: 8), Text('Carrito (${_cart.length})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)), const Spacer(), if(_cart.isNotEmpty) InkWell(onTap: ()=>setState(()=>_cart.clear()), child: const Text('Vaciar', style: TextStyle(color: Colors.redAccent, fontSize: 11)))])),
      Expanded(child: _cart.isEmpty ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('🛒', style: TextStyle(fontSize: 48)), SizedBox(height: 12), Text('Carrito vacio', style: TextStyle(color: Colors.white54, fontSize: 13))])) : ListView.builder(padding: const EdgeInsets.all(10), itemCount: _cart.length, itemBuilder: (c,i){ final it=_cart[i]; return Container(margin: const EdgeInsets.only(bottom: 8), decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)), child: ListTile(dense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), title: Text(it.serviceName.isNotEmpty?it.serviceName:it.productName??'', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis), subtitle: Text('${SettingsService.formatCurrency(it.priceAtMoment)} x ${it.quantity}', style: const TextStyle(color: Colors.white54, fontSize: 10)), trailing: Row(mainAxisSize: MainAxisSize.min, children: [IconButton(icon: const Text('➖', style: TextStyle(fontSize: 12)), onPressed: ()=>_updateQuantity(i, it.quantity-1), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 28, minHeight: 28)), Text('${it.quantity}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)), IconButton(icon: const Text('➕', style: TextStyle(fontSize: 12)), onPressed: ()=>_updateQuantity(i, it.quantity+1), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 28, minHeight: 28))]))); })),
      Container(padding: const EdgeInsets.all(14), decoration: const BoxDecoration(color: Color(0xFF0F172A), border: Border(top: BorderSide(color: Colors.white10))), child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Subtotal:', style: TextStyle(color: Colors.white54, fontSize: 12)), Text(SettingsService.formatCurrency(_subtotal), style: const TextStyle(color: Colors.white, fontSize: 12))]),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('TOTAL:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)), Text(SettingsService.formatCurrency(_total), style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 20))]),
        const SizedBox(height: 12),
        _buildOptionButton(icon: '📅', label: _selectedAppointment?.clientName ?? 'Cita (opcional)', onTap: _showAppointmentSelector),
        const SizedBox(height: 8),
        _buildOptionButton(icon: '👤', label: _selectedClient?.name ?? 'Cliente (opcional)', onTap: _showClientSelector),
        const SizedBox(height: 8),
        _buildPaymentMethodSelector(),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, height: 48, child: ElevatedButton(onPressed: (_cart.isEmpty || !RolePermissions.can(_myRole ?? currentUserRole, BbsPerm.sell)) ? null : _processPayment, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), disabledBackgroundColor: Colors.white10, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text(_cart.isEmpty ? 'COBRAR' : 'COBRAR ${SettingsService.formatCurrency(_total)}${_paymentMethod=='mixed' ? ' - MIXED' : _paymentMethod=='cash' ? ' - CASH' : ''}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white))))
      ]))
    ]));
  }

  Widget _buildOptionButton({required String icon, required String label, required VoidCallback onTap}) {
    return InkWell(onTap: onTap, child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white10)), child: Row(children: [Text(icon, style: const TextStyle(fontSize: 14)), const SizedBox(width: 8), Expanded(child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)), const Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 16)])));
  }

  Widget _buildMobileBottomBar() {
    return Container(padding: const EdgeInsets.fromLTRB(12,10,12,12), decoration: BoxDecoration(color: const Color(0xFF1E293B), border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 12, offset: const Offset(0,-4))]), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Subtotal: ${SettingsService.formatCurrency(_subtotal)}', style: const TextStyle(color: Colors.white54, fontSize: 11)), Text(SettingsService.formatCurrency(_total), style: const TextStyle(color: Color(0xFF10B981), fontSize: 18, fontWeight: FontWeight.bold))])), const SizedBox(width: 10), Expanded(child: OutlinedButton.icon(onPressed: ()=>_showCartModal(), icon: const Text('🛒', style: TextStyle(fontSize: 14)), label: Text('Carrito (${_cart.length})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white24), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))))]),
      const SizedBox(height: 8),
      Row(children: [Expanded(child: _buildOptionButton(icon: '📅', label: _selectedAppointment?.clientName ?? 'Cita', onTap: _showAppointmentSelector)), const SizedBox(width: 8), Expanded(child: _buildOptionButton(icon: '👤', label: _selectedClient?.name ?? 'Cliente', onTap: _showClientSelector))]),
      const SizedBox(height: 8),
      SizedBox(width: double.infinity, height: 48, child: ElevatedButton(onPressed: (_cart.isEmpty || !RolePermissions.can(_myRole ?? currentUserRole, BbsPerm.sell)) ? null : _processPayment, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), disabledBackgroundColor: Colors.white10, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text(_cart.isEmpty ? 'CARRITO VACIO' : 'COBRAR ${SettingsService.formatCurrency(_total)}${_paymentMethod=='mixed' ? ' - MIXED' : _paymentMethod=='cash' ? ' - CASH' : ''}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white))))
    ]));
  }

  void _showCartModal() {
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: const Color(0xFF1E293B), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (c){
      return StatefulBuilder(builder: (ctx,setModal){
        return DraggableScrollableSheet(initialChildSize: 0.7, minChildSize: 0.5, maxChildSize: 0.9, expand: false, builder: (ctx,sc){
          return Column(children: [
            Container(padding: const EdgeInsets.all(16), decoration: const BoxDecoration(color: Color(0xFF6366F1), borderRadius: BorderRadius.vertical(top: Radius.circular(20))), child: Row(children: [Text('Carrito (${_cart.length})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)), const Spacer(), if(_cart.isNotEmpty) TextButton(onPressed: (){ setState(()=>_cart.clear()); setModal((){}); }, child: const Text('Vaciar', style: TextStyle(color: Colors.white70, fontSize: 12)))])),
            Expanded(child: _cart.isEmpty ? const Center(child: Text('🛒 Carrito vacio', style: TextStyle(color: Colors.white54, fontSize: 13))) : ListView.builder(controller: sc, padding: const EdgeInsets.all(12), itemCount: _cart.length, itemBuilder: (ctx,i){ final it=_cart[i]; return Container(margin: const EdgeInsets.only(bottom: 8), decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)), child: ListTile(dense: true, title: Text(it.serviceName.isNotEmpty?it.serviceName:it.productName??'', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)), subtitle: Text('${SettingsService.formatCurrency(it.priceAtMoment)} x ${it.quantity} = ${SettingsService.formatCurrency(it.priceAtMoment*it.quantity)}', style: const TextStyle(color: Colors.white54, fontSize: 10)), trailing: Row(mainAxisSize: MainAxisSize.min, children: [IconButton(icon: const Text('➖', style: TextStyle(fontSize: 12)), onPressed: (){ setState(()=> _updateQuantity(i, it.quantity-1)); setModal((){}); }, padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 28, minHeight: 28)), Text('${it.quantity}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)), IconButton(icon: const Text('➕', style: TextStyle(fontSize: 12)), onPressed: (){ setState(()=> it.quantity++); setModal((){}); }, padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 28, minHeight: 28)), IconButton(icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent), onPressed: (){ setState(()=>_cart.removeAt(i)); setModal((){}); })]))); })),
            Container(padding: const EdgeInsets.all(16), decoration: const BoxDecoration(color: Color(0xFF0F172A), border: Border(top: BorderSide(color: Colors.white10))), child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Subtotal:', style: TextStyle(color: Colors.white54, fontSize: 12)), Text(SettingsService.formatCurrency(_subtotal), style: const TextStyle(color: Colors.white, fontSize: 12))]),
              const SizedBox(height: 6),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('TOTAL:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)), Text(SettingsService.formatCurrency(_total), style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 20))]),
              const SizedBox(height: 12),
              _buildPaymentMethodSelector(onChanged: (){ setModal((){}); }),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, height: 48, child: ElevatedButton(onPressed: _cart.isEmpty?null:(){ Navigator.pop(c); _processPayment(); }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text('COBRAR ${SettingsService.formatCurrency(_total)}${_paymentMethod=='mixed' ? ' - MIXED' : _paymentMethod=='cash' ? ' - CASH' : ''}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white))))
            ]))
          ]);
        });
      });
    });
  }

  void _showMobileMenu() {
    showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), backgroundColor: const Color(0xFF1E293B), builder: (context) => DraggableScrollableSheet(initialChildSize: 0.9, minChildSize: 0.5, maxChildSize: 0.95, expand: false, builder: (context, scrollController) => SingleChildScrollView(controller: scrollController, child: Column(children: [
      Container(padding: const EdgeInsets.all(20), decoration: const BoxDecoration(color: Color(0xFF6366F1), borderRadius: BorderRadius.vertical(top: Radius.circular(20))), child: Row(children: [const Text('☰', style: TextStyle(fontSize: 28, color: Colors.white)), const SizedBox(width: 12), Text('Menú  •  Rol: ${(_myRole ?? currentUserRole).toString()}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white))])),
      Column(children: [
        // Menú por permisos - no solo admin. Barbero no ve Usuarios/Roles/Config, Cajero ve cierre/historial pero no edita.
        if (RolePermissions.can(_myRole ?? currentUserRole, BbsPerm.viewReports))
          _buildMenuItem('📝', 'Reportes Avanzados', () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => AdvancedReportsScreen())); }),
        if (RolePermissions.can(_myRole ?? currentUserRole, BbsPerm.viewCommissions))
          _buildMenuItem('💰', 'Comisiones', () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => CommissionsScreen())); }),
        if (RolePermissions.isAdmin(_myRole ?? currentUserRole)) ...[
          _buildMenuItem('💈', 'Barberos', () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => BarbersScreen())).then((_) => _loadData()); }),
          _buildMenuItem('✂️', 'Servicios', () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => ServicesScreen())).then((_) => _loadData()); }),
          _buildMenuItem('📦', 'Productos', () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => ProductsScreen())).then((_) => _loadData()); }),
        ],
        if (RolePermissions.can(_myRole ?? currentUserRole, BbsPerm.viewUsers))
          _buildMenuItem('👥', 'Usuarios', () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => users_screen.UsersScreen())); }),
        // FIX: Roles siempre para Admin (isAdmin) aunque la tabla role_permissions esté incompleta. Antes solo can(manageRoles) lo ocultaba.
        if (RolePermissions.isAdmin(_myRole ?? currentUserRole) || RolePermissions.can(_myRole ?? currentUserRole, BbsPerm.manageRoles))
          _buildMenuItem('🛡️', 'Roles', () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => roles_screen.RolesScreen())); }),
        if (RolePermissions.can(_myRole ?? currentUserRole, BbsPerm.viewAgenda))
          _buildMenuItem('📅', 'Agenda', () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => AppointmentsScreen())); }),
        if (RolePermissions.can(_myRole ?? currentUserRole, BbsPerm.viewReports))
          _buildMenuItem('📊', 'Dashboard', () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => DashboardScreen())); }),
        if (RolePermissions.can(_myRole ?? currentUserRole, BbsPerm.viewReports))
          _buildMenuItem('📈', 'Reportes', () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => ReportsScreen())); }),
        if (RolePermissions.can(_myRole ?? currentUserRole, BbsPerm.viewHistory))
          _buildMenuItem('📜', 'Historial', () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => SalesHistoryScreen())); }),
        if (RolePermissions.can(_myRole ?? currentUserRole, BbsPerm.viewSettings))
          _buildMenuItem('⚙️', 'Configuración', () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => SettingsScreen())); }),
        if (RolePermissions.can(_myRole ?? currentUserRole, BbsPerm.viewClients))
          _buildMenuItem('🧑‍💼', 'Clientes (solo ver)', () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => ClientsScreen())).then((_) => _loadData()); }),
        const Divider(color: Colors.white10),
        _buildMenuItem('🚪', 'Cerrar sesión', () { Navigator.pop(context); _handleLogout(); }, isLogout: true),
      ]),
      const SizedBox(height: 20),
    ])))) ;
  }

  Widget _buildMenuItem(String icon, String text, VoidCallback onTap, {bool isLogout = false}) {
    return ListTile(leading: Text(icon, style: const TextStyle(fontSize: 20)), title: Text(text, style: TextStyle(fontSize: 14, color: isLogout ? Colors.redAccent : Colors.white, fontWeight: FontWeight.w500)), onTap: onTap);
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(context: context, builder: (context) => AlertDialog(backgroundColor: const Color(0xFF1E293B), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), title: const Text('Cerrar sesión', style: TextStyle(color: Colors.white, fontSize: 14)), content: const Text('¿Seguro que deseas cerrar sesión?', style: TextStyle(color: Colors.white70, fontSize: 12)), actions: [TextButton(onPressed: ()=>Navigator.pop(context,false), child: const Text('Cancelar', style: TextStyle(color: Colors.grey, fontSize: 12))), ElevatedButton(onPressed: ()=>Navigator.pop(context,true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Cerrar', style: TextStyle(fontSize: 12))) ]));
    if(confirm==true){ await Supabase.instance.client.auth.signOut(); if(mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (c)=>LoginScreen())); }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.menu_rounded, color: Colors.white), onPressed: _showMobileMenu),
        title: Row(children: [
          Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: const Color(0xFF6366F1), borderRadius: BorderRadius.circular(10)), child: const Text('💈', style: TextStyle(fontSize: 18))),
          const SizedBox(width: 8),
          const Text('POS Premium', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
          if(_selectedBarber!=null) ...[
            const SizedBox(width: 10),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3))), child: Text('✂️ ${_selectedBarber!.name}', style: const TextStyle(color: Color(0xFF818CF8), fontSize: 11, fontWeight: FontWeight.bold))),
          ]
        ]),
        actions: [
          if(isMobile) Stack(children: [IconButton(icon: const Icon(Icons.shopping_cart_rounded, color: Colors.white), onPressed: _showCartModal), if(_cart.isNotEmpty) Positioned(right: 6, top: 6, child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle), child: Text('${_cart.length}', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold))))]),
          IconButton(icon: const Icon(Icons.person_rounded, color: Colors.white70), onPressed: _showBarberSelector),
        ],
        bottom: TabBar(controller: _tabController, indicatorColor: const Color(0xFF6366F1), indicatorWeight: 3, labelColor: Colors.white, unselectedLabelColor: Colors.white54, labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), tabs: const [Tab(icon: Text('✂️', style: TextStyle(fontSize: 16)), text: 'Servicios'), Tab(icon: Text('📦', style: TextStyle(fontSize: 16)), text: 'Productos')]),
      ),
      body: isMobile
          ? Column(children: [
              if(_selectedBarber==null) Container(width: double.infinity, padding: const EdgeInsets.all(10), color: const Color(0xFFF59E0B).withOpacity(0.15), child: const Text('⚠️ Selecciona un barbero para vender servicios', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
              Expanded(child: TabBarView(controller: _tabController, children: [
                _services.isEmpty ? const Center(child: Text('No hay servicios', style: TextStyle(color: Colors.white54, fontSize: 13))) : GridView.builder(padding: const EdgeInsets.all(10), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 1.02, crossAxisSpacing: 10, mainAxisSpacing: 10), itemCount: _services.length, itemBuilder: (c,i)=>_buildServiceCard(_services[i])),
                _products.isEmpty ? const Center(child: Text('No hay productos', style: TextStyle(color: Colors.white54, fontSize: 13))) : GridView.builder(padding: const EdgeInsets.all(10), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 1.02, crossAxisSpacing: 10, mainAxisSpacing: 10), itemCount: _products.length, itemBuilder: (c,i)=>_buildProductCard(_products[i])),
              ])),
              _buildMobileBottomBar(),
            ])
          : Row(children: [
              Expanded(child: Column(children: [
                if(_selectedBarber==null) Container(width: double.infinity, padding: const EdgeInsets.all(10), color: const Color(0xFFF59E0B).withOpacity(0.15), child: const Text('⚠️ Selecciona un barbero para vender servicios', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 12), textAlign: TextAlign.center)),
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