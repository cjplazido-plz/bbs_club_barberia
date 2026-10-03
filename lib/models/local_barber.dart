class LocalBarber {
  String? remoteId;
  String name;
  String? phone;
  double commissionValue;
  double commissionRate;
  bool isActive;

  LocalBarber({
    this.remoteId,
    this.name = '',
    this.phone,
    this.commissionValue = 0.0,
    this.commissionRate = 0.0,
    this.isActive = true,
  });
}