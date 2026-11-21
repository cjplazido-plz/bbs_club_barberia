// role_permissions.dart - FIX 2AM V2 - Menu obedece a Roles de Supabase
// REEMPLAZA a lib/services/role_permissions.dart
// FIX V2: Agrega isAdmin() y BbsPerm.confirmCancel que usan las otras pantallas
// y que faltaban en V1 y por eso no compilaba.

import 'package:supabase_flutter/supabase_flutter.dart';

class BbsPerm {
  static const String sell = 'vender';
  static const String viewAgenda = 'ver_agenda';
  static const String createEditAppointment = 'crear_editar_cita';
  static const String confirmCancelAppointment = 'confirmar_cancelar_cita';
  // Alias que usan otras pantallas (appointments_screen usa confirmCancel)
  static const String confirmCancel = 'confirmar_cancelar_cita';
  static const String blockHours = 'bloquear_horas';
  static const String viewClients = 'ver_clientes';
  static const String createEditClient = 'crear_editar_cliente';
  static const String deleteClient = 'eliminar_cliente';
  static const String viewCommissions = 'ver_comisiones';
  static const String markPaid = 'marcar_pagado';
  static const String viewClosure = 'ver_cierre_cuadratura';
  static const String viewCierre = 'ver_cierre_cuadratura';
  static const String viewHistory = 'ver_historial';
  static const String viewReports = 'ver_reportes';
  static const String viewUsers = 'ver_usuarios';
  static const String manageRoles = 'roles';
  static const String viewSettings = 'ver_configuracion';
  static const String viewBarbers = 'ver_barberos';
  static const String viewServices = 'ver_servicios';
  static const String viewProducts = 'ver_productos';
  static const String editPayment = 'editar_pago';
  // Aliases extra que usa el pos_screen V6 - para que no salga Member not found
  static const String viewReport = 'ver_reportes';
  static const String reports = 'ver_reportes';
  static const String viewDashboard = 'ver_dashboard';
  static const String dashboard = 'ver_dashboard';
  static const String viewClosureOld = 'ver_cierre_cuadratura';
  static const String viewComission = 'ver_comisiones';
  static const String viewCommission = 'ver_comisiones';
  static const String viewHistories = 'ver_historial';
  static const String viewClient = 'ver_clientes';
  static const String viewUser = 'ver_usuarios';
  static const String viewSetting = 'ver_configuracion';
  static const String viewBarber = 'ver_barberos';
  static const String viewService = 'ver_servicios';
  static const String viewProduct = 'ver_productos';
  static const String voidSale = 'anular_venta';
  // Faltaba en V5 - lo usa pos_screen y advanced_reports_screen
  static const String viewAdvancedReports = 'ver_reportes_avanzados';
  // V8 - NUEVO: Pagar comisiones. Separado de marcar_pagado (ese es para ventas).
  // Si se usara marcar_pagado, Cajero y Barbero/Cajero ya lo tienen y podrian pagar comisiones sin autorizacion.
  static const String payCommissions = 'pagar_comisiones';
  // V7 - NUEVO: Dashboard separado de Reportes. Antes los 3 usaban ver_reportes.
  static const String viewReporteCaja = 'ver_reportes';
  // V7 - NUEVO: Acciones que existen en la app pero no se podian marcar en Roles
  static const String createEditProduct = 'crear_editar_producto';
  static const String createEditService = 'crear_editar_servicio';
  static const String viewAdvancedReport = 'ver_reportes_avanzados';
  static const String advancedReports = 'ver_reportes_avanzados';
  static const String viewSales = 'ver_historial';
  static const String viewCash = 'ver_cierre_cuadratura';
  static const String viewCaja = 'ver_cierre_cuadratura';
  static const String viewAppointments = 'ver_agenda';
  static const String viewInventory = 'ver_productos';

  static const List<String> all = [
    sell, viewAgenda, createEditAppointment, confirmCancelAppointment, blockHours,
    viewClients, createEditClient, deleteClient, viewCommissions, markPaid,
    viewClosure, viewHistory, viewReports, viewUsers, manageRoles,
    viewSettings, viewBarbers, viewServices, viewProducts, editPayment, voidSale, viewDashboard, viewAdvancedReports, createEditProduct, createEditService, payCommissions,
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
    viewClosure: 'Ver Cierre-Cuadratura',
    viewHistory: 'Ver Historial',
    viewReports: 'Ver Reportes',
    viewUsers: 'Ver Usuarios',
    manageRoles: 'Roles',
    viewSettings: 'Ver Configuración',
    viewBarbers: 'Ver Barberos',
    viewServices: 'Ver Servicios',
    viewProducts: 'Ver Productos',
    editPayment: 'Editar Pago',
    voidSale: 'Anular Venta',
    viewDashboard: 'Ver Dashboard',
    viewAdvancedReports: 'Ver Reportes Avanzados',
    createEditProduct: 'Crear-Editar Producto',
    createEditService: 'Crear-Editar Servicio',
    payCommissions: 'Pagar Comisiones',
  };
}

class RolePermissions {
  static const Map<String, String> roleNames = {
    'admin': 'Administrador',
    'cashier': 'Cajero',
    'barber': 'Barbero',
    'barber_cashier': 'Barbero/Cajero',
  };

  // Colores que usa roles_screen.dart:153 - faltaba en V2
  static const Map<String, int> roleColors = {
    'admin': 0xFF6366F1,
    'cashier': 0xFF10B981,
    'barber': 0xFFF59E0B,
    'barber_cashier': 0xFFEC4899,
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
      'ver_cierre_cuadratura','ver_historial','ver_reportes','ver_usuarios','roles',
      'ver_configuracion','ver_barberos','ver_servicios','ver_productos','editar_pago','anular_venta',
      'ver_dashboard','ver_reportes_avanzados','crear_editar_producto','crear_editar_servicio','pagar_comisiones',
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

  // Metodos que usan las otras pantallas y faltaban en V1
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
        if (m.containsKey('permission') && m['permission'] != null) {
          perm = m['permission'].toString();
        } else if (m.containsKey('permission_key') && m['permission_key'] != null) {
          perm = m['permission_key'].toString();
        }
        perm = perm.trim();
        if (perm.isEmpty) continue;
        if (perm == 'none') continue;
        if (m.containsKey('allowed')) {
          final allowed = m['allowed'];
          if (allowed == false || allowed == 0 || allowed == 'false' || allowed == 'f') continue;
        }
        next.putIfAbsent(role, () => <String>{}).add(perm);
      }
      if (next.isNotEmpty) {
        _perms = next;
        _loaded = true;
      }
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
    if (_loaded) {
      return _perms[role]?.contains(perm) ?? false;
    }
    return (defaults[role] ?? {}).contains(perm);
  }
}
