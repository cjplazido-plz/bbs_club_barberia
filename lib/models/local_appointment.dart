class LocalAppointment {
  String? remoteId;
  String? clientId;
  String? barberId;
  String? serviceId;
  DateTime? startTime;
  DateTime? endTime;
  String status;
  String? notes;
  
  // Propiedades adicionales que tu código espera
  String? clientName;
  String? clientPhone;
  String? barberName;
  String? serviceName;
  double servicePrice;
  DateTime appointmentDate;
  DateTime? lastSync;

  LocalAppointment({
    this.remoteId,
    this.clientId,
    this.barberId,
    this.serviceId,
    this.startTime,
    this.endTime,
    this.status = 'pending',
    this.notes,
    this.clientName,
    this.clientPhone,
    this.barberName,
    this.serviceName,
    this.servicePrice = 0.0,
    DateTime? appointmentDate,
    this.lastSync,
  }) : appointmentDate = appointmentDate ?? DateTime.now();
}