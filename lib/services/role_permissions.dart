import 'package:supabase_flutter/supabase_flutter.dart';

class BbsPerm {
  static const sell = 'sell';
  static const viewAgenda = 'viewAgenda';
  static const createEditAppointment = 'createEditAppointment';
  static const confirmCancel = 'confirmCancel';
  static const blockHours = 'blockHours';
  static const viewClients = 'viewClients';
  static const createEditClient = 'createEditClient';
  static const deleteClient = 'deleteClient';
  static const viewCommissions = 'viewCommissions';
  static const markPaid = 'markPaid';
  static const viewClosure = 'viewClosure';
  static const viewHistory = 'viewHistory';
  static const viewReports = 'viewReports'; 
  static const viewUsers = 'viewUsers';
  static const manageRoles = 'manageRoles';
  static const viewSettings = 'viewSettings';

  // Eliminamos viewPos y cancelSale (Anular/Editar Pago)
  static const all = [
    sell, viewAgenda, createEditAppointment, confirmCancel, blockHours,
    viewClients, createEditClient, deleteClient, viewCommissions, markPaid,
    viewClosure, viewHistory, viewReports, viewUsers, manageRoles, viewSettings,
  ];

  static const labels = {
    sell: 'Vender (cobrar)',
    viewAgenda: 'Ver Agenda',
    createEditAppointment: 'Crear-Editar Cita',
    confirmCancel: 'Confirmar-Cancelar Cita',
    blockHours: 'Bloquear Horas',
    viewClients: 'Ver Clientes',
    createEditClient: 'Crear-Editar Cliente',
    deleteClient: 'Eliminar Cliente',
    viewCommissions: 'Ver Comisiones',
    markPaid: 'Marcar Pagado',
    viewClosure: 'Ver Cierre-Cuadratura',
    viewHistory: 'Ver Historial',
    viewReports: 'Ver Reportes', 
    viewUsers: 'Ver Usuarios',
    manageRoles: 'Roles',
    viewSettings: 'Ver Configuración',
  };
}

class RolePermissions {
  static const Map<String, Set<String>> defaults = {
    'admin': {
      BbsPerm.sell, BbsPerm.viewAgenda, BbsPerm.createEditAppointment,
      BbsPerm.confirmCancel, BbsPerm.blockHours, BbsPerm.viewClients, BbsPerm.createEditClient,
      BbsPerm.deleteClient, BbsPerm.viewCommissions, BbsPerm.markPaid, BbsPerm.viewClosure,
      BbsPerm.viewHistory, BbsPerm.viewReports, BbsPerm.viewUsers,
      BbsPerm.manageRoles, BbsPerm.viewSettings,
    },
    'cashier': {
      BbsPerm.sell, BbsPerm.viewAgenda, BbsPerm.createEditAppointment,
      BbsPerm.confirmCancel, BbsPerm.viewClients, BbsPerm.viewClosure, BbsPerm.viewHistory,
    },
    'barber': {
      BbsPerm.viewAgenda, BbsPerm.viewClients, BbsPerm.viewCommissions, BbsPerm.viewHistory,
    },
    'barber_cashier': {
      BbsPerm.sell, BbsPerm.viewAgenda, BbsPerm.createEditAppointment,
      BbsPerm.confirmCancel, BbsPerm.viewClients, BbsPerm.viewCommissions, BbsPerm.viewClosure,
      BbsPerm.viewHistory,
    },
  };

  static const Map<String, String> roleNames = {
    'admin': 'Administrador',
    'cashier': 'Cajero',
    'barber': 'Barbero',
    'barber_cashier': 'Barbero/Cajero',
  };

  static const Map<String, int> roleColors = {
    'admin': 0xFF6C5CE7,
    'cashier': 0xFF3B82F6,
    'barber': 0xFFF59E0B,
    'barber_cashier': 0xFF10B981,
  };

  static Map<String, Set<String>> _custom = {};

  static Set<String> getPermissions(String role) {
    final r = role.trim().toLowerCase();
    if (_custom.containsKey(r)) {
      // FIX: Especificar <String> para evitar el error de tipo dynamic
      final perms = Set<String>.from(_custom[r]!);
      perms.remove('none'); // Quita el permiso fantasma
      return perms;
    }
    // FIX: Especificar <String> aquí también
    return Set<String>.from(defaults[r] ?? defaults['cashier']!);
  }
  
  static bool can(String? role, String perm) {
    final r = (role ?? '').trim().toLowerCase();
    if (r == 'admin') return true;
    if (_custom.containsKey(r)) return _custom[r]!.contains(perm);
    return defaults[r]?.contains(perm) ?? false;
  }

  static bool isAdmin(String? role) => (role ?? '').toLowerCase() == 'admin';

  static Future<void> loadFromSupabase() async {
    try {
      final res = await Supabase.instance.client.from('role_permissions').select('role, permission');
      final Map<String, Set<String>> map = {};
      for (final row in (res as List)) {
        final r = (row['role'] ?? '').toString();
        final p = (row['permission'] ?? '').toString();
        map.putIfAbsent(r, () => {}).add(p);
      }
      _custom = map;
    } catch (_) {}
  }

  static Future<String?> currentRole() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return null;
      final res = await Supabase.instance.client.from('profiles').select('role').eq('id', uid).maybeSingle();
      return (res?['role'] ?? '').toString();
    } catch (_) {
      return null;
    }
  }
}