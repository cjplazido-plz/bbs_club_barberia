// auth_service.dart - FIX 2AM
// REEMPLAZA a lib/services/auth_service.dart
// FIX: Antes userRole siempre devolvia 'admin' para todos.
// Ahora lee el rol real de profiles. Por defecto es 'barber' (el mas bajo),
// nunca 'admin', para no dar acceso de mas por error.

import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  // Cache del rol, se carga en getCurrentProfile()
  String _cachedRole = 'barber';
  String _cachedName = '';

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
      // Guarda el rol real para que userRole no mienta
      if (response['role'] != null) {
        _cachedRole = (response['role'] as String).trim();
      }
      if (response['full_name'] != null) {
        _cachedName = response['full_name'].toString();
      }
      return response;
    } catch (e) {
      print('Error al obtener perfil: $e');
      return null;
    }
  }

  // Carga el rol desde Supabase si aun no esta cargado
  Future<String> loadRole() async {
    final p = await getCurrentProfile();
    if (p != null && p['role'] != null) return p['role'].toString();
    return _cachedRole;
  }

  // Ahora devuelve el rol real, no 'admin' fijo
  String get userRole => _cachedRole;
  String get userName => _cachedName;

  bool get isAdmin => userRole == 'admin';
  bool get isCashier => userRole == 'cashier';
  bool get isBarber => userRole == 'barber';
  bool get isBarberCashier => userRole == 'barber_cashier';

  Future<void> signOut() async {
    _cachedRole = 'barber';
    _cachedName = '';
    await _client.auth.signOut();
  }

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;
}
