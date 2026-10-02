import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  // Obtener usuario actual
  User? get currentUser => _client.auth.currentUser;

  // Obtener perfil del usuario actual
  Future<Map<String, dynamic>?> getCurrentProfile() async {
    final user = currentUser;
    if (user == null) return null;

    final response = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .single();

    return response;
  }

  // Iniciar sesión
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // Registrar nuevo usuario
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    required String role,
  }) async {
    return await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName,
        'role': role,
      },
    );
  }

  // Cerrar sesión
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // Verificar si está logueado
  bool get isLoggedIn => currentUser != null;

  // Escuchar cambios de autenticación
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;
}