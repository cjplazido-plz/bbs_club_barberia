// role_permissions_FINAL_COMPLETO.dart
// REEMPLAZA a role_permissions.dart - VERSIÓN FINAL, COMPATIBLE 100% CON TU PROYECTO
// - BbsPerm es CLASE con constantes String + all + labels (como lo usa tu roles_screen)
// - RolePermissions tiene: can, isAdmin, loadFromSupabase, defaults (List), roleNames, roleColors, getPermissions
// - Lee permisos desde Supabase tabla role_permissions (permission_key + allowed)
// - Si no ha cargado, usa defaults

import 'package:supabase_flutter/supabase_flutter.dart';

// BbsPerm: constantes String, NO enum. Así lo usa tu código: BbsPerm.viewReports es un String.
class BbsPerm {
  static const String vender = 'vender';
  static const String viewAgenda = 'ver_agenda';
  static const String verAgenda = 'ver_agenda';
  static const String createEditAppointment = 'crear_editar_cita';
  static const String confirmCancel = 'confirmar_cancelar_cita';
  static const String blockHours = 'bloquear_horas';
  static const String viewClients = 'ver_clientes';
  static const String createEditClient = 'crear_editar_cliente';
  static const String deleteClient = 'eliminar_cliente';
  static const String viewCommissions = 'ver_comisiones';
  static const String markPaid = 'marcar_pagado';
  static const String viewClosure = 'ver_cierre_cuadratura';
  static const String viewCierreCuadratura = 'ver_cierre_cuadratura';
  static const String viewHistory = 'ver_historial';
  static const String viewReports = 'ver_reportes';
  static const String viewUsers = 'ver_usuarios';
  static const String roles = 'roles';
  static const String manageRoles = 'roles';
  static const String viewConfig = 'ver_configuracion';
  static const String viewSettings = 'ver_configuracion';
  static const String viewBarbers = 'ver_barberos';
  static const String viewServices = 'ver_servicios';
  static const String viewProducts = 'ver_productos';
  static const String editPayment = 'editar_pago';
  static const String voidSale = 'anular_venta';

  // ORDEN PARA PATRICIO: 1. Qué puede VER, 2. Qué puede HACER
  static const List<String> all = [
    // VER
    'ver_agenda',
    'ver_clientes',
    'ver_historial',
    'ver_comisiones',
    'ver_cierre_cuadratura',
    'ver_reportes',
    'ver_servicios',
    'ver_productos',
    'ver_barberos',
    'ver_usuarios',
    'roles',
    'ver_configuracion',
    // HACER
    'vender',
    'crear_editar_cita',
    'confirmar_cancelar_cita',
    'bloquear_horas',
    'crear_editar_cliente',
    'eliminar_cliente',
    'marcar_pagado',
    'editar_pago',
    'anular_venta',
  ];

  // Nombres claros para Patricio
  static const Map<String, String> labels = {
    'ver_agenda': 'Ver Agenda',
    'ver_clientes': 'Ver lista de clientes',
    'ver_historial': 'Ver Historial de ventas',
    'ver_comisiones': 'Ver Comisiones',
    'ver_cierre_cuadratura': 'Ver Cierre y Cuadratura de caja',
    'ver_reportes': 'Ver Reportes',
    'ver_servicios': 'Ver Servicios y precios',
    'ver_productos': 'Ver Productos',
    'ver_barberos': 'Ver lista de Barberos',
    'ver_usuarios': 'Ver Usuarios del sistema',
    'roles': 'Ver y editar Roles',
    'ver_configuracion': 'Ver Configuración',
    'vender': 'Cobrar en caja (Vender)',
    'crear_editar_cita': 'Crear y editar citas',
    'confirmar_cancelar_cita': 'Confirmar y cancelar citas',
    'bloquear_horas': 'Bloquear horas',
    'crear_editar_cliente': 'Crear y editar clientes',
    'eliminar_cliente': 'Eliminar clientes',
    'marcar_pagado': 'Marcar venta como pagada',
    'editar_pago': 'Editar pago de una venta',
    'anular_venta': 'Anular una venta',
  };

