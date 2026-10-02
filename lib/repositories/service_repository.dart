import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/local_service.dart';

class ServiceRepository {
  final _client = Supabase.instance.client;

  Future<List<LocalService>> getAllServices() async {
    final response = await _client.from('services').select();
    return List<Map<String, dynamic>>.from(response).map((data) {
      return LocalService()
        ..remoteId = data['id']
        ..name = data['name'] ?? ''
        ..price = (data['price'] as num?)?.toDouble() ?? 0.0
        ..durationMinutes = (data['duration_minutes'] as int?) ?? 30
        ..commissionType = data['commission_type'] ?? 'percentage'
        ..commissionValue = (data['commission'] as num?)?.toDouble() ?? 0.0
        ..isActive = data['is_active'] ?? true;
    }).toList();
  }

  Future<void> createService(LocalService service) async {
    final id = service.remoteId ?? 'srv-${DateTime.now().millisecondsSinceEpoch}';
    service.remoteId = id;
    await _client.from('services').insert({
      'id': id,
      'name': service.name,
      'price': service.price,
      'duration_minutes': service.durationMinutes,
      'commission_type': service.commissionType,
      'commission': service.commissionValue,
      'is_active': true,
    });
    print('✅ Servicio creado: ${service.name}');
  }

  Future<void> updateService(LocalService service) async {
    await _client.from('services')
        .update({
          'name': service.name,
          'price': service.price,
          'duration_minutes': service.durationMinutes,
          'commission_type': service.commissionType,
          'commission': service.commissionValue,
        })
        .eq('id', service.remoteId!);
    print('✅ Servicio actualizado: ${service.name}');
  }

  Future<void> deleteService(String remoteId) async {
    await _client.from('services')
        .update({'is_active': false})
        .eq('id', remoteId);
    print('✅ Servicio eliminado: $remoteId');
  }
}