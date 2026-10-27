import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  User? get currentUser => _client.auth.currentUser;

  Future<Map<String, dynamic>?> getCurrentProfile() async {
    final user = currentUser;
    if (user == null) return null;

    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();
      return response;
    } catch (e) {
      print('Error al obtener perfil: $e');
      return null;
    }
  }

  String get userRole {
    return 'admin'; // Default temporal
  }

  bool get isAdmin => userRole == 'admin';
  bool get isCashier => userRole == 'cashier';
  bool get isBarber => userRole == 'barber';

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;
}