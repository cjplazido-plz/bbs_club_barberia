﻿import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../models/local_appointment.dart';
import '../models/local_barber.dart';
import '../models/local_client.dart';
import '../models/local_service.dart';
import '../repositories/appointment_repository.dart';
import '../repositories/barber_repository.dart';
import '../repositories/client_repository.dart';
import '../repositories/service_repository.dart';
import '../services/settings_service.dart';
import '../main.dart';
import '../services/role_permissions.dart';
import 'pos_screen.dart';
import 'blocked_hours_screen.dart';

class AppointmentsScreen extends StatefulWidget {
  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  final _appointmentRepo = AppointmentRepository();
  final _barberRepo = BarberRepository();
  final _clientRepo = ClientRepository();
  final _serviceRepo = ServiceRepository();
  List<LocalAppointment> _appointments = [];
  List<LocalBarber> _barbers = [];
  List<LocalClient> _clients = [];
  List<LocalService> _services = [];
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();
  Map<DateTime, int> _daysWithCounts = {};
  DateTime _currentMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadDaysWithCounts();
  }

  Future<void> _syncAppointments() async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sincronizando citas...')),
      );
    }
    
    await _loadData();
    await _loadDaysWithCounts();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Citas sincronizadas'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final appointments = await _appointmentRepo.getAppointmentsByDate(_selectedDate);
    final barbers = await _barberRepo.getAllBarbers();
    final clients = await _clientRepo.getAllClients();
    final services = await _serviceRepo.getAllServices();
    final uniqueBarbers = <String, LocalBarber>{};
    for (final b in barbers) { if (b.remoteId != null) uniqueBarbers[b.remoteId!] = b; }
    final uniqueClients = <String, LocalClient>{};
    for (final c in clients) { if (c.remoteId != null) uniqueClients[c.remoteId!] = c; }
    final uniqueServices = <String, LocalService>{};
    for (final s in services) { if (s.remoteId != null) uniqueServices[s.remoteId!] = s; }
    setState(() {
      _appointments = appointments;
      _barbers = uniqueBarbers.values.toList();
      _clients = uniqueClients.values.toList();
      _services = uniqueServices.values.toList();
      _isLoading = false;
    });
  }

  Future<void> _loadDaysWithCounts() async {
    try {
      final start = DateTime(_currentMonth.year, _currentMonth.month, 1);
      final end = DateTime(_currentMonth.year, _currentMonth.month + 1, 0, 23, 59, 59);
      final res = await Supabase.instance.client.from('appointments').select('appointment_date').gte('appointment_date', start.toIso8601String()).lte('appointment_date', end.toIso8601String());
      Map<DateTime, int> counts = {};
      for (var r in res) {
        final dt = DateTime.parse(r['appointment_date'] as String);
        final day = DateTime(dt.year, dt.month, dt.day);
        counts[day] = (counts[day] ?? 0) + 1;
      }
      if (mounted) setState(() => _daysWithCounts = counts);
    } catch (_) {}
  }

  Future<void> _sendWhatsAppNotification(LocalAppointment appointment, {String type = 'confirmed'}) async {
    if (appointment.clientPhone == null || appointment.clientPhone!.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El cliente no tiene teléfono'), backgroundColor: Colors.orange));
      return;
    }
    String phone = appointment.clientPhone!.replaceAll(RegExp(r'[^0-9]'), '');
    if (phone.startsWith('0')) phone = phone.substring(1);
    if (!phone.startsWith('56') && phone.length == 9) phone = '56$phone';
    final dateStr = DateFormat('dd/MM/yyyy').format(appointment.appointmentDate);
    final timeStr = DateFormat('HH:mm').format(appointment.appointmentDate);
    String msg;
    if (type == 'cancelled') {
      msg = 'Hola ${appointment.clientName}, tu cita en BBS Club Barberia ha sido *CANCELADA*.\n\n\u{1F4C5} Fecha: $dateStr\n\u{23F0} Hora: $timeStr\n\u{2702} Servicio: ${appointment.serviceName}\n\u{1F488} Barbero: ${appointment.barberName}\n\nSi deseas reagendar avisanos.';
    } else if (type == 'booking') {
      msg = 'Hola ${appointment.clientName}, tu cita en BBS Club Barberia ha sido *REGISTRADA*.\n\n\u{1F4C5} Fecha: $dateStr\n\u{23F0} Hora: $timeStr\n\u{2702} Servicio: ${appointment.serviceName}\n\u{1F488} Barbero: ${appointment.barberName}\n\nTe confirmamos pronto.';
    } else {
      msg = 'Hola ${appointment.clientName}, tu cita en BBS Club Barberia ha sido *CONFIRMADA*.\n\n\u{1F4C5} Fecha: $dateStr\n\u{23F0} Hora: $timeStr\n\u{2702} Servicio: ${appointment.serviceName}\n\u{1F488} Barbero: ${appointment.barberName}\n\n\u{1F44B} Te esperamos!';
    }
    final abonoTxt = _abonoLine(appointment.notes);
    if (abonoTxt.isNotEmpty) msg = '$msg\n\n💰 $abonoTxt';
    final url = 'https://wa.me/$phone?text=${Uri.encodeComponent(msg)}';
    final uri = Uri.parse(url);
    try { if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication); } catch (e) { print('WA $e'); }
  }

  String _abonoTag(double amount, String method, bool paid) => '[Abono: ${amount.toStringAsFixed(0)} | $method | ${paid ? 'Recibido' : 'Pendiente'}]';
  RegExp get _abonoReg => RegExp(r'\[Abono: ([0-9.]+) \| ([^|]+) \| (Recibido|Pendiente)\]');
  Map<String, dynamic>? _parseAbono(String? notes) {
    if (notes == null) return null;
    final m = _abonoReg.firstMatch(notes);
    if (m == null) return null;
    return {'amount': double.tryParse(m.group(1) ?? '0') ?? 0, 'method': (m.group(2) ?? '').trim(), 'paid': m.group(3) == 'Recibido'};
  }
  String _stripAbono(String? notes) => (notes ?? '').replaceAll(_abonoReg, '').trim();
  String _abonoLine(String? notes) {
    final a = _parseAbono(notes);
    if (a == null) return '';
    final amt = SettingsService.formatCurrency(a['amount'] as double);
    return 'Abono: $amt por ${a['method']} - ${a['paid'] ? 'Recibido' : 'Pendiente'}';
  }

  Future<void> _updateAppointmentStatus(LocalAppointment appointment, String newStatus) async {
    try {
      final oldStatus = appointment.status;
      appointment.status = newStatus;
      await _appointmentRepo.updateAppointment(appointment);
      await Supabase.instance.client.from('appointments').update({'status': newStatus}).eq('id', appointment.remoteId!);
      if (newStatus == 'confirmed') await _sendWhatsAppNotification(appointment, type: 'confirmed');
      if (newStatus == 'cancelled') await _sendWhatsAppNotification(appointment, type: 'cancelled');
      if (newStatus == 'pending' && oldStatus == 'cancelled') await _sendWhatsAppNotification(appointment, type: 'booking');
      await _loadData();
      await _loadDaysWithCounts();
      final msgs = {'pending': '🟠 Pendiente', 'confirmed': '✅ Confirmada', 'in_progress': '🟡 En proceso', 'completed': '🎉 Completada', 'cancelled': '❌ Cancelada'};
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msgs[newStatus] ?? newStatus), backgroundColor: newStatus == 'cancelled' ? Colors.red : Colors.green));
    } catch (e) { print('status $e'); }
  }

  Future<void> _deleteAppointment(LocalAppointment appointment) async {
    final confirm = await showDialog<bool>(context: context, builder: (_) => AlertDialog(backgroundColor: const Color(0xFF1E293B), title: const Text('Cancelar cita?', style: TextStyle(color: Colors.white)), content: Text('¿Cancelar cita de ${appointment.clientName}?', style: const TextStyle(color: Colors.white70)), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')), ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Sí, cancelar'))]));
    if (confirm == true) await _updateAppointmentStatus(appointment, 'cancelled');
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'confirmed': return Colors.blue;
      case 'in_progress': return Colors.purple;
      case 'completed': return Colors.green;
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _getStatusText(String s) {
    switch (s) {
      case 'pending': return 'Pendiente';
      case 'confirmed': return 'Confirmada';
      case 'in_progress': return 'En proceso';
      case 'completed': return 'Completada';
      case 'cancelled': return 'Cancelada';
      default: return s;
    }
  }

  List<Widget> _buildCalendarWeeks(int leadingEmpty, int daysInMonth) {
    final total = leadingEmpty + daysInMonth;
    final weeks = (total / 7).ceil();
    final List<Widget> rows = [];
    for (int w = 0; w < weeks; w++) {
      final List<Widget> cells = [];
      for (int d = 0; d < 7; d++) {
        final idx = w * 7 + d;
        if (idx < leadingEmpty || idx >= total) {
          cells.add(Expanded(child: Container(height: 38, margin: const EdgeInsets.all(3))));
          continue;
        }
        final day = idx - leadingEmpty + 1;
        final date = DateTime(_currentMonth.year, _currentMonth.month, day);
        final count = _daysWithCounts[DateTime(date.year, date.month, date.day)] ?? 0;
        final isSelected = date.year == _selectedDate.year && date.month == _selectedDate.month && date.day == _selectedDate.day;
        final isToday = date.year == DateTime.now().year && date.month == DateTime.now().month && date.day == DateTime.now().day;
        final bg = isSelected ? const Color(0xFF6366F1) : count > 0 ? const Color(0xFF6366F1).withOpacity(0.18) : const Color(0xFF0F172A);
        final border = isSelected ? const Color(0xFF6366F1) : isToday ? const Color(0xFF6366F1).withOpacity(0.6) : count > 0 ? const Color(0xFFF59E0B).withOpacity(0.4) : Colors.white10;
        cells.add(
          Expanded(
            child: Container(
              height: 38,
              margin: const EdgeInsets.all(3),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() => _selectedDate = date);
                    _loadData();
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: border, width: 1)),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Text(
                          '$day',
                          style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, fontSize: 11),
                        ),
                        if (count > 0)
                          Positioned(
                            bottom: 2,
                            child: Container(
                              width: 16,
                              height: 12,
                              decoration: BoxDecoration(color: isSelected ? Colors.white : const Color(0xFFF59E0B), borderRadius: BorderRadius.circular(6)),
                              child: Center(
                                child: Text(
                                  '$count',
                                  style: TextStyle(color: isSelected ? const Color(0xFF6366F1) : Colors.white, fontSize: 7, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }
      rows.add(Row(children: cells));
    }
    return rows;
  }

  Widget _buildPremiumCalendarCompact() {
    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final firstWeekday = DateTime(_currentMonth.year, _currentMonth.month, 1).weekday;
    final leadingEmpty = firstWeekday - 1;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Row(children: [
                Container(padding: const EdgeInsets.all(5), decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.2), borderRadius: BorderRadius.circular(6)), child: const Icon(Icons.calendar_month, color: Color(0xFF6366F1), size: 14)),
                const SizedBox(width: 8),
                Text(DateFormat('MMMM yyyy', 'es').format(_currentMonth), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              ]),
              Row(children: [
                IconButton(icon: const Icon(Icons.chevron_left, color: Colors.white54, size: 18), onPressed: (){ setState(()=> _currentMonth = DateTime(_currentMonth.year, _currentMonth.month -1)); _loadDaysWithCounts(); }, padding: EdgeInsets.zero, constraints: const BoxConstraints.tightFor(width: 28, height: 28)),
                IconButton(icon: const Icon(Icons.chevron_right, color: Colors.white54, size: 18), onPressed: (){ setState(()=> _currentMonth = DateTime(_currentMonth.year, _currentMonth.month +1)); _loadDaysWithCounts(); }, padding: EdgeInsets.zero, constraints: const BoxConstraints.tightFor(width: 28, height: 28)),
              ]),
            ]),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: const ['L','M','X','J','V','S','D'].map((d)=> SizedBox(width: 32, child: Center(child: Text(d, style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold))))).toList()),
            const SizedBox(height: 4),
            ..._buildCalendarWeeks(leadingEmpty, daysInMonth),
            const SizedBox(height: 8),
            Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: const Color(0xFFF59E0B), borderRadius: BorderRadius.circular(4))),
              const SizedBox(width: 5),
              const Text('Día con citas', style: TextStyle(color: Colors.white54, fontSize: 9)),
              const SizedBox(width: 12),
              Container(width: 8, height: 8, decoration: BoxDecoration(color: const Color(0xFF6366F1), borderRadius: BorderRadius.circular(4))),
              const SizedBox(width: 5),
              const Text('Seleccionado', style: TextStyle(color: Colors.white54, fontSize: 9)),
              const Spacer(),
              InkWell(onTap: (){ setState(()=> _selectedDate = DateTime.now()); _loadData(); }, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.2), borderRadius: BorderRadius.circular(6)), child: const Text('Hoy', style: TextStyle(color: Color(0xFF6366F1), fontSize: 9, fontWeight: FontWeight.bold)))),
            ]),
          ]),
        ),
      ),
    );
  }

  Future<void> _addAsClient(LocalAppointment appointment) async {
    final name = (appointment.clientName ?? '').trim();
    final phone = (appointment.clientPhone ?? '').trim();
    if (name.isEmpty) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sin nombre para agregar como cliente'), backgroundColor: Colors.orange)); return; }
    final exists = _clients.any((c) => (c.remoteId != null && c.remoteId == appointment.clientId) || (c.name.trim().toLowerCase() == name.toLowerCase() && (c.phone ?? '').trim() == phone));
    if (exists) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ya esta en Clientes'), backgroundColor: Colors.blue)); return; }
    try {
      await _clientRepo.createClient(name: name, phone: phone, email: '', notes: 'Creado desde Agenda ${DateFormat('dd/MM/yyyy').format(DateTime.now())}');
    } catch (_) {
      try { await Supabase.instance.client.from('clients').insert({'name': name, 'phone': phone}); } catch (_) {}
    }
    await _loadData();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cliente $name agregado a Clientes'), backgroundColor: Colors.green));
  }

  void _showAppointmentDialog({LocalAppointment? existing}) {
    String? selectedBarberId = existing?.barberId;
    String? selectedClientId = existing?.clientId;
    final Set<String> selectedServiceIds = {};
    if (existing?.serviceId != null) selectedServiceIds.add(existing!.serviceId!);
    DateTime selectedDateTime = existing?.appointmentDate ?? DateTime.now();
    String selectedStatus = existing?.status ?? 'pending';
    final bool isReagendar = existing?.status == 'cancelled';
    if (isReagendar) selectedStatus = 'pending';
    final notesController = TextEditingController(text: _stripAbono(existing?.notes));
    final _abonoExistente = _parseAbono(existing?.notes);
    final depositAmountController = TextEditingController(text: _abonoExistente != null ? (_abonoExistente['amount'] as double).toStringAsFixed(0) : '');
    String depositMethod = _abonoExistente?['method'] as String? ?? 'Transferencia';
    bool depositPaid = _abonoExistente?['paid'] as bool? ?? false;
    bool hasDeposit = _abonoExistente != null;
    final _clientIds = _clients.map((c) => c.remoteId).whereType<String>().where((id) => id.isNotEmpty).toSet();
    final _barberIds = _barbers.map((b) => b.remoteId).whereType<String>().where((id) => id.isNotEmpty).toSet();
    if (selectedClientId != null && !_clientIds.contains(selectedClientId)) {
      selectedClientId = null;
    }
    if (selectedBarberId != null && !_barberIds.contains(selectedBarberId)) selectedBarberId = null;
    bool isNewClient = selectedClientId == null && existing != null && (existing.clientName ?? '').isNotEmpty;
    bool saveAsClient = true;
    final newClientNameController = TextEditingController(text: isNewClient ? (existing?.clientName ?? '') : '');
    final phoneController = TextEditingController(text: existing?.clientPhone ?? '');
    LocalClient? selectedClient() {
      if (selectedClientId == null) return null;
      try { return _clients.firstWhere((c) => c.remoteId == selectedClientId); } catch (_) { return null; }
    }
    if (phoneController.text.isEmpty && selectedClient() != null) phoneController.text = selectedClient()!.phone ?? '';
    double totalServ() { double t=0; for(final s in _services){ if(selectedServiceIds.contains(s.remoteId)) t+= s.price; } return t; }

    showDialog(context: context, builder: (ctx){
      return StatefulBuilder(builder: (ctx2, setD){
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(existing==null?'Nueva Cita':'Editar Cita', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (!isNewClient) DropdownButtonFormField<String>(value: (_clientIds.contains(selectedClientId) ? selectedClientId : null), dropdownColor: const Color(0xFF1E293B), style: const TextStyle(color: Colors.white, fontSize: 12), decoration: InputDecoration(labelText: 'Cliente *', labelStyle: const TextStyle(color: Colors.white54), filled: true, fillColor: const Color(0xFF0F172A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), items: [...{for (final c in _clients) c.remoteId: c}.values.map((c)=> DropdownMenuItem(value: c.remoteId, child: Text(c.name, style: const TextStyle(fontSize: 12)))), const DropdownMenuItem(value: '__new__', child: Text('+ Nuevo cliente...', style: TextStyle(fontSize: 12, color: Color(0xFF6366F1), fontWeight: FontWeight.bold)))], onChanged: (v){ if (v == '__new__') { setD((){ isNewClient = true; selectedClientId = null; }); } else { setD((){ selectedClientId = v; final c = selectedClient(); if (c != null && (phoneController.text.isEmpty)) phoneController.text = c.phone ?? ''; }); } }),
            if (isNewClient) Column(children: [
              TextField(controller: newClientNameController, style: const TextStyle(color: Colors.white, fontSize: 12), decoration: InputDecoration(labelText: 'Nombre nuevo cliente *', labelStyle: const TextStyle(color: Colors.white54), filled: true, fillColor: const Color(0xFF0F172A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
              const SizedBox(height: 6),
              TextButton.icon(onPressed: ()=> setD(()=> isNewClient = false), icon: const Icon(Icons.arrow_back, size: 14), label: const Text('Elegir cliente existente', style: TextStyle(fontSize: 11))),
            ]),
            const SizedBox(height: 8),
            TextField(controller: phoneController, keyboardType: TextInputType.phone, style: const TextStyle(color: Colors.white, fontSize: 12), decoration: InputDecoration(labelText: 'Telefono del cliente *', hintText: 'Ej: +56 9 6106 9670', hintStyle: const TextStyle(color: Colors.white24, fontSize: 11), prefixIcon: const Icon(Icons.phone_rounded, color: Colors.white38, size: 18), labelStyle: const TextStyle(color: Colors.white54), filled: true, fillColor: const Color(0xFF0F172A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white10)), 
              child: Material(
                type: MaterialType.transparency,
                child: SwitchListTile(value: saveAsClient, onChanged: (v)=> setD(()=> saveAsClient = v), activeColor: const Color(0xFF6366F1), dense: true, title: const Text('Guardar / actualizar como cliente', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)), subtitle: const Text('Si el cliente no esta en Clientes, se crea. Si ya esta, se actualiza su telefono.', style: TextStyle(color: Colors.white54, fontSize: 9)))
              )
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(value: (_barberIds.contains(selectedBarberId) ? selectedBarberId : null), dropdownColor: const Color(0xFF1E293B), style: const TextStyle(color: Colors.white, fontSize: 12), decoration: InputDecoration(labelText: 'Barbero *', labelStyle: const TextStyle(color: Colors.white54), filled: true, fillColor: const Color(0xFF0F172A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), items: {for (final b in _barbers) b.remoteId: b}.values.map((b)=> DropdownMenuItem(value: b.remoteId, child: Text(b.name, style: const TextStyle(fontSize: 12)))).toList(), onChanged: (v)=> setD(()=> selectedBarberId=v)),
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerLeft, child: Text('Servicios * (varios)', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold))),
            const SizedBox(height: 4),
            Container(
              constraints: const BoxConstraints(maxHeight: 150), 
              decoration: BoxDecoration(color: const Color(0xFF0F172A), border: Border.all(color: Colors.white10), borderRadius: BorderRadius.circular(8)), 
              child: SingleChildScrollView(
                child: Material(
                  color: Colors.transparent, 
                  child: Column(children: _services.map((s){ final checked=selectedServiceIds.contains(s.remoteId); return CheckboxListTile(dense: true, value: checked, activeColor: const Color(0xFF6366F1), title: Text(s.name, style: const TextStyle(color: Colors.white, fontSize: 11)), subtitle: Text(SettingsService.formatCurrency(s.price), style: const TextStyle(color: Colors.white38, fontSize: 9)), onChanged: (v)=> setD(()=> v==true? selectedServiceIds.add(s.remoteId!): selectedServiceIds.remove(s.remoteId))); }).toList())
                )
              )
            ),
            if(selectedServiceIds.isNotEmpty) Padding(padding: const EdgeInsets.only(top:6), child: Text('Total ${SettingsService.formatCurrency(totalServ())}', style: const TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold, fontSize: 11))),
            const SizedBox(height: 8),
            Material(
              color: Colors.transparent,
              child: ListTile(contentPadding: EdgeInsets.zero, title: const Text('Fecha y hora', style: TextStyle(color: Colors.white54, fontSize: 10)), subtitle: Text('${selectedDateTime.day}/${selectedDateTime.month} ${selectedDateTime.hour}:${selectedDateTime.minute.toString().padLeft(2,'0')}', style: const TextStyle(color: Colors.white, fontSize: 11)), trailing: const Icon(Icons.calendar_month, color: Colors.white54, size: 16), onTap: () async {
                final d = await showDatePicker(context: context, initialDate: selectedDateTime, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 60)));
                if(d!=null){ final t=await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(selectedDateTime)); if(t!=null) setD(()=> selectedDateTime=DateTime(d.year,d.month,d.day,t.hour,t.minute)); }
              })
            ),
            if (isReagendar) Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.12), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3))), child: const Row(children: [Icon(Icons.restore, size: 14, color: Color(0xFF10B981)), SizedBox(width: 6), Expanded(child: Text('Reagendando cita cancelada - al guardar quedara Pendiente para reconfirmar en la nueva fecha.', style: TextStyle(color: Colors.white70, fontSize: 10)))])),
            if (isReagendar) const SizedBox(height: 8),
            DropdownButtonFormField<String>(value: selectedStatus, dropdownColor: const Color(0xFF1E293B), style: const TextStyle(color: Colors.white, fontSize: 12), decoration: InputDecoration(labelText: 'Estado *', labelStyle: const TextStyle(color: Colors.white54), filled: true, fillColor: const Color(0xFF0F172A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), items: const [DropdownMenuItem(value: 'pending', child: Text('Pendiente', style: TextStyle(fontSize: 12))), DropdownMenuItem(value: 'confirmed', child: Text('Confirmada', style: TextStyle(fontSize: 12))), DropdownMenuItem(value: 'in_progress', child: Text('En proceso', style: TextStyle(fontSize: 12))), DropdownMenuItem(value: 'completed', child: Text('Completada', style: TextStyle(fontSize: 12))), DropdownMenuItem(value: 'cancelled', child: Text('Cancelada', style: TextStyle(fontSize: 12)))], onChanged: (v)=> setD(()=> selectedStatus = v ?? 'pending')),
            const SizedBox(height: 8),
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white10)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [const Icon(Icons.payments, size: 14, color: Color(0xFFF59E0B)), const SizedBox(width: 6), const Text('Abono / Anticipo', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)), const Spacer(), Switch(value: hasDeposit, activeColor: const Color(0xFFF59E0B), onChanged: (v)=> setD(()=> hasDeposit = v)),
              ]),
              if (hasDeposit) Column(children: [
                const SizedBox(height: 8),
                TextField(controller: depositAmountController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white, fontSize: 12), decoration: InputDecoration(labelText: 'Monto abono (ej: 5000)', labelStyle: const TextStyle(color: Colors.white54, fontSize: 11), filled: true, fillColor: const Color(0xFF1E293B), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(value: depositMethod, dropdownColor: const Color(0xFF1E293B), style: const TextStyle(color: Colors.white, fontSize: 12), decoration: InputDecoration(labelText: 'Metodo', labelStyle: const TextStyle(color: Colors.white54), filled: true, fillColor: const Color(0xFF1E293B), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), items: const [DropdownMenuItem(value: 'Transferencia', child: Text('Transferencia', style: TextStyle(fontSize: 12))), DropdownMenuItem(value: 'Efectivo', child: Text('Efectivo', style: TextStyle(fontSize: 12))), DropdownMenuItem(value: 'Tarjeta', child: Text('Tarjeta', style: TextStyle(fontSize: 12)))], onChanged: (v)=> setD(()=> depositMethod = v ?? 'Transferencia')),
                const SizedBox(height: 6),
                Material(color: Colors.transparent, child: CheckboxListTile(dense: true, value: depositPaid, activeColor: const Color(0xFF10B981), title: const Text('Abono recibido / verificado', style: TextStyle(color: Colors.white, fontSize: 11)), subtitle: const Text('Marca esto solo cuando veas la transferencia en tu cuenta.', style: TextStyle(color: Colors.white54, fontSize: 9)), onChanged: (v)=> setD(()=> depositPaid = v ?? false))),
                const Text('Pide que te mande el comprobante por WhatsApp y verifica en tu banco antes de marcar Recibido.', style: TextStyle(color: Colors.white38, fontSize: 9)),
              ]),
            ])),
            const SizedBox(height: 8),
            TextField(controller: notesController, style: const TextStyle(color: Colors.white, fontSize: 11), decoration: InputDecoration(labelText: 'Notas', labelStyle: const TextStyle(color: Colors.white54, fontSize: 9), filled: true, fillColor: const Color(0xFF0F172A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), maxLines: 2),
          ])),
          actions: [
            TextButton(onPressed: ()=> Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(onPressed: () async {
              final phone = phoneController.text.trim();
              if(phone.isEmpty){ ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Falta el telefono del cliente'))); return; }
              if(isNewClient && newClientNameController.text.trim().isEmpty){ ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Falta el nombre del nuevo cliente'))); return; }
              if(!isNewClient && selectedClientId==null){ ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Falta cliente'))); return; }
              if(selectedBarberId==null || selectedServiceIds.isEmpty){ ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Falta barbero/servicio'))); return; }
              LocalClient client;
              if (isNewClient) {
                try { await _clientRepo.createClient(name: newClientNameController.text.trim(), phone: phone, email: '', notes: 'Creado desde Agenda'); } catch (_) { try { await Supabase.instance.client.from('clients').insert({'name': newClientNameController.text.trim(), 'phone': phone}); } catch (_) {} }
                final all = await _clientRepo.getAllClients();
                if (mounted) setState(() => _clients = all);
                client = all.firstWhere((c) => c.name.trim().toLowerCase() == newClientNameController.text.trim().toLowerCase() && (c.phone ?? '').trim() == phone, orElse: () => LocalClient()..remoteId = 'tmp-${DateTime.now().millisecondsSinceEpoch}'..name = newClientNameController.text.trim()..phone = phone);
                selectedClientId = client.remoteId;
              } else {
                client = _clients.firstWhere((c)=> c.remoteId==selectedClientId);
                if (saveAsClient && (client.phone ?? '').trim() != phone) {
                  try { await Supabase.instance.client.from('clients').update({'phone': phone}).eq('id', client.remoteId!); } catch (_) {}
                  client.phone = phone;
                } else if (saveAsClient && !_clients.any((c) => c.remoteId == client.remoteId)) {
                  try { await _clientRepo.createClient(name: client.name, phone: phone, email: '', notes: 'Creado desde Agenda'); } catch (_) {}
                }
              }
              final barber = _barbers.firstWhere((b)=> b.remoteId==selectedBarberId);
              final firstService = _services.firstWhere((s)=> selectedServiceIds.contains(s.remoteId));
              final newApp = LocalAppointment()
                ..remoteId = existing?.remoteId
                ..clientId = client.remoteId!
                ..clientName = client.name
                ..clientPhone = phone
                ..barberId = barber.remoteId!
                ..barberName = barber.name
                ..serviceId = firstService.remoteId!
                ..serviceName = _services.where((s)=> selectedServiceIds.contains(s.remoteId)).map((s)=> s.name).join(', ')
                ..appointmentDate = selectedDateTime
                ..status = selectedStatus
                ..notes = (() {
                  final base = notesController.text.trim();
                  if (!hasDeposit) return base;
                  final amt = double.tryParse(depositAmountController.text.trim().replaceAll('.', '').replaceAll(',', '')) ?? 0;
                  if (amt <= 0) return base;
                  final tag = _abonoTag(amt, depositMethod, depositPaid);
                  return base.isEmpty ? tag : '$base $tag';
                })();
              if(newApp.remoteId==null){
                await _appointmentRepo.createAppointment(newApp);
                await Supabase.instance.client.from('appointments').insert({'client_id': newApp.clientId,'client_name': newApp.clientName,'client_phone': newApp.clientPhone,'barber_id': newApp.barberId,'barber_name': newApp.barberName,'service_id': newApp.serviceId,'service_name': newApp.serviceName,'appointment_date': newApp.appointmentDate.toIso8601String(),'status': newApp.status,'notes': newApp.notes});
              } else {
                await _appointmentRepo.updateAppointment(newApp);
                await Supabase.instance.client.from('appointments').update({'client_id': newApp.clientId,'client_name': newApp.clientName,'client_phone': newApp.clientPhone,'barber_id': newApp.barberId,'service_id': newApp.serviceId,'service_name': newApp.serviceName,'appointment_date': newApp.appointmentDate.toIso8601String(),'status': newApp.status,'notes': newApp.notes}).eq('id', newApp.remoteId!);
              }
              Navigator.pop(context);
              _loadData();
              _loadDaysWithCounts();
            }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)), child: Text(existing==null?'Crear':'Guardar')),
          ],
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // Evaluamos permisos para la vista de citas
    final canCreateEdit = RolePermissions.can(currentUserRole, BbsPerm.createEditAppointment);
    final canConfirmCancel = RolePermissions.can(currentUserRole, BbsPerm.confirmCancel);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () { if (Navigator.canPop(context)) { Navigator.pop(context); } else { Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => PosScreen())); } }),
        title: const Text('Agenda', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          if (RolePermissions.isAdmin(currentUserRole))
            IconButton(icon: const Icon(Icons.lock_clock_rounded, color: Colors.white), tooltip: 'Bloquear Horas', onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (_) => BlockedHoursScreen()));}),
          IconButton(icon: const Icon(Icons.sync), tooltip: 'Sincronizar', onPressed: _syncAppointments),
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white54), onPressed: (){ _loadData(); _loadDaysWithCounts();})
        ]
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1))) : SingleChildScrollView(padding: const EdgeInsets.all(12), child: Column(children: [
        _buildPremiumCalendarCompact(),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Citas ${DateFormat('dd MMM yyyy', 'es').format(_selectedDate)} (${_appointments.length})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          if (canCreateEdit)
            TextButton.icon(onPressed: ()=> _showAppointmentDialog(), icon: const Icon(Icons.add, size: 14, color: Color(0xFF6366F1)), label: const Text('Nueva', style: TextStyle(fontSize: 11, color: Color(0xFF6366F1)))),
        ]),
        const SizedBox(height: 8),
        ..._appointments.map((appointment){
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(14), border: Border.all(color: appointment.status=='cancelled'? Colors.red.withOpacity(0.3): Colors.white10)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: _getStatusColor(appointment.status).withOpacity(0.18), shape: BoxShape.circle), child: Icon(Icons.event, size: 20, color: _getStatusColor(appointment.status))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(appointment.clientName ?? 'Sin cliente', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                  const SizedBox(height: 2),
                  Text('${appointment.serviceName ?? 'Sin servicio'} · ${appointment.barberName ?? 'Sin barbero'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Colors.white54)),
                  const SizedBox(height: 4),
                  if ((appointment.clientPhone ?? '').isNotEmpty) Material(color: Colors.transparent, child: InkWell(onTap: () => _sendWhatsAppNotification(appointment, type: 'confirmed'), borderRadius: BorderRadius.circular(6), child: Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.phone_rounded, size: 12, color: Color(0xFF10B981)), const SizedBox(width: 4), Text(appointment.clientPhone!, style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.w600)), const SizedBox(width: 6), const Icon(Icons.chat_rounded, size: 11, color: Colors.white38)])))),
                  if ((appointment.clientPhone ?? '').isEmpty) const Row(children: [Icon(Icons.phone_disabled_rounded, size: 12, color: Colors.orange), SizedBox(width: 4), Text('Sin telefono - agregalo en Editar', style: TextStyle(color: Colors.orange, fontSize: 10))]),
                  if (!_clients.any((c) => c.remoteId == appointment.clientId || (c.name.trim().toLowerCase() == (appointment.clientName ?? '').trim().toLowerCase() && (c.phone ?? '').trim() == (appointment.clientPhone ?? '').trim()))) Padding(padding: const EdgeInsets.only(top: 4), child: Material(color: Colors.transparent, child: InkWell(onTap: () => _addAsClient(appointment), borderRadius: BorderRadius.circular(20), child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.18), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.4))), child: const Text('+ Agregar como cliente', style: TextStyle(color: Color(0xFF818CF8), fontSize: 10, fontWeight: FontWeight.bold)))))),
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.schedule, size: 12, color: Colors.white38),
                    const SizedBox(width: 4),
                    Text('${appointment.appointmentDate.hour.toString().padLeft(2,'0')}:${appointment.appointmentDate.minute.toString().padLeft(2,'0')}', style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 12),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: _getStatusColor(appointment.status).withOpacity(0.18), borderRadius: BorderRadius.circular(10)), child: Text(_getStatusText(appointment.status), style: TextStyle(color: _getStatusColor(appointment.status), fontWeight: FontWeight.bold, fontSize: 10))),
                  ]),
                  if (appointment.notes != null && appointment.notes!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(children: [Icon(Icons.notes, size: 12, color: Colors.white30), const SizedBox(width: 4), Expanded(child: Text(appointment.notes!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white38, fontSize: 10)))]),
                  ],
                ])),
              ]),
              const SizedBox(height: 12),
              if (_parseAbono(appointment.notes) != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: (_parseAbono(appointment.notes)!['paid'] as bool) ? const Color(0xFF10B981).withOpacity(0.15) : const Color(0xFFF59E0B).withOpacity(0.15), borderRadius: BorderRadius.circular(20)), child: Text('💰 ${_abonoLine(appointment.notes)}', style: TextStyle(color: (_parseAbono(appointment.notes)!['paid'] as bool) ? const Color(0xFF10B981) : const Color(0xFFF59E0B), fontSize: 10, fontWeight: FontWeight.bold)))),
              
              // BOTONES DE ACCIÓN PROTEGIDOS POR PERMISOS
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (canConfirmCancel && appointment.status == 'pending')
                  _ActionButton(icon: Icons.check_circle, label: 'Confirmar', color: Colors.blue, onPressed: () => _updateAppointmentStatus(appointment, 'confirmed')),
                if (canConfirmCancel && appointment.status == 'confirmed')
                  _ActionButton(icon: Icons.undo, label: 'Volver a Pendiente', color: Colors.orange, onPressed: () => _updateAppointmentStatus(appointment, 'pending')),
                if (canCreateEdit && (appointment.status == 'confirmed' || appointment.status == 'pending'))
                  _ActionButton(icon: Icons.play_circle, label: 'En proceso', color: Colors.purple, onPressed: () => _updateAppointmentStatus(appointment, 'in_progress')),
                if (canCreateEdit && appointment.status != 'completed' && appointment.status != 'cancelled') ...[
                  _ActionButton(icon: Icons.task_alt, label: 'Completar', color: Colors.green, onPressed: () => _updateAppointmentStatus(appointment, 'completed')),
                ],
                if (canConfirmCancel && appointment.status != 'completed' && appointment.status != 'cancelled') ...[
                  _ActionButton(icon: Icons.cancel, label: 'Cancelar', color: Colors.red, onPressed: () => _deleteAppointment(appointment)),
                ],
                if (canCreateEdit && appointment.status == 'cancelled')
                  _ActionButton(icon: Icons.restore, label: 'Reagendar', color: Colors.green, onPressed: () => _showAppointmentDialog(existing: appointment)),
                if (canCreateEdit)
                  _ActionButton(icon: Icons.edit, label: 'Editar', color: Colors.grey, onPressed: () => _showAppointmentDialog(existing: appointment)),
                if (appointment.status == 'cancelled')
                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.red.withOpacity(0.12), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.withOpacity(0.3))), child: const Text('Cancelada', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold))),
              ]),
            ]),
          );
        }),
        if(_appointments.isEmpty) Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(14)), child: Column(children: [Icon(Icons.event_busy, color: Colors.white12, size: 36), const SizedBox(height: 8), const Text('Sin citas para este día', style: TextStyle(color: Colors.white38, fontSize: 12)), const SizedBox(height: 8), if (canCreateEdit) ElevatedButton.icon(onPressed: ()=> _showAppointmentDialog(), icon: const Icon(Icons.add, size: 14), label: const Text('Nueva cita', style: TextStyle(fontSize: 11)), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)))])),
      ])),
      floatingActionButton: canCreateEdit ? FloatingActionButton(onPressed: ()=> _showAppointmentDialog(), backgroundColor: const Color(0xFF6366F1), child: const Icon(Icons.add, color: Colors.white)) : null,
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;
  const _ActionButton({required this.icon, required this.label, required this.color, required this.onPressed});
  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16, color: color),
      label: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), side: BorderSide(color: color.withOpacity(0.4)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
    );
  }
}