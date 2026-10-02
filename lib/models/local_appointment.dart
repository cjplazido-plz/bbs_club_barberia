import 'package:isar/isar.dart';

part 'local_appointment.g.dart';

@collection
class LocalAppointment {
  Id id = Isar.autoIncrement;
  String? remoteId;
  String? clientId;
  String? clientName;
  String? clientPhone;
  String? barberId;
  String? barberName;
  String? serviceId;
  String? serviceName;
  double servicePrice = 0.0;
  DateTime appointmentDate = DateTime.now();
  String status = 'pending';
  String? notes;
  DateTime? lastSync;
}