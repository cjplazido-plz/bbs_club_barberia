class LocalTransaction {
  String? remoteId;
  String? clientId;
  String? barberId;
  double subtotal;
  double total;
  String paymentMethod;
  String status;
  List<LocalTransactionItem> items;
  DateTime createdAt;
  
  String? cashRegisterId;
  String? cashierId;
  String? cashierName;
  double cashReceived;
  double changeAmount;

  LocalTransaction({
    this.remoteId,
    this.clientId,
    this.barberId,
    this.subtotal = 0.0,
    this.total = 0.0,
    this.paymentMethod = 'cash',
    this.status = 'completed',
    this.items = const [],
    DateTime? createdAt,
    this.cashRegisterId,
    this.cashierId,
    this.cashierName,
    this.cashReceived = 0.0,
    this.changeAmount = 0.0,
  }) : createdAt = createdAt ?? DateTime.now();
}

class LocalTransactionItem {
  String type; // 'service' o 'product'
  String? serviceId;
  String serviceName; // <-- Cambiado a no nullable
  String? productId;
  String productName; // <-- Cambiado a no nullable
  double priceAtMoment;
  int quantity;
  String barberId; // <-- Cambiado a no nullable
  String barberName; // <-- Cambiado a no nullable
  double commissionEarned;

  LocalTransactionItem({
    this.type = 'service',
    this.serviceId,
    this.serviceName = '',
    this.productId,
    this.productName = '',
    this.priceAtMoment = 0.0,
    this.quantity = 1,
    this.barberId = '',
    this.barberName = '',
    this.commissionEarned = 0.0,
  });
}