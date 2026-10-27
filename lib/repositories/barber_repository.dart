import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/local_barber.dart';

class BarberRepository {
  final _client = Supabase.instance.client;

  Future<List<LocalBarber>> getAllBarbers() async {
    final response = await _client.from('barbers').select();
    final seen = <String>{};
    final unique = <Map<String, dynamic>>[];
    for (final data in List<Map<String, dynamic>>.from(response)) {
      final id = data['id']?.toString() ?? '';
      if (!seen.contains(id)) {
        seen.add(id);
        unique.add(data);
      }
    }
    return unique.map((data) {
      return LocalBarber()
        ..remoteId = data['id']
        ..name = data['name'] ?? ''
        ..phone = data['phone']
        ..commissionValue = (data['commission'] as num?)?.toDouble() ?? 0.0
        ..commissionRate = (data['commission_rate'] as num?)?.toDouble() ?? (data['commission'] as num?)?.toDouble() ?? 0.0
        ..isActive = data['is_active'] ?? true;
    }).toList();
  }

  Future<void> createBarber(LocalBarber barber) async {
    final id = barber.remoteId ?? 'barber-${DateTime.now().millisecondsSinceEpoch}';
    barber.remoteId = id;
    await _client.from('barbers').insert({
      'id': id,
      'name': barber.name,
      'phone': barber.phone,
      'commission': barber.commissionValue,
      'commission_rate': barber.commissionRate,
      'is_active': true,
    });
    print('✅ Barbero creado: ${barber.name}');
  }

  Future<void> updateBarber(LocalBarber barber) async {
    await _client.from('barbers')
        .update({
          'name': barber.name,
          'phone': barber.phone,
          'commission': barber.commissionValue,
          'commission_rate': barber.commissionRate,
        })
        .eq('id', barber.remoteId!);
    print('✅ Barbero actualizado: ${barber.name}');
  }

  Future<void> deleteBarber(String remoteId) async {
    await _client.from('barbers')
        .update({'is_active': false})
        .eq('id', remoteId);
    print('✅ Barbero eliminado: $remoteId');
  }
}