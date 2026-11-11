// lib/services/role_permissions.dart
// Permisos BBS Club - Barbero NO edita/elimina clientes, Cajero ve cuadratura pero NO edita/borra.
// Admin lo puede todo. Barbero/Cajero = mezcla sin editar/eliminar clientes.
import 'package:supabase_flutter/supabase_flutter.dart';

class BbsPerm {
  static const viewPos = 'viewPos';                 // Ver POS
  static const sell = 'sell';                       // Vender / Cobrar
  static const viewAgenda = 'viewAgenda';
  static const createEditAppointment = 'createEditAppointment';
  static const confirmCancel = 'confirmCancel';
  static const blockHours = 'blockHours';           // Candado Bloquear Horas - solo Admin
  static const viewClients = 'viewClients';
  static const createEditClient = 'createEditClient';
  static const deleteClient = 'deleteClient';
  static const viewCommissions = 'viewCommissions';
  static const markPaid = 'markPaid';               // Marcar PAGADO - solo Admin
  static const viewClosure = 'viewClosure';         // Ver Cierre / Cuadratura
  static const viewHistory = 'viewHistory';
  static const cancelSale = 'cancelSale';           // Anular venta / Editar pago
  static const viewReports = 'viewReports';         // Informes / Exportar
  static const viewUsers = 'viewUsers';
  static const manageRoles = 'manageRoles';         // Editar Roles
  static const viewSettings = 'viewSettings';

  static const all = [
    viewPos, sell, viewAgenda, createEditAppointment, confirmCancel, blockHours,
    viewClients, createEditClient, deleteClient, viewCommissions, markPaid,
    viewClosure, viewHistory, cancelSale, viewReports, viewUsers, manageRoles, viewSettings,
  ];

  static const labels = {
    viewPos: 'Ver POS',
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
    cancelSale: 'Anular Venta / Editar Pago',
    viewReports: 'Ver Informes / Exportar',
    viewUsers: 'Ver Usuarios',
    manageRoles: 'Roles',
    viewSettings: 'Ver Configuración',
  };
}

class RolePermissions {
  // Permisos por defecto acordados con Patricio
  static const Map<String, Set<String>> defaults = {
    'admin': {
      BbsPerm.viewPos, BbsPerm.sell, BbsPerm.viewAgenda, BbsPerm.createEditAppointment,
      BbsPerm.confirmCancel, BbsPerm.blockHours, BbsPerm.viewClients, BbsPerm.createEditClient,
      BbsPerm.deleteClient, BbsPerm.viewCommissions, BbsPerm.markPaid, BbsPerm.viewClosure,
      BbsPerm.viewHistory, BbsPerm.cancelSale, BbsPerm.viewReports, BbsPerm.viewUsers,
      BbsPerm.manageRoles, BbsPerm.viewSettings,
    },
    'cashier': {
      BbsPerm.viewPos, BbsPerm.sell, BbsPerm.viewAgenda, BbsPerm.createEditAppointment,
      BbsPerm.confirmCancel, BbsPerm.viewClients, BbsPerm.viewClosure, BbsPerm.viewHistory,
    },
    'barber': {
      BbsPerm.viewAgenda, BbsPerm.viewClients, BbsPerm.viewCommissions, BbsPerm.viewHistory,
    },
    'barber_cashier': {
      BbsPerm.viewPos, BbsPerm.sell, BbsPerm.viewAgenda, BbsPerm.createEditAppointment,
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

  // Permisos custom que el Admin guardó en Supabase (tabla role_permissions).
  // Si no hay nada guardado, usa defaults.
  static Map<String, Set<String>> _custom = {};

  static bool can(String? role, String perm) {
    final r = (role ?? '').trim().toLowerCase();
    // FIX VERCEL: Admin siempre tiene TODO, aunque la tabla role_permissions esté incompleta.
    // Si no, al guardar un rol nuevo, Admin perdía Roles y el menú no mostraba Roles.
    if (r == 'admin') return true;
    if (_custom.containsKey(r)) return _custom[r]!.contains(perm) || (defaults[r]?.contains(perm) ?? false);
    return defaults[r]?.contains(perm) ?? false;
  }

  static bool isAdmin(String? role) => (role ?? '').toLowerCase() == 'admin';

  // Carga permisos custom desde Supabase. Si la tabla no existe aún, usa defaults sin romper.
  static Future<void> loadFromSupabase() async {
    try {
      final res = await Supabase.instance.client.from('role_permissions').select('role, permission');
      final Map<String, Set<String>> map = {};
      for (final row in (res as List)) {
        final r = (row['role'] ?? '').toString();
        final p = (row['permission'] ?? '').toString();
        map.putIfAbsent(r, () => {}).add(p);
      }
      if (map.isNotEmpty) {
        // Merge: no borra defaults, solo agrega custom. Si admin quedó sin manageRoles en la tabla, igual lo mantiene por can() de arriba.
        _custom = map;
      }
    } catch (_) {
      // Sin tabla aún -> defaults. No rompe la app.
    }
  }

  // Rol del usuario logeado (desde profiles por auth uid)
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
