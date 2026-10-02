import 'package:isar/isar.dart';

part 'local_product.g.dart';

@collection
class LocalProduct {
  Id id = Isar.autoIncrement;
  String? remoteId;
  String name = '';
  String? description;
  double price = 0.0;
  int stock = 0;
  int minStock = 0;
  bool isActive = true;
  DateTime? lastSync;
}