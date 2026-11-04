import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/local_appointment.dart';

class AppointmentRepository {
  final _client = Supabase.instance.client;

  Future<List<LocalAppointment>> getAllAppointments() async {
    final response = await _client.from('appointments').select();
    return List<Map<String, dynamic>>.from(response).map((data) {
      return LocalAppointment()
        ..remoteId = data['id']
        ..clientId = data['client_id']
        ..clientName = data['client_name']
        ..clientPhone = data['client_phone']
        ..barberId = data['barber_id']
        ..barberName = data['barber_name']
        ..serviceId = data['service_id']
        ..serviceName = data['service_name']
        ..servicePrice = (data['service_price'] as num?)?.toDouble() ?? 0.0
        ..appointmentDate = DateTime.parse(data['appointment_date'])
        ..status = data['status'] ?? 'pending'
        ..notes = data['notes'];
    }).toList();
  }

  Future<List<LocalAppointment>> getAppointmentsByDate(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    final response = await _client
        .from('appointments')
        .select()
        .gte('appointment_date', start.toIso8601String())
        .lt('appointment_date', end.toIso8601String());
    return List<Map<String, dynamic>>.from(response).map((data) {
      return LocalAppointment()
        ..remoteId = data['id']
        ..clientId = data['client_id']
        ..clientName = data['client_name']
        ..clientPhone = data['client_phone']
        ..barberId = data['barber_id']
        ..barberName = data['barber_name']
        ..serviceId = data['service_id']
        ..serviceName = data['service_name']
        ..servicePrice = (data['service_price'] as num?)?.toDouble() ?? 0.0
        ..appointmentDate = DateTime.parse(data['appointment_date'])
        ..status = data['status'] ?? 'pending'
        ..notes = data['notes'];
    }).toList();
  }

  Future<LocalAppointment?> findByRemoteId(String remoteId) async {
    final response = await _client
        .from('appointments')
        .select()
        .eq('id', remoteId)
        .maybeSingle();
    if (response == null) return null;
    return LocalAppointment()
      ..remoteId = response['id']
      ..clientId = response['client_id']
      ..clientName = response['client_name']
      ..clientPhone = response['client_phone']
      ..barberId = response['barber_id']
      ..barberName = response['barber_name']
      ..serviceId = response['service_id']
      ..serviceName = response['service_name']
      ..servicePrice = (response['service_price'] as num?)?.toDouble() ?? 0.0
      ..appointmentDate = DateTime.parse(response['appointment_date'])
      ..status = response['status'] ?? 'pending'
      ..notes = response['notes'];
  }

  Future<void> createAppointment(LocalAppointment appointment) async {
    final id = appointment.remoteId ?? 'apt-${DateTime.now().millisecondsSinceEpoch}';
    appointment.remoteId = id;
    await _client.from('appointments').insert({
      'id': id,
      'client_id': appointment.clientId ?? '',
      'client_name': appointment.clientName ?? '',
      'client_phone': appointment.clientPhone ?? '',
      'barber_id': appointment.barberId ?? '',
      'barber_name': appointment.barberName ?? '',
      'service_id': appointment.serviceId ?? '',
      'service_name': appointment.serviceName ?? '',
      'service_price': appointment.servicePrice,
      'appointment_date': appointment.appointmentDate.toIso8601String(),
      'status': appointment.status,
      'notes': appointment.notes,
    });
    print('✅ Cita creada: ${appointment.clientName}');
  }

  Future<void> updateAppointment(LocalAppointment appointment) async {
    await _client.from('appointments')
        .update({
          'client_id': appointment.clientId ?? '',
          'client_name': appointment.clientName ?? '',
          'client_phone': appointment.clientPhone ?? '',
          'barber_id': appointment.barberId ?? '',
          'barber_name': appointment.barberName ?? '',
          'service_id': appointment.serviceId ?? '',
          'service_name': appointment.serviceName ?? '',
          'service_price': appointment.servicePrice,
          'appointment_date': appointment.appointmentDate.toIso8601String(),
          'status': appointment.status,
          'notes': appointment.notes,
        })
        .eq('id', appointment.remoteId!);
    print('✅ Cita actualizada: ${appointment.clientName}');
  }

  Future<void> deleteAppointment(String remoteId) async {
    await _client.from('appointments').delete().eq('id', remoteId);
    print('✅ Cita eliminada: $remoteId');
  }
}