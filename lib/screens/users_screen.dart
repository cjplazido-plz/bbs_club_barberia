import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UsersScreen extends StatefulWidget {
  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> with TickerProviderStateMixin {
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  late AnimationController _mainController;

  @override
  void initState() {
    super.initState();
    _mainController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _loadUsers();
  }

  @override
  void dispose() {
    _mainController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() { _isLoading = true; });
    try {
      final response = await Supabase.instance.client.from('profiles').select('*').order('created_at', ascending: false);
      setState(() {
        _users = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
      _mainController.forward(from: 0);
    } catch (e) {
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _createUser({required String email, required String password, required String fullName, String? phone, required String role, double commission = 0.0}) async {
    try {
      final authResponse = await Supabase.instance.client.auth.signUp(email: email, password: password);
      if (authResponse.user == null) throw Exception('No se pudo crear');
      final userId = authResponse.user!.id;
      await Supabase.instance.client.from('profiles').insert({'id': userId, 'email': email, 'full_name': fullName, 'phone': phone ?? '', 'role': role, 'commission_rate': commission, 'is_active': true});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ $fullName creado'), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
      await _loadUsers();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
    }
  }

  Future<void> _updateUser(Map<String, dynamic> user) async {
    try {
      await Supabase.instance.client.from('profiles').update({'full_name': user['full_name'], 'phone': user['phone'] ?? '', 'role': user['role'], 'commission_rate': user['commission_rate'] ?? 0.0}).eq('id', user['id']);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Actualizado'), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating));
      await _loadUsers();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
    }
  }

  Future<void> _deleteUser(String userId, String userName) async {
    final confirm = await showDialog<bool>(context: context, builder: (context) => AlertDialog(backgroundColor: const Color(0xFF1E293B), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), title: const Text('Eliminar usuario', style: TextStyle(color: Colors.white)), content: Text('¿Eliminar a $userName?', style: const TextStyle(color: Colors.white70)), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')), ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text('Eliminar'))]));
    if (confirm == true) {
      try {
        await Supabase.instance.client.from('profiles').delete().eq('id', userId);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Eliminado'), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating));
        await _loadUsers();
      } catch (e) {}
    }
  }

  void _showUserDialog({Map<String, dynamic>? user}) {
    final emailController = TextEditingController(text: user?['email'] ?? '');
    final passwordController = TextEditingController();
    final nameController = TextEditingController(text: user?['full_name'] ?? '');
    final phoneController = TextEditingController(text: user?['phone'] ?? '');
    final commissionController = TextEditingController(text: '${user?['commission_rate'] ?? 0.0}');
    String selectedRole = user?['role'] ?? 'cashier';
    final isEditing = user != null;

    showDialog(context: context, builder: (context) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(isEditing ? 'Editar Usuario' : 'Nuevo Usuario', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            _field(emailController, 'Email *', '📧', enabled: !isEditing),
            const SizedBox(height: 12),
            if (!isEditing) ...[_field(passwordController, 'Contraseña *', '🔒', isPassword: true), const SizedBox(height: 12)],
            _field(nameController, 'Nombre completo *', '👤'),
            const SizedBox(height: 12),
            _field(phoneController, 'Teléfono', '📱'),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(value: selectedRole, dropdownColor: const Color(0xFF1E293B), style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: 'Rol', prefixText: '👑  ', labelStyle: const TextStyle(color: Colors.white54), filled: true, fillColor: const Color(0xFF0F172A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.white10)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2))), items: const [DropdownMenuItem(value: 'admin', child: Text('Administrador')), DropdownMenuItem(value: 'cashier', child: Text('Cajero')), DropdownMenuItem(value: 'barber', child: Text('Barbero'))], onChanged: (v) => setDialogState(() => selectedRole = v!)),
            const SizedBox(height: 12),
            _field(commissionController, '% Comisión', '💰', keyboardType: TextInputType.number),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
            Container(decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF818CF8)]), borderRadius: BorderRadius.circular(10)), child: ElevatedButton(onPressed: () async { if (nameController.text.trim().isEmpty) return; if (!isEditing && (emailController.text.isEmpty || passwordController.text.isEmpty)) return; Navigator.pop(context); if (!isEditing) { await _createUser(email: emailController.text.trim(), password: passwordController.text, fullName: nameController.text.trim(), phone: phoneController.text.trim(), role: selectedRole, commission: double.tryParse(commissionController.text) ?? 0.0); } else { await _updateUser({'id': user!['id'], 'full_name': nameController.text.trim(), 'phone': phoneController.text.trim(), 'role': selectedRole, 'commission_rate': double.tryParse(commissionController.text) ?? 0.0}); } }, style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text('Guardar', style: TextStyle(fontWeight: FontWeight.bold)))),
          ],
        )));
  }

  Widget _field(TextEditingController c, String label, String icon, {bool enabled = true, bool isPassword = false, TextInputType? keyboardType}) {
    return TextField(controller: c, enabled: enabled, obscureText: isPassword, keyboardType: keyboardType, style: TextStyle(color: enabled ? Colors.white : Colors.white38), decoration: InputDecoration(labelText: label, prefixText: '$icon  ', labelStyle: const TextStyle(color: Colors.white54, fontSize: 12), filled: true, fillColor: enabled ? const Color(0xFF0F172A) : Colors.white10, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.white10)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2))));
  }

  Color _getRoleColor(String role) {
    switch (role) { case 'admin': return const Color(0xFF8B5CF6); case 'cashier': return const Color(0xFF3B82F6); case 'barber': return const Color(0xFFF59E0B); default: return Colors.grey; }
  }
  String _getRoleText(String role) {
    switch (role) { case 'admin': return 'Admin'; case 'cashier': return 'Cajero'; case 'barber': return 'Barbero'; default: return role; }
  }
  String _getRoleIcon(String role) {
    switch (role) { case 'admin': return '👑'; case 'cashier': return '💰'; case 'barber': return '✂️'; default: return '👤'; }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: const Text('Usuarios Premium', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
          : _users.isEmpty
              ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('👥', style: TextStyle(fontSize: 64)), SizedBox(height: 16), Text('No hay usuarios', style: TextStyle(color: Colors.white54, fontSize: 16))]))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _users.length,
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    final roleColor = _getRoleColor(user['role'] ?? 'cashier');
                    return AnimatedBuilder(
                      animation: _mainController,
                      builder: (context, child) {
                        final delay = index * 0.07;
                        final anim = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _mainController, curve: Interval(delay, 0.6 + delay, curve: Curves.easeOutCubic)));
                        return FadeTransition(opacity: anim, child: SlideTransition(position: Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero).animate(anim), child: child));
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withOpacity(0.05)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))]),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(18),
                          leading: Container(width: 52, height: 52, decoration: BoxDecoration(color: roleColor.withOpacity(0.15), shape: BoxShape.circle, border: Border.all(color: roleColor.withOpacity(0.3))), child: Center(child: Text(_getRoleIcon(user['role'] ?? 'cashier'), style: const TextStyle(fontSize: 22)))),
                          title: Text(user['full_name'] ?? 'Sin nombre', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(user['email'] ?? '', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                            if (user['phone'] != null && user['phone'].toString().isNotEmpty) Text('📱 ${user['phone']}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                            const SizedBox(height: 6),
                            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), decoration: BoxDecoration(color: roleColor.withOpacity(0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: roleColor.withOpacity(0.3))), child: Text(_getRoleText(user['role'] ?? 'cashier'), style: TextStyle(color: roleColor, fontSize: 10, fontWeight: FontWeight.bold))),
                          ]),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            Container(decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(10)), child: IconButton(icon: const Icon(Icons.edit_rounded, size: 18, color: Color(0xFF6366F1)), onPressed: () => _showUserDialog(user: user))),
                            const SizedBox(width: 6),
                            Container(decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: IconButton(icon: const Icon(Icons.delete_rounded, size: 18, color: Colors.red), onPressed: () => _deleteUser(user['id'], user['full_name'] ?? 'Usuario'))),
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
