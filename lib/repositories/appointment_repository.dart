import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/local_appointment.dart';

class AppointmentRepository {
  final _client = Supabase.instance.client;

  Future<List<LocalAppointment>> getAllAppointments() async {
    final response = await _client.from('appointments').select().limit(10000);
    return List<Map<String, dynamic>>.from(response).map((data) {
      return LocalAppointment()
        ..remoteId = data['id']
        ..clientId = data['client_id']?.toString()
        ..clientName = data['client_name']
        ..clientPhone = data['client_phone']
        ..barberId = data['barber_id']?.toString()
        ..barberName = data['barber_name']
        ..serviceId = data['service_id']?.toString()
        ..serviceName = data['service_name']
        ..servicePrice = (data['service_price'] as num?)?.toDouble() ?? 0.0
        ..appointmentDate = DateTime.parse(data['appointment_date'].toString())
        ..status = data['status'] ?? 'pending'
        ..notes = data['notes'];
    }).toList();
  }

  Future<List<LocalAppointment>> getAppointmentsByDate(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    final response = await _client.from('appointments').select().gte('appointment_date', start.toUtc().toIso8601String()).lt('appointment_date', end.toUtc().toIso8601String()).limit(10000);
    return List<Map<String, dynamic>>.from(response).map((data) {
      return LocalAppointment()
        ..remoteId = data['id']
        ..clientId = data['client_id']?.toString()
        ..clientName = data['client_name']
        ..clientPhone = data['client_phone']
        ..barberId = data['barber_id']?.toString()
        ..barberName = data['barber_name']
        ..serviceId = data['service_id']?.toString()
        ..serviceName = data['service_name']
        ..servicePrice = (data['service_price'] as num?)?.toDouble() ?? 0.0
        ..appointmentDate = DateTime.parse(data['appointment_date'].toString())
        ..status = data['status'] ?? 'pending'
        ..notes = data['notes'];
    }).toList();
  }

  Future<void> createAppointment(LocalAppointment appointment) async {
    final id = appointment.remoteId ?? 'apt-${DateTime.now().millisecondsSinceEpoch}';
    appointment.remoteId = id;
    await _client.from('appointments').upsert({
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
    }, onConflict: 'id');
  }

  Future<void> updateAppointment(LocalAppointment appointment) async {
    await _client.from('appointments').upsert({
      'id': appointment.remoteId!,
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
    }, onConflict: 'id');
  }

  Future<void> deleteAppointment(String remoteId) async {
    await _client.from('appointments').delete().eq('id', remoteId);
  }
  
  Future<LocalAppointment?> findByRemoteId(String remoteId) async {
    final response = await _client.from('appointments').select().eq('id', remoteId).maybeSingle();
    if (response == null) return null;
    return LocalAppointment()
      ..remoteId = response['id']
      ..clientId = response['client_id']?.toString()
      ..clientName = response['client_name']
      ..clientPhone = response['client_phone']
      ..barberId = response['barber_id']?.toString()
      ..barberName = response['barber_name']
      ..serviceId = response['service_id']?.toString()
      ..serviceName = response['service_name']
      ..servicePrice = (response['service_price'] as num?)?.toDouble() ?? 0.0
      ..appointmentDate = DateTime.parse(response['appointment_date'].toString())
      ..status = response['status'] ?? 'pending'
      ..notes = response['notes'];
  }
}
