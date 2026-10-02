import 'package:isar/isar.dart';

part 'local_barber.g.dart';

@collection
class LocalBarber {
  Id id = Isar.autoIncrement;
  String? remoteId;
  String name = '';
  String? phone;
  double commissionValue = 0.0;
  double commissionRate = 0.0;
  bool isActive = true;
}