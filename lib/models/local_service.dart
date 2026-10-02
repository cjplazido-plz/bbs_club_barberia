import 'package:isar/isar.dart';

part 'local_service.g.dart';

@collection
class LocalService {
  Id id = Isar.autoIncrement;
  String? remoteId;
  String name = '';
  double price = 0.0;
  int durationMinutes = 30;
  String commissionType = 'percentage';
  double commissionValue = 0.0;
  bool isActive = true;
  String? description;
}