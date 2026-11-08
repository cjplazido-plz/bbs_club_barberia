// lib/models/local_transaction.dart - FINAL DEFINITIVO v2 - compila con tu pos_screen + fix null
class LocalTransactionItem {
  String type = 'service';
  String serviceId = '';
  String serviceName = '';
  String productId = '';
  String productName = '';
  String barberId = '';
  String barberName = '';
  double priceAtMoment = 0;
  int quantity = 1;
  double commissionEarned = 0;

  // Hierba Viva granel
  String tipoVenta = 'unidad';
  double? gramos;
  double? precioKg;

  String get tipo => tipoVenta;
  set tipo(String v) => tipoVenta = v;
  String get id => serviceId.isNotEmpty ? serviceId : productId;

  LocalTransactionItem();
}

class LocalTransaction {
  String _remoteId = '';
  String _id = '';
  String folio = '';
  String cashRegisterId = 'caja-001';
  String cashierId = 'user-001';
  String cashierName = 'Sistema';
  String clientName = 'Consumidor Final';
  String turnoId = '';
  double subtotal = 0;
  double total = 0;
  String paymentMethod = 'cash';
  double cashReceived = 0;
  double changeAmount = 0;
  List<LocalTransactionItem> items = [];
  DateTime createdAt = DateTime.now();
  String status = 'completed';
  List<Map<String, dynamic>>? mixtoDetail;
  List<Map<String, dynamic>>? mixtoDetalle;
  dynamic mixto_detalle;

  LocalTransaction();

  String get remoteId => _remoteId.isNotEmpty ? _remoteId : _id;
  set remoteId(String v) { _remoteId = v; _id = v; if (folio.isEmpty) folio = v; }

  String get id => _id.isNotEmpty ? _id : _remoteId;
  set id(String v) { _id = v; _remoteId = v; if (folio.isEmpty) folio = v; }

  String get transactionId => remoteId;
}
