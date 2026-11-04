import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; });
    final appointments = await _appointmentRepo.getAppointmentsByDate(_selectedDate);
    final barbers = await _barberRepo.getAllBarbers();
    final clients = await _clientRepo.getAllClients();
    final services = await _serviceRepo.getAllServices();
    final uniqueBarbers = <String, LocalBarber>{};
    for (final b in barbers) {
      if (b.remoteId != null) uniqueBarbers[b.remoteId!] = b;
    }
    final uniqueClients = <String, LocalClient>{};
    for (final c in clients) {
      if (c.remoteId != null) uniqueClients[c.remoteId!] = c;
    }
    final uniqueServices = <String, LocalService>{};
    for (final s in services) {
      if (s.remoteId != null) uniqueServices[s.remoteId!] = s;
    }
    setState(() {
      _appointments = appointments;
      _barbers = uniqueBarbers.values.toList();
      _clients = uniqueClients.values.toList();
      _services = uniqueServices.values.toList();
      _isLoading = false;
    });
  }

  // ✅ WHATSAPP: 3 tipos de mensaje (booking / confirmed / cancelled) con codificación correcta
  Future<void> _sendWhatsAppNotification(LocalAppointment appointment, {String type = 'confirmed'}) async {
    if (appointment.clientPhone == null || appointment.clientPhone!.isEmpty) {
      print('⚠️ No hay número de teléfono para enviar WhatsApp');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El cliente no tiene teléfono registrado'), backgroundColor: Colors.orange),
        );
      }
      return;
    }
    String phone = appointment.clientPhone!.replaceAll(RegExp(r'[^0-9]'), '');
    if (phone.startsWith('0')) phone = phone.substring(1);
    if (!phone.startsWith('56') && phone.length == 9) phone = '56$phone';

    final dateStr = DateFormat('dd/MM/yyyy').format(appointment.appointmentDate);
    final timeStr = DateFormat('HH:mm').format(appointment.appointmentDate);

    String message;
    if (type == 'cancelled') {
      message = 'Hola ${appointment.clientName}, tu cita en BBS Club Barbería ha sido *CANCELADA*.\n\n'
          '📅 *Fecha:* $dateStr\n⏰ *Hora:* $timeStr\n✂️ *Servicio:* ${appointment.serviceName}\n\n'
          'Si deseas reagendar, estamos a tu disposición. ¡Gracias!';
    } else if (type == 'booking') {
      message = 'Hola ${appointment.clientName}, tu cita en BBS Club Barbería ha sido *REGISTRADA*.\n\n'
          '📅 *Fecha:* $dateStr\n⏰ *Hora:* $timeStr\n✂️ *Servicios:* ${appointment.serviceName}\n'
          '💈 *Barbero:* ${appointment.barberName}\n\n'
          'Te contactaremos pronto para confirmar. ¡Gracias! 💈';
    } else {
      message = 'Hola ${appointment.clientName}, tu cita en BBS Club Barbería ha sido *CONFIRMADA*.\n\n'
          '📅 *Fecha:* $dateStr\n⏰ *Hora:* $timeStr\n✂️ *Servicios:* ${appointment.serviceName}\n'
          '💈 *Barbero:* ${appointment.barberName}\n\n¡Te esperamos! 💈';
    }

    final url = 'https://wa.me/$phone?text=${Uri.encodeComponent(message)}';
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        print('✅ WhatsApp abierto ($type) a $phone');
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo abrir WhatsApp'), backgroundColor: Colors.orange),
          );
        }
      }
    } catch (e) {
      print('❌ Error al abrir WhatsApp: $e');
    }
  }

  Future<void> _syncAppointments() async {
    setState(() { _isLoading = true; });
    try {
      print('🔄 Sincronizando citas...');
      final localAppointments = await _appointmentRepo.getAllAppointments();
      final cloudResponse = await Supabase.instance.client.from('appointments').select('*');
      final cloudAppointments = List<Map<String, dynamic>>.from(cloudResponse);
      int uploaded = 0;
      for (final localApt in localAppointments) {
        final localDateStr = localApt.appointmentDate.toIso8601String();
        final existsInCloud = cloudAppointments.any((cloud) {
          final cloudDate = cloud['appointment_date']?.toString() ?? '';
          final cloudDateNormalized = cloudDate.replaceAll('+00:00', '').replaceAll('Z', '');
          final localDateNormalized = localDateStr.replaceAll('+00:00', '').replaceAll('Z', '');
          return cloud['client_name'] == localApt.clientName && cloudDateNormalized == localDateNormalized;
        });
        if (!existsInCloud && localApt.remoteId != null) {
          try {
            await Supabase.instance.client.from('appointments').insert({
              'id': localApt.remoteId,
              'client_id': localApt.clientId ?? '',
              'client_name': localApt.clientName ?? '',
              'client_phone': localApt.clientPhone ?? '',
              'barber_id': localApt.barberId ?? '',
              'barber_name': localApt.barberName ?? '',
              'service_id': localApt.serviceId ?? '',
              'service_name': localApt.serviceName ?? '',
              'service_price': localApt.servicePrice,
              'appointment_date': localApt.appointmentDate.toIso8601String(),
              'status': localApt.status,
              'notes': localApt.notes,
            });
            uploaded++;
          } catch (e) {
            print('⚠️ Error al subir ${localApt.clientName}: $e');
          }
        }
      }
      int downloaded = 0;
      for (final cloudApt in cloudAppointments) {
        final remoteId = cloudApt['id'].toString();
        final existsLocally = await _appointmentRepo.findByRemoteId(remoteId);
        if (existsLocally == null) {
          try {
            final newApt = LocalAppointment()
              ..remoteId = remoteId
              ..clientName = cloudApt['client_name']
              ..clientPhone = cloudApt['client_phone']
              ..barberName = cloudApt['barber_name']
              ..serviceName = cloudApt['service_name']
              ..servicePrice = (cloudApt['service_price'] as num?)?.toDouble() ?? 0.0
              ..appointmentDate = DateTime.parse(cloudApt['appointment_date'])
              ..status = cloudApt['status'] ?? 'pending'
              ..notes = cloudApt['notes']
              ..lastSync = DateTime.now();
            await _appointmentRepo.createAppointment(newApt);
            downloaded++;
          } catch (e) {
            print('❌ Error al descargar: $e');
          }
        }
      }
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sincronizado: $uploaded subidas, $downloaded descargadas'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      print('❌ Error al sincronizar: $e');
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _updateAppointmentStatus(LocalAppointment appointment, String newStatus) async {
    try {
      appointment.status = newStatus;
      await _appointmentRepo.updateAppointment(appointment);
      await Supabase.instance.client.from('appointments').update({'status': newStatus}).eq('id', appointment.remoteId!);
      if (newStatus == 'confirmed') {
        await _sendWhatsAppNotification(appointment, type: 'confirmed');
      } else if (newStatus == 'cancelled') {
        await _sendWhatsAppNotification(appointment, type: 'cancelled');
      }
      await _loadData();
      final statusMessages = {
        'confirmed': '✅ Cita confirmada',
        'in_progress': '🟡 Cita en proceso',
        'completed': '🎉 Cita completada',
        'cancelled': '❌ Cita cancelada',
      };
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(statusMessages[newStatus] ?? 'Estado actualizado'), backgroundColor: newStatus == 'cancelled' ? Colors.red : Colors.green),
        );
      }
    } catch (e) {
      print('❌ Error al actualizar estado: $e');
    }
  }

  Future<void> _deleteAppointment(LocalAppointment appointment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar cancelación'),
        content: Text('¿Cancelar la cita de ${appointment.clientName}? Se enviará un mensaje de WhatsApp.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Sí, cancelar')),
        ],
      ),
    );
    if (confirm == true) {
      await _updateAppointmentStatus(appointment, 'cancelled');
    }
  }

  // ✅ NUEVO: días del mes que tienen citas (para marcarlos en el calendario)
  Future<Set<DateTime>> _fetchDaysWithAppointments(DateTime month) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);
    try {
      final res = await Supabase.instance.client
          .from('appointments')
          .select('appointment_date')
          .gte('appointment_date', start.toIso8601String())
          .lt('appointment_date', end.toIso8601String())
          .neq('status', 'cancelled');
      final days = <DateTime>{};
      for (final row in List<Map<String, dynamic>>.from(res)) {
        final d = DateTime.parse(row['appointment_date'].toString());
        days.add(DateTime(d.year, d.month, d.day));
      }
      return days;
    } catch (e) {
      print('⚠️ Error al cargar días con citas: $e');
      return {};
    }
  }

  // ✅ NUEVO: calendario personalizado que DESTACA los días con citas
  Future<void> _showCalendarDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    DateTime viewMonth = DateTime(_selectedDate.year, _selectedDate.month);
    Set<DateTime> days = await _fetchDaysWithAppointments(viewMonth);
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final firstDay = DateTime(viewMonth.year, viewMonth.month, 1);
          final daysInMonth = DateTime(viewMonth.year, viewMonth.month + 1, 0).day;
          final leadingBlanks = (firstDay.weekday - 1) % 7;
          final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
          final selected = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);

          Future<void> changeMonth(int delta) async {
            final newMonth = DateTime(viewMonth.year, viewMonth.month + delta);
            final newDays = await _fetchDaysWithAppointments(newMonth);
            setDialogState(() {
              viewMonth = newMonth;
              days = newDays;
            });
          }

          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            title: Row(
              children: [
                IconButton(icon: const Icon(Icons.chevron_left, color: Color(0xFF6366F1)), onPressed: () => changeMonth(-1)),
                Expanded(
                  child: Text(
                    DateFormat('MMMM yyyy', 'es').format(viewMonth),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                  ),
                ),
                IconButton(icon: const Icon(Icons.chevron_right, color: Color(0xFF6366F1)), onPressed: () => changeMonth(1)),
              ],
            ),
            content: SizedBox(
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: ['L', 'M', 'X', 'J', 'V', 'S', 'D']
                        .map((d) => Expanded(child: Center(child: Text(d, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.grey[400] : Colors.grey[600])))))
                        .toList(),
                  ),
                  const SizedBox(height: 4),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
                    itemCount: leadingBlanks + daysInMonth,
                    itemBuilder: (context, i) {
                      if (i < leadingBlanks) return const SizedBox.shrink();
                      final day = i - leadingBlanks + 1;
                      final date = DateTime(viewMonth.year, viewMonth.month, day);
                      final hasAppt = days.contains(date);
                      final isSelected = date == selected;
                      final isToday = date == today;
                      return InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          setState(() { _selectedDate = date; });
                          _loadData();
                        },
                        child: Container(
                          margin: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF6366F1) : (isToday ? const Color(0xFF6366F1).withOpacity(0.15) : Colors.transparent),
                            shape: BoxShape.circle,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$day',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: (hasAppt || isSelected) ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black87),
                                ),
                              ),
                              Container(
                                width: 6,
                                height: 6,
                                margin: const EdgeInsets.only(top: 2),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: hasAppt ? (isSelected ? Colors.white : Colors.orange) : Colors.transparent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.orange)),
                      const SizedBox(width: 6),
                      Text('Días con citas agendadas', style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ✅ DIÁLOGO CON SELECCIÓN MÚLTIPLE DE SERVICIOS
  void _showAppointmentDialog({LocalAppointment? appointment}) {
    String? selectedBarberId = appointment?.barberId;
    String? selectedClientId = appointment?.clientId;
    final Set<String> selectedServiceIds = {};
    if (appointment?.serviceId != null) selectedServiceIds.add(appointment!.serviceId!);
    DateTime selectedDateTime = appointment?.appointmentDate ?? DateTime.now();
    String selectedStatus = appointment?.status ?? 'pending';
    final notesController = TextEditingController(text: appointment?.notes ?? '');

    double selectedTotal() {
      double t = 0;
      for (final s in _services) {
        if (selectedServiceIds.contains(s.remoteId)) t += s.price;
      }
      return t;
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(appointment == null ? 'Nueva Cita' : 'Editar Cita'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedClientId,
                  decoration: const InputDecoration(labelText: 'Cliente *'),
                  items: _clients.map((client) => DropdownMenuItem(value: client.remoteId, child: Text(client.name))).toList(),
                  onChanged: (value) => setDialogState(() => selectedClientId = value),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedBarberId,
                  decoration: const InputDecoration(labelText: 'Barbero *'),
                  items: _barbers.map((barber) => DropdownMenuItem(value: barber.remoteId, child: Text(barber.name))).toList(),
                  onChanged: (value) => setDialogState(() => selectedBarberId = value),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Servicios * (puedes marcar varios)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[600])),
                ),
                const SizedBox(height: 4),
                Container(
                  constraints: const BoxConstraints(maxHeight: 180),
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(8)),
                  child: _services.isEmpty
                      ? const Padding(padding: EdgeInsets.all(12), child: Text('No hay servicios cargados', style: TextStyle(fontSize: 12)))
                      : ListView(
                          shrinkWrap: true,
                          children: _services.map((service) {
                            final checked = selectedServiceIds.contains(service.remoteId);
                            return CheckboxListTile(
                              dense: true,
                              value: checked,
                              activeColor: const Color(0xFF6366F1),
                              title: Text(service.name, style: const TextStyle(fontSize: 14)),
                              subtitle: Text(SettingsService.formatCurrency(service.price), style: const TextStyle(fontSize: 12)),
                              onChanged: (v) => setDialogState(() {
                                if (v == true) {
                                  selectedServiceIds.add(service.remoteId!);
                                } else {
                                  selectedServiceIds.remove(service.remoteId);
                                }
                              }),
                            );
                          }).toList(),
                        ),
                ),
                if (selectedServiceIds.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${selectedServiceIds.length} servicio(s) marcado(s)', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        Text('Total: ${SettingsService.formatCurrency(selectedTotal())}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF6366F1))),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Fecha y hora'),
                  subtitle: Text('${selectedDateTime.toLocal()}'.split('.')[0]),
                  trailing: const Icon(Icons.calendar_month, size: 20),
                  onTap: () async {
                    final date = await showDatePicker(context: context, initialDate: selectedDateTime, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 30)));
                    if (date != null) {
                      final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(selectedDateTime));
                      if (time != null) {
                        setDialogState(() {
                          selectedDateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                        });
                      }
                    }
                  },
                ),
                if (appointment != null) ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedStatus,
                    decoration: const InputDecoration(labelText: 'Estado'),
                    items: const [
                      DropdownMenuItem(value: 'pending', child: Text('Pendiente')),
                      DropdownMenuItem(value: 'confirmed', child: Text('Confirmada')),
                      DropdownMenuItem(value: 'in_progress', child: Text('En proceso')),
                      DropdownMenuItem(value: 'completed', child: Text('Completada')),
                      DropdownMenuItem(value: 'cancelled', child: Text('Cancelada')),
                    ],
                    onChanged: (value) => setDialogState(() => selectedStatus = value!),
                  ),
                ],
                const SizedBox(height: 8),
                TextField(controller: notesController, decoration: const InputDecoration(labelText: 'Notas'), maxLines: 3),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (selectedClientId == null || selectedBarberId == null || selectedServiceIds.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cliente, barbero y al menos un servicio son obligatorios')));
                  return;
                }
                final client = _clients.firstWhere((c) => c.remoteId == selectedClientId);
                final barber = _barbers.firstWhere((b) => b.remoteId == selectedBarberId);
                final selectedServices = _services.where((s) => selectedServiceIds.contains(s.remoteId)).toList();
                final serviceNames = selectedServices.map((s) => s.name).join(', ');
                final totalPrice = selectedServices.fold(0.0, (sum, s) => sum + s.price);

                if (appointment == null) {
                  final newAppointment = LocalAppointment()
                    ..remoteId = 'apt-${DateTime.now().millisecondsSinceEpoch}'
                    ..clientId = client.remoteId
                    ..clientName = client.name
                    ..clientPhone = client.phone
                    ..barberId = barber.remoteId
                    ..barberName = barber.name
                    ..serviceId = selectedServices.first.remoteId
                    ..serviceName = serviceNames
                    ..servicePrice = totalPrice
                    ..appointmentDate = selectedDateTime
                    ..status = selectedStatus
                    ..notes = notesController.text.isEmpty ? null : notesController.text;
                  await _appointmentRepo.createAppointment(newAppointment);
                  await _sendWhatsAppNotification(newAppointment, type: 'booking');
                } else {
                  appointment.clientId = client.remoteId;
                  appointment.clientName = client.name;
                  appointment.clientPhone = client.phone;
                  appointment.barberId = barber.remoteId;
                  appointment.barberName = barber.name;
                  appointment.serviceId = selectedServices.first.remoteId;
                  appointment.serviceName = serviceNames;
                  appointment.servicePrice = totalPrice;
                  appointment.appointmentDate = selectedDateTime;
                  appointment.status = selectedStatus;
                  appointment.notes = notesController.text.isEmpty ? null : notesController.text;
                  await _appointmentRepo.updateAppointment(appointment);
                  if (selectedStatus == 'confirmed') {
                    await _sendWhatsAppNotification(appointment, type: 'confirmed');
                  }
                }
                Navigator.pop(context);
                _loadData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(appointment == null ? '✅ Cita creada con ${selectedServiceIds.length} servicio(s)' : '✅ Cita actualizada'), backgroundColor: Colors.green),
                  );
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
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

  String _getStatusText(String status) {
    switch (status) {
      case 'pending': return 'Pendiente';
      case 'confirmed': return 'Confirmada';
      case 'in_progress': return 'En proceso';
      case 'completed': return 'Completada';
      case 'cancelled': return 'Cancelada';
      default: return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agenda de Citas'),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.sync), tooltip: 'Sincronizar con la nube', onPressed: _syncAppointments),
          IconButton(icon: const Icon(Icons.calendar_month), tooltip: 'Seleccionar fecha', onPressed: _showCalendarDialog),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: isDark ? const Color(0xFF1E293B) : Colors.indigo[50],
            child: Row(
              children: [
                Icon(Icons.today, size: 20, color: isDark ? const Color(0xFF818CF8) : Colors.indigo[700]),
                const SizedBox(width: 8),
                Text(
                  '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.indigo[700]),
                ),
                const Spacer(),
                Text('${_appointments.length} citas', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _appointments.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.event_busy, size: 64, color: isDark ? Colors.grey[600] : Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text('No hay citas para este día', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[400], fontSize: 16)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _appointments.length,
                        itemBuilder: (context, index) {
                          final appointment = _appointments[index];
                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.only(bottom: 12),
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(color: _getStatusColor(appointment.status).withOpacity(0.2), shape: BoxShape.circle),
                                        child: Icon(Icons.event, size: 24, color: _getStatusColor(appointment.status)),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(appointment.clientName ?? 'Sin cliente', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${appointment.serviceName ?? 'Sin servicio'} · ${appointment.barberName ?? 'Sin barbero'}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[300] : Colors.black87),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                                                const SizedBox(width: 4),
                                                Text('${appointment.appointmentDate.hour.toString().padLeft(2, '0')}:${appointment.appointmentDate.minute.toString().padLeft(2, '0')}', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600)),
                                                const SizedBox(width: 16),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(color: _getStatusColor(appointment.status).withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                                                  child: Text(_getStatusText(appointment.status), style: TextStyle(color: _getStatusColor(appointment.status), fontWeight: FontWeight.bold, fontSize: 12)),
                                                ),
                                              ],
                                            ),
                                            if (appointment.notes != null) ...[
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Icon(Icons.notes, size: 14, color: Colors.grey[600]),
                                                  const SizedBox(width: 4),
                                                  Expanded(child: Text(appointment.notes!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[600], fontSize: 12))),
                                                ],
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      if (appointment.status == 'pending')
                                        _ActionButton(icon: Icons.check_circle, label: 'Confirmar', color: Colors.blue, onPressed: () => _updateAppointmentStatus(appointment, 'confirmed')),
                                      if (appointment.status == 'confirmed' || appointment.status == 'pending')
                                        _ActionButton(icon: Icons.play_circle, label: 'En proceso', color: Colors.purple, onPressed: () => _updateAppointmentStatus(appointment, 'in_progress')),
                                      if (appointment.status != 'completed' && appointment.status != 'cancelled') ...[
                                        _ActionButton(icon: Icons.task_alt, label: 'Completar', color: Colors.green, onPressed: () => _updateAppointmentStatus(appointment, 'completed')),
                                        _ActionButton(icon: Icons.cancel, label: 'Cancelar', color: Colors.red, onPressed: () => _deleteAppointment(appointment)),
                                      ],
                                      _ActionButton(icon: Icons.edit, label: 'Editar', color: Colors.grey, onPressed: () => _showAppointmentDialog(appointment: appointment)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAppointmentDialog(),
        backgroundColor: const Color(0xFF6366F1),
        child: const Icon(Icons.add),
      ),
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
      icon: Icon(icon, size: 18),
      label: Text(label, style: TextStyle(color: color, fontSize: 12)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        side: BorderSide(color: color.withOpacity(0.5)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}