  // Descripción corta debajo de cada permiso (para la pantalla Roles)
  static const Map<String, String> descriptions = {
    'ver_agenda': 'Ve las citas del día',
    'ver_clientes': 'Ve nombres y teléfonos',
    'ver_historial': 'Ve ventas pasadas y quién cobró',
    'ver_comisiones': 'Ve cuánto ganó cada barbero (50%)',
    'ver_cierre_cuadratura': 'Ve cuánta plata hay al cerrar el día',
    'ver_reportes': 'Ve resumen por día / mes',
    'ver_servicios': 'Necesario para poder cobrar un corte',
    'ver_productos': 'Necesario para poder cobrar un producto',
    'ver_barberos': 'Ve quiénes son los barberos',
    'ver_usuarios': 'Ve quiénes entran al sistema',
    'roles': 'Puede cambiar permisos de otros. Solo Admin.',
    'ver_configuracion': 'Ve precio, banco, horarios',
    'vender': 'Cobra en el POS y da ticket. Entra plata a caja.',
    'crear_editar_cita': 'Puede agendar y cambiar una cita',
    'confirmar_cancelar_cita': 'Confirma que viene o cancela',
    'bloquear_horas': 'Bloquea una hora para que nadie agende',
    'crear_editar_cliente': 'CUIDADO: Puede cambiar datos de clientes. Barbero NO debe tenerlo.',
    'eliminar_cliente': 'Borra un cliente. Solo Admin.',
    'marcar_pagado': 'Cambia de Pendiente a Pagada sin cobrar de nuevo. Ej: pagó por transferencia.',
    'editar_pago': 'Cambia método de pago o monto de una venta ya hecha.',
    'anular_venta': 'Borra una venta del historial. Solo Cajero / Admin.',
  };
}

class RolePermissions {
  static final Map<String, Map<String, bool>> _cache = {};

  // defaults: Map rol -> LISTA de permission_key activados por defecto
  // Así lo usa roles_screen: for (final p in RolePermissions.defaults['cashier']!)
  static final Map<String, List<String>> defaults = {
    'admin': BbsPerm.all,
    'barber': [
      'ver_agenda', 'ver_clientes', 'ver_historial', 'ver_comisiones',
      'ver_servicios', 'ver_productos', 'vender',
    ],
    'barber_cashier': [
      'ver_agenda', 'ver_clientes', 'ver_historial', 'ver_comisiones',
      'ver_cierre_cuadratura', 'ver_servicios', 'ver_productos',
      'vender', 'crear_editar_cita', 'confirmar_cancelar_cita',
      'marcar_pagado', 'editar_pago', 'anular_venta',
    ],
    'cashier': [
      'ver_agenda', 'ver_clientes', 'ver_historial',
      'ver_cierre_cuadratura', 'ver_servicios', 'ver_productos',
      'vender', 'marcar_pagado', 'editar_pago', 'anular_venta',
    ],
  };

  static const Map<String, String> roleNames = {
    'admin': 'Administrador',
    'barber': 'Barbero',
    'barber_cashier': 'Barbero/Cajero',
    'cashier': 'Cajero',
    'supervisor': 'Supervisor',
  };

  static const Map<String, int> roleColors = {
    'admin': 0xFF6C5CE7,
    'barber': 0xFF00B894,
    'barber_cashier': 0xFF0984E3,
    'cashier': 0xFFFDCB6E,
    'supervisor': 0xFFE17055,
  };

  // Devuelve los permisos activados para un rol (lo usa roles_screen para los ticks)
  static Set<String> getPermissions(String role) {
    if (role == 'admin') return BbsPerm.all.toSet();
    if (_cache.containsKey(role)) {
      return _cache[role]!.entries.where((e) => e.value).map((e) => e.key).toSet();
    }
    return (defaults[role] ?? []).toSet();
  }

  static Future<void> loadFromSupabase() async {
    try {
      final db = Supabase.instance.client;
      final rows = await db.from('role_permissions').select('role, permission_key, allowed');
      _cache.clear();
      for (final r in (rows as List)) {
        final role = r['role'] as String;
        final k = r['permission_key'] as String;
        final v = r['allowed'] as bool;
        _cache.putIfAbsent(role, () => {})[k] = v;
      }
    } catch (_) {}
  }

  static Future<void> cargar(String role) async => loadFromSupabase();

  static bool can(String role, String perm) {
    if (role == 'admin') return true;
    if (_cache.containsKey(role) && _cache[role]!.containsKey(perm)) return _cache[role]![perm]!;
    return (defaults[role] ?? []).contains(perm);
  }

  static bool isAdmin(String role) => role == 'admin';

  static bool canKey(String role, String key) => can(role, key);
}
