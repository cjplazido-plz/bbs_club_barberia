class LocalAppointment {
  String? clientEmail;
  String? remoteId;
  String? clientId;
  String? clientName;
  String? clientPhone;
  String? barberId;
  String? barberName;
  String? serviceId;
  String? serviceName;
  double servicePrice;
  DateTime? startTime;
  DateTime? endTime;
  DateTime appointmentDate;
  String status;
  String? notes;
  DateTime? lastSync;

  LocalAppointment({
    this.clientEmail,
    this.remoteId,
    this.clientId,
    this.clientName,
    this.clientPhone,
    this.barberId,
    this.barberName,
    this.serviceId,
    this.serviceName,
    this.servicePrice = 0.0,
    this.startTime,
    this.endTime,
    DateTime? appointmentDate,
    this.status = 'pending',
    this.notes,
    this.lastSync,
  }) : appointmentDate = appointmentDate ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': remoteId,
      'client_id': clientId,
      'client_name': clientName,
      'client_email': clientEmail,
      'client_phone': clientPhone,
      'barber_id': barberId,
      'barber_name': barberName,
      'service_id': serviceId,
      'service_name': serviceName,
      'service_price': servicePrice,
      'start_time': startTime?.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'appointment_date': appointmentDate.toIso8601String(),
      'status': status,
      'notes': notes,
      'last_sync': lastSync?.toIso8601String(),
    };
  }

  factory LocalAppointment.fromMap(Map<String, dynamic> map) {
    return LocalAppointment(
      remoteId: map['id'],
      clientId: map['client_id'],
      clientName: map['client_name'],
      clientEmail: map['client_email'],
      clientPhone: map['client_phone'],
      barberId: map['barber_id'],
      barberName: map['barber_name'],
      serviceId: map['service_id'],
      serviceName: map['service_name'],
      servicePrice: (map['service_price'] as num?)?.toDouble() ?? 0.0,
      startTime: map['start_time'] != null ? DateTime.parse(map['start_time']) : null,
      endTime: map['end_time'] != null ? DateTime.parse(map['end_time']) : null,
      appointmentDate: map['appointment_date'] != null 
          ? DateTime.parse(map['appointment_date']) 
          : DateTime.now(),
      status: map['status'] ?? 'pending',
      notes: map['notes'],
      lastSync: map['last_sync'] != null ? DateTime.parse(map['last_sync']) : null,
    );
  }
}