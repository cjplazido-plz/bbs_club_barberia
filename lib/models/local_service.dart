class LocalService {
  String? remoteId;
  String name;
  double price;
  int durationMinutes;
  bool isActive;
  String commissionType;
  double commissionValue;

  LocalService({
    this.remoteId,
    this.name = '',
    this.price = 0.0,
    this.durationMinutes = 30,
    this.isActive = true,
    this.commissionType = 'percentage',
    this.commissionValue = 0.0,
  });
}