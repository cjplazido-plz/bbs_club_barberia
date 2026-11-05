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

class AppointmentsScreen extends StatefulWidget {
  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> with TickerProviderStateMixin {
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
  late AnimationController _mainController;

  @override
  void initState() {
    super.initState();
    _mainController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _loadData();
  }

  @override
  void dispose() {
    _mainController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; });
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
    _mainController.forward(from: 0);
  }

  Future<void> _sendWhatsAppNotification(LocalAppointment appointment, {String type = 'confirmed'}) async {
    if (appointment.clientPhone == null || appointment.clientPhone!.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El cliente no tiene teléfono'), backgroundColor: Colors.orange, behavior: SnackBarBehavior.floating));
      return;
    }
    String phone = appointment.clientPhone!.replaceAll(RegExp(r'[^0-9]'), '');
    if (phone.startsWith('0')) phone = phone.substring(1);
    if (!phone.startsWith('56') && phone.length == 9) phone = '56$phone';
    final dateStr = DateFormat('dd/MM/yyyy').format(appointment.appointmentDate);
    final timeStr = DateFormat('HH:mm').format(appointment.appointmentDate);
    String message;
    if (type == 'cancelled') {
      message = 'Hola ${appointment.clientName}, tu cita en BBS Club ha sido *CANCELADA*.\n\n📅 $dateStr ⏰ $timeStr ✂️ ${appointment.serviceName}';
    } else if (type == 'booking') {
      message = 'Hola ${appointment.clientName}, tu cita en BBS Club ha sido *REGISTRADA*.\n\n📅 $dateStr ⏰ $timeStr ✂️ ${appointment.serviceName} 💈 ${appointment.barberName}';
    } else {
      message = 'Hola ${appointment.clientName}, tu cita en BBS Club ha sido *CONFIRMADA*.\n\n📅 $dateStr ⏰ $timeStr ✂️ ${appointment.serviceName} 💈 ${appointment.barberName}';
    }
    final url = 'https://wa.me/$phone?text=${Uri.encodeComponent(message)}';
    try { if (await canLaunchUrl(Uri.parse(url))) await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication); } catch (e) {}
  }

  Future<void> _syncAppointments() async {
    if (_isLoading) return;
    setState(() { _isLoading = true; });
    try { await _loadData(); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Citas actualizadas'), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating)); } finally { if (mounted) setState(() { _isLoading = false; }); }
  }

  Future<void> _updateAppointmentStatus(LocalAppointment appointment, String newStatus) async {
    try {
      appointment.status = newStatus;
      await _appointmentRepo.updateAppointment(appointment);
      await Supabase.instance.client.from('appointments').update({'status': newStatus}).eq('id', appointment.remoteId!);
      if (newStatus == 'confirmed') await _sendWhatsAppNotification(appointment, type: 'confirmed');
      else if (newStatus == 'cancelled') await _sendWhatsAppNotification(appointment, type: 'cancelled');
      await _loadData();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text({'confirmed': '✅ Confirmada', 'in_progress': '🟡 En proceso', 'completed': '🎉 Completada', 'cancelled': '❌ Cancelada'}[newStatus] ?? 'Actualizado'), backgroundColor: newStatus == 'cancelled' ? Colors.red : Colors.green, behavior: SnackBarBehavior.floating));
    } catch (e) {}
  }

  Future<void> _deleteAppointment(LocalAppointment appointment) async {
    final confirm = await showDialog<bool>(context: context, builder: (c) {
      return AlertDialog(backgroundColor: const Color(0xFF1E293B), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), title: const Text('Cancelar cita', style: TextStyle(color: Colors.white)), content: Text('¿Cancelar cita de ${appointment.clientName}?', style: const TextStyle(color: Colors.white70)), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('No')), ElevatedButton(onPressed: () => Navigator.pop(c, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Sí, cancelar'))]);
    });
    if (confirm == true) await _updateAppointmentStatus(appointment, 'cancelled');
  }

  void _showAppointmentDialog({LocalAppointment? appointment}) {
    // Mantén lógica original pero con UI premium - simplificado para no romper
    final clientNameController = TextEditingController(text: appointment?.clientName ?? '');
    final serviceNameController = TextEditingController(text: appointment?.serviceName ?? '');
    final barberNameController = TextEditingController(text: appointment?.barberName ?? '');
    final notesController = TextEditingController(text: appointment?.notes ?? '');
    DateTime selectedDateTime = appointment?.appointmentDate ?? DateTime.now();

    showDialog(context: context, builder: (context) {
      return StatefulBuilder(builder: (context, setS) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(appointment == null ? 'Nueva Cita' : 'Editar Cita', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            _field(clientNameController, 'Cliente *', '👤'),
            const SizedBox(height: 12),
            _field(serviceNameController, 'Servicio *', '✂️'),
            const SizedBox(height: 12),
            _field(barberNameController, 'Barbero *', '💈'),
            const SizedBox(height: 12),
            InkWell(onTap: () async { final d = await showDatePicker(context: context, initialDate: selectedDateTime, firstDate: DateTime.now().subtract(const Duration(days: 30)), lastDate: DateTime.now().add(const Duration(days: 90)), builder: (c, child) => Theme(data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: Color(0xFF6366F1))), child: child!),); if (d != null) { final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(selectedDateTime)); if (t != null) setS(() => selectedDateTime = DateTime(d.year, d.month, d.day, t.hour, t.minute)); } }, child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white10)), child: Row(children: [const Text('📅  ', style: TextStyle(fontSize: 16)), Text(DateFormat('dd/MM/yyyy HH:mm').format(selectedDateTime), style: const TextStyle(color: Colors.white))]))),
            const SizedBox(height: 12),
            _field(notesController, 'Notas', '📝', maxLines: 2),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
            Container(decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF818CF8)]), borderRadius: BorderRadius.circular(10)), child: ElevatedButton(onPressed: () async { if (clientNameController.text.isEmpty) return; Navigator.pop(context); final newApp = LocalAppointment()..remoteId = appointment?.remoteId ?? 'app-${DateTime.now().millisecondsSinceEpoch}'..clientName = clientNameController.text..serviceName = serviceNameController.text..barberName = barberNameController.text..appointmentDate = selectedDateTime..notes = notesController.text..status = appointment?.status ?? 'pending'..clientPhone = _clients.firstWhere((c) => c.name == clientNameController.text, orElse: () => _clients.isNotEmpty ? _clients.first : LocalClient()..phone = '').phone; if (appointment == null) { await _appointmentRepo.createAppointment(newApp); await _sendWhatsAppNotification(newApp, type: 'booking'); } else { await _appointmentRepo.updateAppointment(newApp); } await _loadData(); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent), child: const Text('Guardar'))),
          ],
        );
      });
    });
  }

  Widget _field(TextEditingController c, String label, String icon, {int maxLines = 1}) {
    return TextField(controller: c, maxLines: maxLines, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: label, prefixText: '$icon  ', labelStyle: const TextStyle(color: Colors.white54, fontSize: 13), filled: true, fillColor: const Color(0xFF0F172A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.white10)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2))));
  }

  Color _getStatusColor(String status) {
    switch (status) { case 'pending': return const Color(0xFFF59E0B); case 'confirmed': return const Color(0xFF3B82F6); case 'in_progress': return const Color(0xFF8B5CF6); case 'completed': return const Color(0xFF10B981); case 'cancelled': return const Color(0xFFEF4444); default: return Colors.grey; }
  }
  String _getStatusText(String status) {
    switch (status) { case 'pending': return 'Pendiente'; case 'confirmed': return 'Confirmada'; case 'in_progress': return 'En proceso'; case 'completed': return 'Completada'; case 'cancelled': return 'Cancelada'; default: return status; }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: const Text('Agenda Premium', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [IconButton(icon: const Icon(Icons.sync_rounded, color: Colors.white), onPressed: _syncAppointments)],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF1E293B), Color(0xFF312E81)]), borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))]),
            child: Row(children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: const Text('📅', style: TextStyle(fontSize: 20))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(DateFormat('EEEE, dd MMM', 'es').format(_selectedDate), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)), Text('${_appointments.length} citas', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12))])),
              InkWell(onTap: () async { final d = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2023), lastDate: DateTime.now().add(const Duration(days: 60)), builder: (c, child) => Theme(data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: Color(0xFF6366F1))), child: child!),); if (d != null) { setState(() => _selectedDate = d); _loadData(); } }, child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: const Color(0xFF6366F1), borderRadius: BorderRadius.circular(20)), child: const Text('Cambiar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)))),
            ]),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
                : _appointments.isEmpty
                    ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('📅', style: TextStyle(fontSize: 64)), SizedBox(height: 16), Text('No hay citas este día', style: TextStyle(color: Colors.white54, fontSize: 16))]))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _appointments.length,
                        itemBuilder: (context, index) {
                          final appointment = _appointments[index];
                          return AnimatedBuilder(
                            animation: _mainController,
                            builder: (context, child) {
                              final delay = index * 0.06;
                              final anim = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _mainController, curve: Interval(delay, 0.6 + delay, curve: Curves.easeOutCubic)));
                              return FadeTransition(opacity: anim, child: SlideTransition(position: Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(anim), child: child));
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withOpacity(0.05)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))]),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Row(children: [
                                    Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: _getStatusColor(appointment.status).withOpacity(0.15), shape: BoxShape.circle, border: Border.all(color: _getStatusColor(appointment.status).withOpacity(0.3))), child: Icon(Icons.event_rounded, size: 20, color: _getStatusColor(appointment.status))),
                                    const SizedBox(width: 12),
                                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(appointment.clientName ?? 'Sin cliente', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis), const SizedBox(height: 2), Text('${appointment.serviceName ?? 'Servicio'} • ${appointment.barberName ?? 'Barbero'}', style: const TextStyle(fontSize: 12, color: Colors.white54), maxLines: 1, overflow: TextOverflow.ellipsis)])),
                                    Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: _getStatusColor(appointment.status).withOpacity(0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: _getStatusColor(appointment.status).withOpacity(0.3))), child: Text(_getStatusText(appointment.status), style: TextStyle(color: _getStatusColor(appointment.status), fontWeight: FontWeight.bold, fontSize: 10))),
                                  ]),
                                  const SizedBox(height: 12),
                                  Row(children: [
                                    Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(10)), child: Row(children: [const Icon(Icons.schedule_rounded, size: 14, color: Colors.white54), const SizedBox(width: 4), Text('${appointment.appointmentDate.hour.toString().padLeft(2, '0')}:${appointment.appointmentDate.minute.toString().padLeft(2, '0')}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))])),
                                    if (appointment.notes != null && appointment.notes!.isNotEmpty) ...[const SizedBox(width: 8), Expanded(child: Text(appointment.notes!, style: const TextStyle(color: Colors.white38, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis))],
                                  ]),
                                  const SizedBox(height: 12),
                                  Wrap(spacing: 8, runSpacing: 8, children: [
                                    if (appointment.status == 'pending') _ActionButton(icon: Icons.check_circle_rounded, label: 'Confirmar', color: const Color(0xFF3B82F6), onPressed: () => _updateAppointmentStatus(appointment, 'confirmed')),
                                    if (appointment.status == 'confirmed' || appointment.status == 'pending') _ActionButton(icon: Icons.play_circle_rounded, label: 'Proceso', color: const Color(0xFF8B5CF6), onPressed: () => _updateAppointmentStatus(appointment, 'in_progress')),
                                    if (appointment.status != 'completed' && appointment.status != 'cancelled') ...[
                                      _ActionButton(icon: Icons.task_alt_rounded, label: 'Completar', color: const Color(0xFF10B981), onPressed: () => _updateAppointmentStatus(appointment, 'completed')),
                                      _ActionButton(icon: Icons.cancel_rounded, label: 'Cancelar', color: const Color(0xFFEF4444), onPressed: () => _deleteAppointment(appointment)),
                                    ],
                                    _ActionButton(icon: Icons.edit_rounded, label: 'Editar', color: Colors.white54, onPressed: () => _showAppointmentDialog(appointment: appointment)),
                                  ]),
                                ]),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: Container(decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF818CF8)]), borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 6))]), child: FloatingActionButton(onPressed: () => _showAppointmentDialog(), backgroundColor: Colors.transparent, elevation: 0, child: const Icon(Icons.add_rounded, color: Colors.white, size: 28))),
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
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.3))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 14, color: color), const SizedBox(width: 6), Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold))]),
      ),
    );
  }
}
