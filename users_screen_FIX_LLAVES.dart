// lib/screens/users_screen.dart - FIX LLAVES - Usuarios Premium + Roles
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';
import 'roles_screen.dart' as roles_screen;

class UsersScreen extends StatefulWidget {
  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> with TickerProviderStateMixin {
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _loadUsers();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final res = await Supabase.instance.client.from('profiles').select().order('created_at');
      if (mounted) setState(() { _users = List<Map<String, dynamic>>.from(res as List); _isLoading = false; });
      _ctrl.forward(from: 0);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteUser(String id, String userName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
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
    final emailCtrl = TextEditingController(text: user?['email'] ?? '');
    final nameCtrl = TextEditingController(text: user?['full_name'] ?? '');
    final phoneCtrl = TextEditingController(text: user?['phone'] ?? '');
    final commCtrl = TextEditingController(text: '${user?['commission_rate'] ?? 0.0}');
    final passCtrl = TextEditingController();
    String selectedRole = user?['role'] ?? 'cashier';
    final isEditing = user != null;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
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
                if (!isEditing) ...[
                  _field(passCtrl, 'Contraseña (para crear en Auth)', Icons.lock_rounded, obscure: true),
                  const SizedBox(height: 6),
                  const Text('Después creá este email en Supabase > Authentication > Add user con esa contraseña para que pueda entrar.', style: TextStyle(color: Colors.white38, fontSize: 10)),
                  const SizedBox(height: 12),
                ],
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  dropdownColor: const Color(0xFF1E293B),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Rol',
                    labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'admin', child: Text('Administrador')),
                    DropdownMenuItem(value: 'cashier', child: Text('Cajero')),
                    DropdownMenuItem(value: 'barber', child: Text('Barbero')),
                    DropdownMenuItem(value: 'barber_cashier', child: Text('Barbero/Cajero')),
                  ],
                  onChanged: (v) => setDialogState(() => selectedRole = v!),
                ),
                const SizedBox(height: 12),
                _field(commCtrl, '% Comisión', Icons.percent_rounded, keyboardType: TextInputType.number),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF818CF8)]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: ElevatedButton(
                onPressed: () async {
                  final email = emailCtrl.text.trim();
                  final name = nameCtrl.text.trim();
                  if (email.isEmpty || name.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ Email y nombre son obligatorios'), backgroundColor: Colors.red));
                    return;
                  }
                  final comm = double.tryParse(commCtrl.text.trim()) ?? 0.0;
                  try {
                    if (isEditing) {
                      await Supabase.instance.client.from('profiles').update({
                        'full_name': name,
                        'phone': phoneCtrl.text.trim(),
                        'role': selectedRole,
                        'commission_rate': comm,
                        'updated_at': DateTime.now().toIso8601String(),
                      }).eq('id', user!['id']);
                    } else {
                      String uuid() {
                        final rnd = Random();
                        String hex(int n) => List.generate(n, (_) => rnd.nextInt(16).toRadixString(16)).join();
                        return '${hex(8)}-${hex(4)}-4${hex(3)}-${['8', '9', 'a', 'b'][rnd.nextInt(4)]}${hex(3)}-${hex(12)}';
                      }
                      final newId = uuid();
                      await Supabase.instance.client.from('profiles').insert({
                        'id': newId,
                        'email': email,
                        'full_name': name,
                        'phone': phoneCtrl.text.trim(),
                        'role': selectedRole,
                        'commission_rate': comm,
                        'created_at': DateTime.now().toIso8601String(),
                        'updated_at': DateTime.now().toIso8601String(),
                      });
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
        prefixIcon: Icon(icon, color: const Color(0xFF818CF8), size: 18),
        filled: true,
        fillColor: const Color(0xFF0F172A),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin':
        return const Color(0xFF8B5CF6);
      case 'cashier':
        return const Color(0xFF6366F1);
      case 'barber':
        return const Color(0xFFF59E0B);
      case 'barber_cashier':
        return const Color(0xFF10B981);
      default:
        return Colors.grey;
    }
  }

  String _getRoleLabel(String role) {
    switch (role) {
      case 'admin':
        return 'Administrador';
      case 'cashier':
        return 'Cajero';
      case 'barber':
        return 'Barbero';
      case 'barber_cashier':
        return 'Barbero/Cajero';
      default:
        return role;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: const Text('Usuarios Premium', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => roles_screen.RolesScreen())),
            icon: const Icon(Icons.shield_rounded, color: Colors.white, size: 18),
            label: const Text('Roles', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
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
                        decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withOpacity(0.06))),
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
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                                child: IconButton(icon: const Icon(Icons.edit_rounded, size: 18, color: Color(0xFF818CF8)), onPressed: () => _showUserDialog(user: user)),
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
                    );
                  },
                ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF818CF8)]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 6))],
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
