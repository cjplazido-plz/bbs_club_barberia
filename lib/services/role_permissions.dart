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
  
  // NUEVOS PERMISOS
  static const viewBarbers = 'viewBarbers';
  static const viewServices = 'viewServices';
  static const viewProducts = 'viewProducts';
  static const editPayment = 'editPayment';
  static const voidSale = 'voidSale';

  static const all = [
    sell, viewAgenda, createEditAppointment, confirmCancel, blockHours,
    viewClients, createEditClient, deleteClient, viewCommissions, markPaid,
    viewClosure, viewHistory, viewReports, viewUsers, manageRoles, viewSettings,
    viewBarbers, viewServices, viewProducts, editPayment, voidSale,
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
    viewBarbers: 'Ver Barberos',   // <-- NUEVO
    viewServices: 'Ver Servicios', // <-- NUEVO
    viewProducts: 'Ver Productos',
    editPayment: 'Editar Pago',
    voidSale: 'Anular Venta',
  };
}

class RolePermissions {
  // MODELO REAL BBS: Barbero (ALEX/MATY) vende y ve historial, pero NO edita pago, NO anula, NO ve cierre, NO marca pagado.
  // Barbero/Cajero (BRAYAN) maneja la Caja 1 unica: vende, ve cierre, marca pagado, edita pago, anula.
  // Admin todo. Si el Admin cambia algo en Roles, manda la DB, no estos defaults.
  static const Map<String, Set<String>> defaults = {
    'admin': {
      BbsPerm.sell, BbsPerm.viewAgenda, BbsPerm.createEditAppointment,
      BbsPerm.confirmCancel, BbsPerm.blockHours, BbsPerm.viewClients, BbsPerm.createEditClient,
      BbsPerm.deleteClient, BbsPerm.viewCommissions, BbsPerm.markPaid, BbsPerm.viewClosure,
      BbsPerm.viewHistory, BbsPerm.viewReports, BbsPerm.viewUsers,
      BbsPerm.manageRoles, BbsPerm.viewSettings,
      BbsPerm.viewBarbers, BbsPerm.viewServices, BbsPerm.viewProducts,
      BbsPerm.editPayment, BbsPerm.voidSale,
    },
    'cashier': {
      BbsPerm.sell, BbsPerm.viewAgenda, BbsPerm.createEditAppointment,
      BbsPerm.confirmCancel, BbsPerm.viewClients, BbsPerm.viewClosure, BbsPerm.viewHistory,
      BbsPerm.viewServices, BbsPerm.viewProducts, BbsPerm.markPaid,
      BbsPerm.editPayment, BbsPerm.voidSale,
    },
    'barber': {
      BbsPerm.sell, BbsPerm.viewAgenda, BbsPerm.viewClients, BbsPerm.viewCommissions, BbsPerm.viewHistory,
      BbsPerm.viewServices, BbsPerm.viewProducts,
    },
    'barber_cashier': {
      BbsPerm.sell, BbsPerm.viewAgenda, BbsPerm.createEditAppointment,
      BbsPerm.confirmCancel, BbsPerm.viewClients, BbsPerm.viewCommissions, BbsPerm.viewClosure,
      BbsPerm.viewHistory, BbsPerm.viewServices, BbsPerm.viewProducts,
      BbsPerm.markPaid, BbsPerm.editPayment, BbsPerm.voidSale,
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
  static bool _loaded = false;
  static bool get loaded => _loaded;

  static Set<String> getPermissions(String role) {
    final r = role.trim().toLowerCase();
    // FIX OBEDECE ROLES 100%: si ya cargamos de DB, manda la DB aunque el rol tenga 0 permisos.
    if (_loaded && _custom.containsKey(r)) {
      final perms = Set<String>.from(_custom[r]!);
      perms.remove('none');
      return perms;
    }
    if (_custom.containsKey(r)) {
      final perms = Set<String>.from(_custom[r]!);
      perms.remove('none');
      return perms;
    }
    return Set<String>.from(defaults[r] ?? defaults['cashier']!);
  }
  
  static bool can(String? role, String perm) {
    final r = (role ?? '').trim().toLowerCase();
    if (r == 'admin') return true;
    // Si ya cargamos de DB y el rol existe en DB, manda la DB: si el permiso no está, es false aunque el default lo tenga.
    if (_loaded && _custom.containsKey(r)) return _custom[r]!.contains(perm);
    if (_custom.containsKey(r)) return _custom[r]!.contains(perm);
    return defaults[r]?.contains(perm) ?? false;
  }

  static bool isAdmin(String? role) => (role ?? '').toLowerCase() == 'admin';


  // Mapa BD -> codigo: la tabla usa ver_agenda, vender... el codigo usa viewAgenda, sell...
  static String _dbKeyToCode(String db) {
    const m = {
      'vender': 'sell',
      'ver_agenda': 'viewAgenda',
      'crear_editar_cita': 'createEditAppointment',
      'confirmar_cancelar_cita': 'confirmCancel',
      'bloquear_horas': 'blockHours',
      'ver_clientes': 'viewClients',
      'crear_editar_cliente': 'createEditClient',
      'eliminar_cliente': 'deleteClient',
      'ver_comisiones': 'viewCommissions',
      'marcar_pagado': 'markPaid',
      'ver_cierre_cuadratura': 'viewClosure',
      'ver_historial': 'viewHistory',
      'ver_reportes': 'viewReports',
      'ver_usuarios': 'viewUsers',
      'roles': 'manageRoles',
      'ver_configuracion': 'viewSettings',
      'ver_barberos': 'viewBarbers',
      'ver_servicios': 'viewServices',
      'ver_productos': 'viewProducts',
      'editar_pago': 'editPayment',
      'anular_venta': 'voidSale',
    };
    return m[db] ?? db;
  }

  static Future<void> loadFromSupabase() async {
    try {
      // FIX 400: la tabla tiene permission_key + allowed, NO 'permission'
      final res = await Supabase.instance.client.from('role_permissions').select('role, permission_key, allowed');
      final Map<String, Set<String>> map = {};
      // Asegurar que cada rol que aparece en DB quede en el mapa aunque no tenga permisos marcados
      for (final row in (res as List)) {
        final rr = (row['role'] ?? '').toString();
        if (rr.isNotEmpty) map.putIfAbsent(rr, () => {});
      }
      _loaded = true;
      for (final row in (res as List)) {
        final r = (row['role'] ?? '').toString();
        final p = (row['permission_key'] ?? '').toString();
        final allowed = row['allowed'] == true;
        if (p.isEmpty) continue;
        if (!allowed) continue; // solo los marcados true cuentan como permiso
        // Traducir nombres de BD (vender, ver_agenda...) a claves del codigo (sell, viewAgenda...)
        final p2 = _dbKeyToCode(p);
        if (p2.isEmpty) continue;
        map.putIfAbsent(r, () => {}).add(p2);
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