// PREMIUM RESERVAS - Solo colores: fondo 0A0A0A, tarjetas 141414, dorado D4AF37 / FBBF24. Lógica, Placido oculto/protegido, bloqueo folio, permisos intactos.
// lib/screens/users_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'roles_screen.dart' as roles_screen;
import '../services/role_permissions.dart'; // <-- NUEVO IMPORT
import '../main.dart'; // para currentUserEmail - proteger a Placido

class UsersScreen extends StatefulWidget {
  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> with TickerProviderStateMixin {
  // FIX OCULTO + PROTEGE PLACIDO: Placido está oculto para Patricio, ni lo ve. Solo Placido se ve a sí mismo.
  // Patricio es ADMIN del día a día, pero no puede editar ni borrar a Placido, si no te deja afuera y se queda con la app.
  bool get _isDev => currentUserEmail.toLowerCase().trim() == 'cjplazido@gmail.com';
  bool _isProtectedUser(Map<String, dynamic> u) => (u['email'] ?? '').toString().toLowerCase().trim() == 'cjplazido@gmail.com';

  List<Map<String, dynamic>> _users = [];
  List<String> _availableRoles = ['admin', 'cashier', 'barber', 'barber_cashier']; // <-- NUEVA LISTA
  bool _isLoading = true;
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _loadRoles(); // Cargar roles primero
    _loadUsers();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // <-- NUEVA FUNCIÓN PARA CARGAR ROLES
  Future<void> _loadRoles() async {
    await RolePermissions.loadFromSupabase();
    try {
      final res = await Supabase.instance.client.from('role_permissions').select('role');
      final Set<String> fromDb = {};
      for (final r in (res as List)) fromDb.add((r['role'] ?? '').toString());
      final all = {...RolePermissions.defaults.keys, ...fromDb}.toList();
      all.sort((a, b) {
        const order = {'admin': 0, 'cashier': 1, 'barber': 2, 'barber_cashier': 3};
        return (order[a] ?? 99).compareTo(order[b] ?? 99);
      });
      if (mounted) setState(() => _availableRoles = all);
    } catch (e) {
      print('Error roles $e');
    }
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final res = await Supabase.instance.client.from('profiles').select().order('created_at');
      // FIX OCULTO: si no eres Placido, ni siquiera ves a Placido en la lista. Mejor escondido que con candado.
      // Patricio ve solo ALEX, BRAYAN, MATY, PATRICIO y User de Pruebas. Placido solo se ve a sí mismo cuando entra como Placido.
      final allUsers = List<Map<String, dynamic>>.from(res as List);
      final visibleUsers = _isDev ? allUsers : allUsers.where((u) => !_isProtectedUser(u)).toList();
      if (mounted) setState(() { _users = visibleUsers; _isLoading = false; });
      _ctrl.forward(from: 0);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteUser(String id, String userName) async {
    // FIX PROTEGE PLACIDO: si no eres Placido, no puedes borrar a Placido.
    final target = _users.firstWhere((u) => u['id'] == id, orElse: () => <String, dynamic>{});
    if (target.isNotEmpty && _isProtectedUser(target) && !_isDev) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🔒 No puedes eliminar a Placido, es el desarrollador / dueño. Solo él puede hacerlo.'), backgroundColor: Colors.orange));
      return;
    }
    if (target.isNotEmpty && _isProtectedUser(target) && _isDev) {
      // Si eres Placido y te quieres borrar a ti mismo, avisar que te quedas afuera
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ Eres Placido, si te borras te quedas sin acceso. No lo hagas.'), backgroundColor: Colors.red));
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar usuario', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('¿Eliminar a $userName?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          Container(
            decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
            child: ElevatedButton(
              onPressed: () => Navigator.pop(c, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent),
              child: const Text('Eliminar'),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await Supabase.instance.client.from('profiles').delete().eq('id', id);
      await _loadUsers();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Usuario eliminado'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red));
    }
  }

  void _showUserDialog({Map<String, dynamic>? user}) {
    // FIX PROTEGE PLACIDO: Patricio no puede editar a Placido (ni cambiarle rol, ni nombre, ni clave)
    if (user != null && _isProtectedUser(user) && !_isDev) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🔒 No puedes editar a Placido, es el desarrollador / dueño. Solo él puede editarse.'), backgroundColor: Colors.orange));
      return;
    }
    final emailCtrl = TextEditingController(text: user?['email'] ?? '');
    final nameCtrl = TextEditingController(text: user?['full_name'] ?? '');
    final phoneCtrl = TextEditingController(text: user?['phone'] ?? '');
    final passCtrl = TextEditingController();
    String selectedRole = user?['role'] ?? 'cashier';
    final isEditing = user != null;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF141414),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(isEditing ? 'Editar Usuario' : 'Nuevo Usuario', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(emailCtrl, 'Email *', Icons.email_rounded, enabled: !isEditing),
                const SizedBox(height: 12),
                _field(nameCtrl, 'Nombre completo *', Icons.person_rounded),
                const SizedBox(height: 12),
                _field(phoneCtrl, 'Teléfono', Icons.phone_rounded, keyboardType: TextInputType.phone),
                const SizedBox(height: 12),
                _field(passCtrl, isEditing ? 'Nueva Contraseña (Opcional)' : 'Contraseña *', Icons.lock_rounded, obscure: true),
                if (isEditing) const Padding(padding: EdgeInsets.only(top: 4, bottom: 8), child: Text('Deja en blanco para no cambiarla.', style: TextStyle(color: Colors.white38, fontSize: 10))),
                const SizedBox(height: 12),

                DropdownButtonFormField<String>(
                  value: selectedRole,
                  dropdownColor: const Color(0xFF141414),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Rol',
                    labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
                    filled: true,
                    fillColor: const Color(0xFF0A0A0A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  // <-- FIX: Generar items dinámicamente
                  items: _availableRoles.map((role) {
                    String label = role;
                    if (role == 'admin') label = 'Administrador';
                    else if (role == 'cashier') label = 'Cajero';
                    else if (role == 'barber') label = 'Barbero';
                    else if (role == 'barber_cashier') label = 'Barbero/Cajero';
                    else label = role[0].toUpperCase() + role.substring(1); // Capitalizar custom
                    
                    return DropdownMenuItem(value: role, child: Text(label));
                  }).toList(),
                  onChanged: (v) => setDialogState(() => selectedRole = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFD4AF37), Color(0xFFFBBF24)]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: ElevatedButton(
                onPressed: () async {
                  final email = emailCtrl.text.trim();
                  final name = nameCtrl.text.trim();
                  final pass = passCtrl.text.trim();
                  
                  if (email.isEmpty || name.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ Email y nombre son obligatorios'), backgroundColor: Colors.red));
                    return;
                  }
                  
                  try {
                    if (isEditing) {
                      if (pass.isNotEmpty) {
                        if (pass.length < 6) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La contraseña debe tener al menos 6 caracteres'), backgroundColor: Colors.red));
                          return;
                        }
                        final response = await Supabase.instance.client.functions.invoke(
                          'admin-update-user',
                          body: {
                            'userId': user!['id'],
                            'password': pass,
                            'full_name': name,
                            'role': selectedRole,
                            'phone': phoneCtrl.text.trim(),
                          },
                        );
                        if (response.status != 200) throw Exception('Error al actualizar: ${response.data}');
                      } else {
                        await Supabase.instance.client.from('profiles').update({
                          'full_name': name,
                          'phone': phoneCtrl.text.trim(),
                          'role': selectedRole,
                          'updated_at': DateTime.now().toIso8601String(),
                        }).eq('id', user!['id']);
                      }
                    } else {
                      if (pass.isEmpty || pass.length < 6) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('La contraseña debe tener al menos 6 caracteres'), backgroundColor: Colors.red),
                        );
                        return;
                      }

                      final response = await Supabase.instance.client.functions.invoke(
                        'admin-create-user',
                        body: {
                          'email': email,
                          'password': pass,
                          'full_name': name,
                          'role': selectedRole,
                          'phone': phoneCtrl.text.trim(),
                          'commission_rate': 0.0,
                        },
                      );

                      if (response.status != 200) {
                        throw Exception('Error al crear el usuario: ${response.data}');
                      }
                    }
                    
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                    await _loadUsers();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(isEditing ? '✅ Usuario actualizado' : '✅ Usuario creado'), backgroundColor: Colors.green),
                      );
                    }
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red));
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent),
                child: const Text('Guardar', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon, {TextInputType? keyboardType, bool enabled = true, bool obscure = false}) {
    return TextField(
      controller: c,
      enabled: enabled,
      keyboardType: keyboardType,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
        prefixIcon: Icon(icon, color: const Color(0xFFFBBF24), size: 18),
        filled: true,
        fillColor: const Color(0xFF0A0A0A),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin': return const Color(0xFF8B5CF6);
      case 'cashier': return const Color(0xFFD4AF37);
      case 'barber': return const Color(0xFFF59E0B);
      case 'barber_cashier': return const Color(0xFF10B981);
      default: return Colors.grey;
    }
  }

  String _getRoleLabel(String role) {
    switch (role) {
      case 'admin': return 'Administrador';
      case 'cashier': return 'Cajero';
      case 'barber': return 'Barbero';
      case 'barber_cashier': return 'Barbero/Cajero';
      default: return role[0].toUpperCase() + role.substring(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: const Text('Usuarios Premium', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF141414),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => roles_screen.RolesScreen()));
              _loadRoles(); // Recargar roles al volver
            },
            icon: const Icon(Icons.shield_rounded, color: Colors.white, size: 18),
            label: const Text('Roles', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
          : _users.isEmpty
              ? const Center(child: Text('No hay usuarios', style: TextStyle(color: Colors.white38)))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _users.length,
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    final role = (user['role'] ?? 'cashier').toString();
                    final delay = (index * 0.05).clamp(0.0, 0.5);
                    return FadeTransition(
                      opacity: Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _ctrl, curve: Interval(delay, 0.6 + delay, curve: Curves.easeOutCubic))),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(color: const Color(0xFF141414), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withOpacity(0.06))),
                        child: Material(
                          type: MaterialType.transparency,
                          child: ListTile(
                            leading: CircleAvatar(backgroundColor: _getRoleColor(role).withOpacity(0.18), child: Text((user['full_name'] ?? 'U').toString().isNotEmpty ? (user['full_name'] ?? 'U').toString()[0].toUpperCase() : 'U', style: TextStyle(color: _getRoleColor(role), fontWeight: FontWeight.bold))),
                            title: Text(user['full_name'] ?? 'Sin nombre', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 2),
                                Text(user['email'] ?? '', style: const TextStyle(fontSize: 11, color: Colors.white54)),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: _getRoleColor(role).withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                                  child: Text(_getRoleLabel(role).toUpperCase(), style: TextStyle(color: _getRoleColor(role), fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            trailing: (_isProtectedUser(user) && !_isDev)
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(color: Colors.amber.withOpacity(0.12), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.amber.withOpacity(0.3))),
                                  child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.lock_rounded, size: 14, color: Colors.amber), SizedBox(width: 4), Text('DUEÑO', style: TextStyle(color: Colors.amber, fontSize: 9, fontWeight: FontWeight.bold))]),
                                )
                              : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  decoration: BoxDecoration(color: const Color(0xFFD4AF37).withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                                  child: IconButton(icon: const Icon(Icons.edit_rounded, size: 18, color: Color(0xFFFBBF24)), onPressed: () => _showUserDialog(user: user)),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                                  child: IconButton(icon: const Icon(Icons.delete_rounded, size: 18, color: Color(0xFFEF4444)), onPressed: () => _deleteUser(user['id'], user['full_name'] ?? 'Usuario')),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFD4AF37), Color(0xFFFBBF24)]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: const Color(0xFFD4AF37).withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 6))],
        ),
        child: FloatingActionButton(
          onPressed: () => _showUserDialog(),
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}