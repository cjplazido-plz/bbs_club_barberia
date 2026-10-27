class LocalClient {
  String? remoteId;
  String name;
  String? phone;
  String? notes;
  String? email;
  int totalVisits;
  double totalSpent;

  LocalClient({
    this.remoteId,
    this.name = '',
    this.phone,
    this.notes,
    this.email,
    this.totalVisits = 0,
    this.totalSpent = 0.0,
  });
}