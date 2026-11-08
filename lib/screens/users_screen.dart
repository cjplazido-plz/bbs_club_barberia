import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
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
      final response = await Supabase.instance.client.from('profiles').select('*').order('created_at', ascending: false);
      setState(() {
        _users = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
      _ctrl.forward(from: 0);
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteUser(String userId, String userName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Eliminar usuario', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('¿Eliminar a $userName?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          Container(decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)), child: ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent), child: const Text('Eliminar'))),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await Supabase.instance.client.from('profiles').delete().eq('id', userId);
        await _loadUsers();
      } catch (e) {}
    }
  }

  void _showUserDialog({Map<String, dynamic>? user}) {
    final emailCtrl = TextEditingController(text: user?['email'] ?? '');
    final nameCtrl = TextEditingController(text: user?['full_name'] ?? '');
    final phoneCtrl = TextEditingController(text: user?['phone'] ?? '');
    final commCtrl = TextEditingController(text: '${user?['commission_rate'] ?? 0.0}');
    String selectedRole = user?['role'] ?? 'cashier';
    final isEditing = user != null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(isEditing ? 'Editar Usuario' : 'Nuevo Usuario', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _field(emailCtrl, 'Email *', Icons.email_rounded, enabled: !isEditing),
              const SizedBox(height: 12),
              _field(nameCtrl, 'Nombre completo *', Icons.person_rounded),
              const SizedBox(height: 12),
              _field(phoneCtrl, 'Teléfono', Icons.phone_rounded, keyboardType: TextInputType.phone),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(value: selectedRole, dropdownColor: const Color(0xFF1E293B), style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: 'Rol', labelStyle: const TextStyle(color: Colors.white54, fontSize: 13), filled: true, fillColor: const Color(0xFF0F172A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), items: const [DropdownMenuItem(value: 'admin', child: Text('Administrador')), DropdownMenuItem(value: 'cashier', child: Text('Cajero')), DropdownMenuItem(value: 'barber', child: Text('Barbero'))], onChanged: (v) => setDialogState(() => selectedRole = v!)),
              const SizedBox(height: 12),
              _field(commCtrl, '% Comisión', Icons.percent_rounded, keyboardType: TextInputType.number),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
            Container(decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF818CF8)]), borderRadius: BorderRadius.circular(10)), child: ElevatedButton(onPressed: () async { Navigator.pop(context); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent), child: const Text('Guardar', style: TextStyle(fontWeight: FontWeight.bold)))),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon, {TextInputType? keyboardType, bool enabled = true}) {
    return TextField(
      controller: c,
      enabled: enabled,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18, color: const Color(0xFF818CF8)),
        labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
        filled: true,
        fillColor: enabled ? const Color(0xFF0F172A) : Colors.white10,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.08))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2)),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin': return const Color(0xFF8B5CF6);
      case 'cashier': return const Color(0xFF3B82F6);
      case 'barber': return const Color(0xFFF59E0B);
      default: return Colors.grey;
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
                    final role = user['role'] ?? 'cashier';
                    return AnimatedBuilder(
                      animation: _ctrl,
                      builder: (context, child) {
                        final delay = index * 0.06;
                        final anim = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _ctrl, curve: Interval(delay, 0.6 + delay, curve: Curves.easeOutCubic)));
                        return FadeTransition(opacity: anim, child: SlideTransition(position: Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(anim), child: child));
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.06))),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          leading: Container(width: 44, height: 44, decoration: BoxDecoration(color: _getRoleColor(role).withOpacity(0.15), shape: BoxShape.circle, border: Border.all(color: _getRoleColor(role).withOpacity(0.3))), child: Icon(role == 'admin' ? Icons.workspace_premium_rounded : role == 'barber' ? Icons.content_cut_rounded : Icons.point_of_sale_rounded, size: 20, color: _getRoleColor(role))),
                          title: Text(user['full_name'] ?? 'Sin nombre', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)),
                          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const SizedBox(height: 2),
                            Text(user['email'] ?? '', style: const TextStyle(fontSize: 11, color: Colors.white54)),
                            const SizedBox(height: 4),
                            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: _getRoleColor(role).withOpacity(0.15), borderRadius: BorderRadius.circular(20)), child: Text(role.toUpperCase(), style: TextStyle(color: _getRoleColor(role), fontSize: 10, fontWeight: FontWeight.bold))),
                          ]),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            Container(decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.12), borderRadius: BorderRadius.circular(10)), child: IconButton(icon: const Icon(Icons.edit_rounded, size: 18, color: Color(0xFF818CF8)), onPressed: () => _showUserDialog(user: user))),
                            const SizedBox(width: 6),
                            Container(decoration: BoxDecoration(color: Colors.red.withOpacity(0.12), borderRadius: BorderRadius.circular(10)), child: IconButton(icon: const Icon(Icons.delete_rounded, size: 18, color: Color(0xFFEF4444)), onPressed: () => _deleteUser(user['id'], user['full_name'] ?? 'Usuario'))),
                          ]),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: Container(decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF818CF8)]), borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 6))]), child: FloatingActionButton(onPressed: () => _showUserDialog(), backgroundColor: Colors.transparent, elevation: 0, child: const Icon(Icons.add_rounded, color: Colors.white, size: 28))),
    );
  }
}
