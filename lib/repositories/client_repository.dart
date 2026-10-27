import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/local_client.dart';

class ClientRepository {
  final _client = Supabase.instance.client;

  Future<List<LocalClient>> getAllClients() async {
    final response = await _client.from('clients').select();
    
    // ✅ Filtrar duplicados por ID
    final seen = <String>{};
    final unique = <Map<String, dynamic>>[];
    for (final data in List<Map<String, dynamic>>.from(response)) {
      final id = data['id']?.toString() ?? '';
      if (id.isNotEmpty && !seen.contains(id)) {
        seen.add(id);
        unique.add(data);
      }
    }
    
    return unique.map((data) {
      return LocalClient()
        ..remoteId = data['id']
        ..name = data['name'] ?? ''
        ..phone = data['phone']
        ..email = data['email']
        ..notes = data['notes']
        ..totalVisits = (data['visits'] as int?) ?? 0
        ..totalSpent = (data['total_spent'] as num?)?.toDouble() ?? 0.0;
    }).toList();
  }

  Future<LocalClient> createClient({
    required String name,
    String? phone,
    String? email,
    String? notes,
  }) async {
    final id = 'client-${DateTime.now().millisecondsSinceEpoch}';
    final client = LocalClient()
      ..remoteId = id
      ..name = name
      ..phone = phone
      ..email = email
      ..notes = notes;
    
    await _client.from('clients').insert({
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'notes': notes,
      'visits': 0,
      'total_spent': 0.0,
    });
    
    print('✅ Cliente creado: $name');
    return client;
  }

  Future<LocalClient> updateClient(LocalClient client) async {
    await _client.from('clients')
        .update({
          'name': client.name,
          'phone': client.phone,
          'email': client.email,
          'notes': client.notes,
        })
        .eq('id', client.remoteId!);
    
    print('✅ Cliente actualizado: ${client.name}');
    return client;
  }

  Future<void> deleteClient(String remoteId) async {
    await _client.from('clients').delete().eq('id', remoteId);
    print('✅ Cliente eliminado: $remoteId');
  }

  Future<void> incrementVisits(String clientId, double amount) async {
    try {
      final response = await _client
          .from('clients')
          .select('visits, total_spent')
          .eq('id', clientId)
          .single();
      final visits = (response['visits'] as int?) ?? 0;
      final total = (response['total_spent'] as num?)?.toDouble() ?? 0.0;
      await _client.from('clients')
          .update({'visits': visits + 1, 'total_spent': total + amount})
          .eq('id', clientId);
    } catch (e) {
      print('⚠️ Error incrementVisits: $e');
    }
  }
}