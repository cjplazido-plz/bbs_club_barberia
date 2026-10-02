import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/local_appointment.dart';
import '../models/local_barber.dart';
import '../models/local_client.dart';
import '../models/local_service.dart';
import '../repositories/appointment_repository.dart';
import '../repositories/barber_repository.dart';
import '../repositories/client_repository.dart';
import '../repositories/service_repository.dart';

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
    
    // ✅ Filtrar duplicados por remoteId
    final uniqueBarbers = <String, LocalBarber>{};
    for (final b in barbers) {
      if (b.remoteId != null) {
        uniqueBarbers[b.remoteId!] = b;
      }
    }
    
    final uniqueClients = <String, LocalClient>{};
    for (final c in clients) {
      if (c.remoteId != null) {
        uniqueClients[c.remoteId!] = c;
      }
    }
    
    final uniqueServices = <String, LocalService>{};
    for (final s in services) {
      if (s.remoteId != null) {
        uniqueServices[s.remoteId!] = s;
      }
    }
    
    setState(() {
      _appointments = appointments;
      _barbers = uniqueBarbers.values.toList();
      _clients = uniqueClients.values.toList();
      _services = uniqueServices.values.toList();
      _isLoading = false;
    });
  }

  // 🔄 Sincronizar citas (bidireccional: sube y descarga)
  Future<void> _syncAppointments() async {
    setState(() { _isLoading = true; });
    try {
      print('🔄 Sincronizando citas...');
      final localAppointments = await _appointmentRepo.getAllAppointments();
      print('📱 Citas locales: ${localAppointments.length}');
      
      final cloudResponse = await Supabase.instance.client
          .from('appointments')
          .select('*');
      final cloudAppointments = List<Map<String, dynamic>>.from(cloudResponse);
      print('☁️ Citas en Supabase: ${cloudAppointments.length}');

      int uploaded = 0;
      for (final localApt in localAppointments) {
        final localDateStr = localApt.appointmentDate.toIso8601String();
        final existsInCloud = cloudAppointments.any((cloud) {
          final cloudDate = cloud['appointment_date']?.toString() ?? '';
          final cloudDateNormalized = cloudDate.replaceAll('+00:00', '').replaceAll('Z', '');
          final localDateNormalized = localDateStr.replaceAll('+00:00', '').replaceAll('Z', '');
          return cloud['client_name'] == localApt.clientName &&
                 cloudDateNormalized == localDateNormalized;
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
            print('  ⬆️ Subida: ${localApt.clientName} - ${localApt.appointmentDate}');
          } catch (e) {
            print('  ❌ Error al subir ${localApt.clientName}: $e');
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
            print('  ️ Descargada: ${newApt.clientName}');
          } catch (e) {
            print('  ❌ Error al descargar: $e');
          }
        }
      }

      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Sincronizado: $uploaded subidas, $downloaded descargadas'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ Error al sincronizar: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  // ✅ Botón rápido: Cambiar estado de cita
  Future<void> _updateAppointmentStatus(LocalAppointment appointment, String newStatus) async {
    try {
      appointment.status = newStatus;
      await _appointmentRepo.updateAppointment(appointment);
      
      await Supabase.instance.client
          .from('appointments')
          .update({'status': newStatus})
          .eq('id', appointment.remoteId!);
      
      await _loadData();
      
      final statusMessages = {
        'confirmed': '✅ Cita confirmada',
        'in_progress': '🟡 Cita en proceso',
        'completed': '🎉 Cita completada',
        'cancelled': ' Cita cancelada',
      };
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(statusMessages[newStatus] ?? 'Estado actualizado'),
            backgroundColor: newStatus == 'cancelled' ? Colors.red : Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ Error al actualizar estado: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // 🗑️ Cancelar cita
  Future<void> _deleteAppointment(LocalAppointment appointment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar cancelación'),
        content: Text('¿Cancelar la cita de ${appointment.clientName}?'),
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

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() { _selectedDate = picked; });
      _loadData();
    }
  }

  void _showAppointmentDialog({LocalAppointment? appointment}) {
    String? selectedBarberId = appointment?.barberId;
    String? selectedClientId = appointment?.clientId;
    String? selectedServiceId = appointment?.serviceId;
    DateTime selectedDateTime = appointment?.appointmentDate ?? DateTime.now();
    String selectedStatus = appointment?.status ?? 'pending';
    final notesController = TextEditingController(text: appointment?.notes ?? '');

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
                  items: _clients.map((client) => DropdownMenuItem(
                    value: client.remoteId,
                    child: Text(client.name),
                  )).toList(),
                  onChanged: (value) => setDialogState(() => selectedClientId = value),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedBarberId,
                  decoration: const InputDecoration(labelText: 'Barbero *'),
                  items: _barbers.map((barber) => DropdownMenuItem(
                    value: barber.remoteId,
                    child: Text(barber.name),
                  )).toList(),
                  onChanged: (value) => setDialogState(() => selectedBarberId = value),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedServiceId,
                  decoration: const InputDecoration(labelText: 'Servicio *'),
                  items: _services.map((service) => DropdownMenuItem(
                    value: service.remoteId,
                    child: Text('${service.name} - \$${service.price}'),
                  )).toList(),
                  onChanged: (value) => setDialogState(() => selectedServiceId = value),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Fecha y hora'),
                  subtitle: Text('${selectedDateTime.toLocal()}'.split('.')[0]),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDateTime,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 30)),
                    );
                    if (date != null) {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(selectedDateTime),
                      );
                      if (time != null) {
                        setDialogState(() {
                          selectedDateTime = DateTime(
                            date.year, date.month, date.day,
                            time.hour, time.minute,
                          );
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
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(labelText: 'Notas'),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (selectedClientId == null || selectedBarberId == null || selectedServiceId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cliente, barbero y servicio son obligatorios')),
                  );
                  return;
                }
                final client = _clients.firstWhere((c) => c.remoteId == selectedClientId);
                final barber = _barbers.firstWhere((b) => b.remoteId == selectedBarberId);
                final service = _services.firstWhere((s) => s.remoteId == selectedServiceId);
                
                if (appointment == null) {
                  final newAppointment = LocalAppointment()
                    ..remoteId = 'apt-${DateTime.now().millisecondsSinceEpoch}'
                    ..clientId = client.remoteId
                    ..clientName = client.name
                    ..clientPhone = client.phone
                    ..barberId = barber.remoteId
                    ..barberName = barber.name
                    ..serviceId = service.remoteId
                    ..serviceName = service.name
                    ..servicePrice = service.price
                    ..appointmentDate = selectedDateTime
                    ..status = selectedStatus
                    ..notes = notesController.text.isEmpty ? null : notesController.text;
                  await _appointmentRepo.createAppointment(newAppointment);
                  print('✅ Cita creada localmente');
                } else {
                  appointment.clientId = client.remoteId;
                  appointment.clientName = client.name;
                  appointment.clientPhone = client.phone;
                  appointment.barberId = barber.remoteId;
                  appointment.barberName = barber.name;
                  appointment.serviceId = service.remoteId;
                  appointment.serviceName = service.name;
                  appointment.servicePrice = service.price;
                  appointment.appointmentDate = selectedDateTime;
                  appointment.status = selectedStatus;
                  appointment.notes = notesController.text.isEmpty ? null : notesController.text;
                  await _appointmentRepo.updateAppointment(appointment);
                  print('✅ Cita actualizada localmente');
                }
                Navigator.pop(context);
                _loadData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(appointment == null ? 'Cita creada' : 'Cita actualizada'),
                      backgroundColor: Colors.green,
                    ),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agenda de Citas'),
        backgroundColor: Colors.indigo[700],
        actions: [
          IconButton(
            icon: const Icon(Icons.sync, color: Colors.white),
            tooltip: 'Sincronizar con la nube',
            onPressed: _syncAppointments,
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today, color: Colors.white),
            tooltip: 'Seleccionar fecha',
            onPressed: _selectDate,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.indigo[50],
            child: Row(
              children: [
                const Icon(Icons.date_range, color: Colors.indigo),
                const SizedBox(width: 8),
                Text(
                  '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo),
                ),
                const Spacer(),
                Text(
                  '${_appointments.length} citas',
                  style: TextStyle(color: Colors.grey[600]),
                ),
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
                            Icon(Icons.event_busy, size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text('No hay citas para este día', style: TextStyle(color: Colors.grey[400], fontSize: 16)),
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
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(appointment.status).withOpacity(0.2),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(Icons.event, color: _getStatusColor(appointment.status)),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(appointment.clientName ?? 'Sin cliente', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                            const SizedBox(height: 4),
                                            Text('✂️ ${appointment.serviceName ?? 'Sin servicio'} - ${appointment.barberName ?? 'Sin barbero'}'),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '${appointment.appointmentDate.hour.toString().padLeft(2, '0')}:${appointment.appointmentDate.minute.toString().padLeft(2, '0')}',
                                                  style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600),
                                                ),
                                                const SizedBox(width: 16),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: _getStatusColor(appointment.status).withOpacity(0.2),
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: Text(
                                                    _getStatusText(appointment.status),
                                                    style: TextStyle(color: _getStatusColor(appointment.status), fontWeight: FontWeight.bold, fontSize: 12),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (appointment.notes != null) ...[
                                              const SizedBox(height: 4),
                                              Text('📝 ${appointment.notes}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
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
                                      if (appointment.status == 'pending') ...[
                                        _ActionButton(
                                          icon: Icons.check_circle,
                                          label: 'Confirmar',
                                          color: Colors.blue,
                                          onPressed: () => _updateAppointmentStatus(appointment, 'confirmed'),
                                        ),
                                      ],
                                      if (appointment.status == 'confirmed' || appointment.status == 'pending') ...[
                                        _ActionButton(
                                          icon: Icons.play_circle,
                                          label: 'En proceso',
                                          color: Colors.purple,
                                          onPressed: () => _updateAppointmentStatus(appointment, 'in_progress'),
                                        ),
                                      ],
                                      if (appointment.status != 'completed' && appointment.status != 'cancelled') ...[
                                        _ActionButton(
                                          icon: Icons.check,
                                          label: 'Completar',
                                          color: Colors.green,
                                          onPressed: () => _updateAppointmentStatus(appointment, 'completed'),
                                        ),
                                        _ActionButton(
                                          icon: Icons.cancel,
                                          label: 'Cancelar',
                                          color: Colors.red,
                                          onPressed: () => _deleteAppointment(appointment),
                                        ),
                                      ],
                                      _ActionButton(
                                        icon: Icons.edit,
                                        label: 'Editar',
                                        color: Colors.grey,
                                        onPressed: () => _showAppointmentDialog(appointment: appointment),
                                      ),
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
        backgroundColor: Colors.indigo[700],
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

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18, color: color),
      label: Text(label, style: TextStyle(color: color, fontSize: 12)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        side: BorderSide(color: color.withOpacity(0.5)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}