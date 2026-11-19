// lib/services/role_permissions.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class BbsPerm {
  static const String sell = 'vender';
  static const String viewAgenda = 'ver_agenda';
  static const String createEditAppointment = 'crear_editar_cita';
  static const String confirmCancelAppointment = 'confirmar_cancelar_cita';
  static const String confirmCancel = 'confirmar_cancelar_cita';
  static const String blockHours = 'bloquear_horas';
  static const String viewClients = 'ver_clientes';
  static const String createEditClient = 'crear_editar_cliente';
  static const String deleteClient = 'eliminar_cliente';
  static const String viewCommissions = 'ver_comisiones';
  static const String markPaid = 'marcar_pagado';
  
  // --- REPORTES SEPARADOS ---
  static const String viewDashboard = 'ver_dashboard'; // <-- NUEVO
  static const String viewClosure = 'ver_cierre_cuadratura'; // Reporte Caja
  static const String viewAdvancedReports = 'ver_reportes_avanzados';
  
  static const String viewHistory = 'ver_historial';
  static const String viewUsers = 'ver_usuarios';
  static const String manageRoles = 'roles';
  static const String viewSettings = 'ver_configuracion';
  static const String viewBarbers = 'ver_barberos';
  static const String viewServices = 'ver_servicios';
  static const String viewProducts = 'ver_productos';
  static const String editPayment = 'editar_pago';
  static const String voidSale = 'anular_venta';

  static const List<String> all = [
    sell, viewAgenda, createEditAppointment, confirmCancelAppointment, blockHours,
    viewClients, createEditClient, deleteClient, viewCommissions, markPaid,
    viewDashboard, viewClosure, viewAdvancedReports, viewHistory, viewUsers, manageRoles, // <-- ACTUALIZADO
    viewSettings, viewBarbers, viewServices, viewProducts, editPayment, voidSale,
  ];

  static const Map<String, String> labels = {
    sell: 'Vender (cobrar)',
    viewAgenda: 'Ver Agenda',
    createEditAppointment: 'Crear-Editar Cita',
    confirmCancelAppointment: 'Confirmar-Cancelar Cita',
    blockHours: 'Bloquear Horas',
    viewClients: 'Ver Clientes',
    createEditClient: 'Crear-Editar Cliente',
    deleteClient: 'Eliminar Cliente',
    viewCommissions: 'Ver Comisiones',
    markPaid: 'Marcar Pagado',
    viewDashboard: 'Ver Dashboard', // <-- NUEVO
    viewClosure: 'Ver Reporte Caja / Cierre', // <-- RENOMBRADO PARA CLARIDAD
    viewAdvancedReports: 'Ver Reportes Avanzados',
    viewHistory: 'Ver Historial',
    viewUsers: 'Ver Usuarios',
    manageRoles: 'Roles',
    viewSettings: 'Ver Configuración',
    viewBarbers: 'Ver Barberos',
    viewServices: 'Ver Servicios',
    viewProducts: 'Ver Productos',
    editPayment: 'Editar Pago',
    voidSale: 'Anular Venta',
  };
}

class RolePermissions {
  static const Map<String, String> roleNames = {
    'admin': 'Administrador',
    'cashier': 'Cajero',
    'barber': 'Barbero',
    'barber_cashier': 'Barbero/Cajero',
  };

  static Future<String?> currentRole() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;
    try {
      final profile = await Supabase.instance.client.from('profiles').select('role').eq('id', user.id).maybeSingle();
      return profile?['role']?.toString();
    } catch (_) { return null; }
  }

  static const Map<String, int> roleColors = {
    'admin': 0xFF6366F1, 'cashier': 0xFF10B981, 'barber': 0xFFF59E0B, 'barber_cashier': 0xFFEC4899,
  };

  static const Map<String, String> roleDescriptions = {
    'admin': 'Acceso total',
    'cashier': 'Cobra, ve cierre, no edita ni borra',
    'barber': 'Solo sus citas, no edita clientes',
    'barber_cashier': 'Corta y cobra, no edita clientes',
  };

  static const List<String> allRoles = ['admin', 'cashier', 'barber', 'barber_cashier'];

  static const Map<String, Set<String>> defaults = {
    'admin': {
      'vender','ver_agenda','crear_editar_cita','confirmar_cancelar_cita','bloquear_horas',
      'ver_clientes','crear_editar_cliente','eliminar_cliente','ver_comisiones','marcar_pagado',
      'ver_dashboard','ver_cierre_cuadratura','ver_reportes_avanzados','ver_historial','ver_usuarios','roles', // <-- ACTUALIZADO
      'ver_configuracion','ver_barberos','ver_servicios','ver_productos','editar_pago','anular_venta',
    },
    'barber_cashier': {
      'vender','ver_comisiones','ver_cierre_cuadratura','ver_historial','editar_pago','anular_venta',
    },
    'barber': {
      'vender','ver_historial','ver_comisiones','ver_agenda','ver_clientes','ver_servicios','ver_productos',
    },
    'cashier': {
      'vender','ver_cierre_cuadratura','ver_historial','marcar_pagado','ver_clientes','ver_servicios','ver_productos','ver_agenda',
    },
  };

  static Map<String, Set<String>> _perms = {};
  static bool _loaded = false;

  static bool isAdmin(String role) => role == 'admin';
  static bool isCashier(String role) => role == 'cashier';
  static bool isBarber(String role) => role == 'barber';
  static bool isBarberCashier(String role) => role == 'barber_cashier';

  static Future<void> loadFromSupabase() async {
    try {
      final res = await Supabase.instance.client.from('role_permissions').select();
      final Map<String, Set<String>> next = {};
      for (final row in (res as List)) {
        final m = row as Map;
        final role = (m['role'] ?? '').toString().trim();
        if (role.isEmpty) continue;
        String perm = '';
        if (m.containsKey('permission') && m['permission'] != null) perm = m['permission'].toString();
        else if (m.containsKey('permission_key') && m['permission_key'] != null) perm = m['permission_key'].toString();
        perm = perm.trim();
        if (perm.isEmpty || perm == 'none') continue;
        if (m.containsKey('allowed')) {
          final allowed = m['allowed'];
          if (allowed == false || allowed == 0 || allowed == 'false' || allowed == 'f') continue;
        }
        next.putIfAbsent(role, () => <String>{}).add(perm);
      }
      if (next.isNotEmpty) { _perms = next; _loaded = true; }
    } catch (_) {}
  }

  static Set<String> getPermissions(String role) {
    if (role == 'admin') return Set.from(defaults['admin']!);
    if (_loaded && _perms.containsKey(role)) return Set.from(_perms[role]!);
    if (_perms.containsKey(role)) return Set.from(_perms[role]!);
    return Set.from(defaults[role] ?? {});
  }

  static bool can(String role, String perm) {
    if (role == 'admin') return true;
    if (_loaded) return _perms[role]?.contains(perm) ?? false;
    return (defaults[role] ?? {}).contains(perm);
  }
}