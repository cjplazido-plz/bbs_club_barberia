import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

class AppointmentsScreen extends StatefulWidget {
  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  List<Map<String, dynamic>> _appointments = [];
  List<DateTime> _daysWithAppointments = [];
  bool _isLoading = true;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadAppointments();
    _loadAppointmentDates();
  }

  Future<void> _loadAppointmentDates() async {
    try {
      final startOfMonth = DateTime(_focusedDay.year, _focusedDay.month, 1);
      final endOfMonth = DateTime(_focusedDay.year, _focusedDay.month + 1, 0, 23, 59, 59);

      final response = await Supabase.instance.client
          .from('appointments')
          .select('appointment_date')
          .gte('appointment_date', startOfMonth.toIso8601String())
          .lte('appointment_date', endOfMonth.toIso8601String())
          .neq('status', 'cancelled');

      setState(() {
        _daysWithAppointments = (response as List)
            .map((r) => DateTime.parse(r['appointment_date']))
            .toList();
      });
    } catch (e) {
      print('Error al cargar fechas de citas: $e');
    }
  }

  Future<void> _loadAppointments() async {
    setState(() => _isLoading = true);
    try {
      final dayStart = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
      final dayEnd = dayStart.add(const Duration(days: 1));

      final response = await Supabase.instance.client
          .from('appointments')
          .select('*')
          .gte('appointment_date', dayStart.toIso8601String())
          .lt('appointment_date', dayEnd.toIso8601String())
          .neq('status', 'cancelled')
          .order('appointment_time', ascending: true);

      setState(() {
        _appointments = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      print('Error al cargar citas: $e');
      setState(() => _isLoading = false);
    }
  }

  bool _hasAppointment(DateTime day) {
    return _daysWithAppointments.any((d) =>
        d.year == day.year && d.month == day.month && d.day == day.day);
  }

  String _formatTime(String? time) {
    if (time == null || time.isEmpty) return '--:--';
    try {
      final parts = time.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
    } catch (e) {
      return time;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'confirmed': return Colors.green;
      case 'pending': return Colors.orange;
      case 'completed': return Colors.blue;
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'confirmed': return 'Confirmada';
      case 'pending': return 'Pendiente';
      case 'completed': return 'Completada';
      case 'cancelled': return 'Cancelada';
      default: return status;
    }
  }

  void _showAppointmentDialog({Map<String, dynamic>? appointment}) {
    final clientController = TextEditingController(text: appointment?['client_name'] ?? '');
    final barberController = TextEditingController(text: appointment?['barber_name'] ?? '');
    final serviceController = TextEditingController(text: appointment?['service_name'] ?? '');
    final notesController = TextEditingController(text: appointment?['notes'] ?? '');
    String status = appointment?['status'] ?? 'pending';
    TimeOfDay selectedTime = appointment?['appointment_time'] != null
        ? _parseTimeOfDay(appointment!['appointment_time'])
        : TimeOfDay.now();
    DateTime selectedDate = appointment?['appointment_date'] != null
        ? DateTime.parse(appointment!['appointment_date'])
        : _selectedDay;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(appointment == null ? 'Nueva Cita' : 'Editar Cita'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: clientController,
                  decoration: const InputDecoration(labelText: 'Cliente *'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: barberController,
                  decoration: const InputDecoration(labelText: 'Barbero *'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: serviceController,
                  decoration: const InputDecoration(labelText: 'Servicio *'),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Fecha: ${DateFormat('dd/MM/yyyy').format(selectedDate)}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Hora: ${selectedTime.format(context)}'),
                  trailing: const Icon(Icons.access_time),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: selectedTime,
                    );
                    if (picked != null) {
                      setDialogState(() => selectedTime = picked);
                    }
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: status,
                  decoration: const InputDecoration(labelText: 'Estado'),
                  items: const [
                    DropdownMenuItem(value: 'pending', child: Text('Pendiente')),
                    DropdownMenuItem(value: 'confirmed', child: Text('Confirmada')),
                    DropdownMenuItem(value: 'completed', child: Text('Completada')),
                    DropdownMenuItem(value: 'cancelled', child: Text('Cancelada')),
                  ],
                  onChanged: (v) => setDialogState(() => status = v ?? 'pending'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(labelText: 'Notas'),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (clientController.text.trim().isEmpty ||
                    barberController.text.trim().isEmpty ||
                    serviceController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cliente, barbero y servicio son obligatorios'), backgroundColor: Colors.red),
                  );
                  return;
                }

                final appointmentData = {
                  'client_name': clientController.text.trim(),
                  'barber_name': barberController.text.trim(),
                  'service_name': serviceController.text.trim(),
                  'appointment_date': DateFormat('yyyy-MM-dd').format(selectedDate),
                  'appointment_time': '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
                  'status': status,
                  'notes': notesController.text.trim(),
                };

                try {
                  if (appointment == null) {
                    await Supabase.instance.client.from('appointments').insert({
                      ...appointmentData,
                      'id': 'apt-${DateTime.now().millisecondsSinceEpoch}',
                    });
                  } else {
                    await Supabase.instance.client
                        .from('appointments')
                        .update(appointmentData)
                        .eq('id', appointment['id']);
                  }
                  Navigator.pop(context);
                  await _loadAppointments();
                  await _loadAppointmentDates();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(appointment == null ? 'Cita creada' : 'Cita actualizada'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
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

  TimeOfDay _parseTimeOfDay(String time) {
    try {
      final parts = time.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (e) {
      return TimeOfDay.now();
    }
  }

  Future<void> _deleteAppointment(Map<String, dynamic> appointment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text('¿Eliminar la cita de ${appointment['client_name']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await Supabase.instance.client
            .from('appointments')
            .delete()
            .eq('id', appointment['id']);
        await _loadAppointments();
        await _loadAppointmentDates();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cita eliminada'), backgroundColor: Colors.orange),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.event, size: 22),
            SizedBox(width: 8),
            Expanded(child: Text('Agenda de Citas', overflow: TextOverflow.ellipsis)),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: () {
              _loadAppointments();
              _loadAppointmentDates();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Header con fecha seleccionada
          Container(
            padding: const EdgeInsets.all(12),
            color: isDark ? const Color(0xFF1E293B) : Colors.indigo[50],
            child: Row(
              children: [
                Icon(Icons.calendar_today, size: 20, color: isDark ? const Color(0xFF818CF8) : Colors.indigo[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    DateFormat('dd/MM/yyyy').format(_selectedDay),
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black87),
                  ),
                ),
                Text(
                  '${_appointments.length} citas',
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
              ],
            ),
          ),

          // Calendario
          Card(
            margin: const EdgeInsets.all(8),
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: TableCalendar(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
                _loadAppointments();
              },
              onFormatChanged: (format) {
                setState(() {
                  _calendarFormat = format;
                });
              },
              onPageChanged: (focusedDay) {
                setState(() {
                  _focusedDay = focusedDay;
                });
                _loadAppointmentDates();
              },
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: isDark ? const Color(0xFF312E81) : Colors.indigo[100],
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: const Color(0xFF6366F1),
                  shape: BoxShape.circle,
                ),
                selectedTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                todayTextStyle: TextStyle(color: isDark ? Colors.white : Colors.indigo[700], fontWeight: FontWeight.bold),
                defaultTextStyle: TextStyle(color: isDark ? Colors.grey[300] : Colors.black87),
                weekendTextStyle: TextStyle(color: isDark ? Colors.red[300] : Colors.red[700]),
              ),
              headerStyle: HeaderStyle(
                formatButtonDecoration: BoxDecoration(
                  color: isDark ? const Color(0xFF312E81) : Colors.indigo[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                formatButtonTextStyle: TextStyle(color: isDark ? Colors.white : Colors.indigo[700]),
                titleTextStyle: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
                leftChevronIcon: Icon(Icons.chevron_left, color: isDark ? Colors.white : Colors.indigo[700]),
                rightChevronIcon: Icon(Icons.chevron_right, color: isDark ? Colors.white : Colors.indigo[700]),
              ),
              calendarBuilders: CalendarBuilders(
                defaultBuilder: (context, date, _) {
                  final hasAppointment = _hasAppointment(date);
                  final isSelected = isSameDay(_selectedDay, date);
                  final isToday = isSameDay(DateTime.now(), date);

                  return Container(
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF6366F1)
                          : (hasAppointment ? Colors.green.withOpacity(0.3) : null),
                      shape: BoxShape.circle,
                      border: isToday && !isSelected ? Border.all(color: const Color(0xFF6366F1), width: 1.5) : null,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${date.day}',
                            style: TextStyle(
                              color: isSelected ? Colors.white : (hasAppointment ? Colors.green[700] : (isDark ? Colors.grey[300] : Colors.black87)),
                              fontWeight: isSelected ? FontWeight.bold : (hasAppointment ? FontWeight.bold : null),
                            ),
                          ),
                          if (hasAppointment)
                            Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.white : Colors.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Lista de citas del día
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
                            Text(
                              'No hay citas para el ${DateFormat('dd/MM/yyyy').format(_selectedDay)}',
                              style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[400], fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        itemCount: _appointments.length,
                        itemBuilder: (context, index) {
                          final appointment = _appointments[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              leading: CircleAvatar(
                                backgroundColor: _getStatusColor(appointment['status'] ?? '').withOpacity(0.2),
                                child: Text(
                                  _formatTime(appointment['appointment_time']).substring(0, 2),
                                  style: TextStyle(fontWeight: FontWeight.bold, color: _getStatusColor(appointment['status'] ?? '')),
                                ),
                              ),
                              title: Text(
                                appointment['client_name'] ?? 'Sin cliente',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : Colors.black87),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.person, size: 14, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          '${appointment['barber_name'] ?? 'Sin barbero'} · ${appointment['service_name'] ?? 'Sin servicio'}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.access_time, size: 14, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                                      const SizedBox(width: 4),
                                      Text(
                                        _formatTime(appointment['appointment_time']),
                                        style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                                      ),
                                      const SizedBox(width: 12),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(appointment['status'] ?? '').withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          _getStatusLabel(appointment['status'] ?? ''),
                                          style: TextStyle(fontSize: 10, color: _getStatusColor(appointment['status'] ?? ''), fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.amber, size: 20),
                                    onPressed: () => _showAppointmentDialog(appointment: appointment),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                                    onPressed: () => _deleteAppointment(appointment),
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