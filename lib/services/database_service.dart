class DatabaseService {
  // Isar ha sido eliminado. La aplicación ahora usa Supabase directamente.
  // Esta clase se mantiene por compatibilidad pero ya no inicializa nada local.
  
  static Future<void> init() async {
    print('✅ DatabaseService inicializado (Modo solo Supabase)');
  }
}