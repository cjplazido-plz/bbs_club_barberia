import 'package:isar/isar.dart';

part 'local_client.g.dart';

@collection
class LocalClient {
  Id id = Isar.autoIncrement;
  String? remoteId;
  String name = '';
  String? phone;
  String? email;
  String? notes;
  int totalVisits = 0;
  double totalSpent = 0.0;
  DateTime? updatedAt;
}