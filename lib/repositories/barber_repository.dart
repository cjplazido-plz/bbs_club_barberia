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
        ..remoteId = data['id'] // <-- Ahora siempre será el UUID real
        ..name = data['name'] ?? ''
        ..phone = data['phone']
        ..commissionValue = (data['commission'] as num?)?.toDouble() ?? 0.0
        ..commissionRate = (data['commission_rate'] as num?)?.toDouble() ?? (data['commission'] as num?)?.toDouble() ?? 0.0
        ..isActive = data['is_active'] ?? true;
    }).toList();
  }

  Future<void> createBarber(LocalBarber barber) async {
    // FIX: Quitamos el ID inventado. No enviamos 'id', dejamos que Supabase lo cree.
    final response = await _client.from('barbers').insert({
      'name': barber.name,
      'phone': barber.phone,
      'commission': barber.commissionValue,
      'commission_rate': barber.commissionRate,
      'is_active': true,
    }).select().single();
    
    // Asignamos el UUID real generado por Supabase a nuestro objeto local
    barber.remoteId = response['id']; 
    print('✅ Barbero creado con UUID real: ${barber.remoteId}');
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