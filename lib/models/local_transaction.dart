import 'package:isar/isar.dart';

part 'local_transaction.g.dart';

@collection
class LocalTransaction {
  Id id = Isar.autoIncrement;
  String? remoteId;
  String cashRegisterId = '';
  String cashierId = '';
  String cashierName = '';
  double subtotal = 0.0;
  double total = 0.0;
  String paymentMethod = 'cash';
  String status = 'completed';
  DateTime createdAt = DateTime.now();
  double cashReceived = 0.0;  // ✅ NUEVO - Monto recibido en efectivo
  double changeAmount = 0.0;  // ✅ NUEVO - Cambio a devolver

  List<LocalTransactionItem> items = [];
}

@embedded
class LocalTransactionItem {
  String type = 'service';
  String serviceId = '';
  String serviceName = '';
  String? productId;
  String? productName;
  String barberId = '';
  String barberName = '';
  double priceAtMoment = 0.0;
  int quantity = 1;
  double commissionEarned = 0.0;
}