import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UsersScreen extends StatefulWidget {
  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() { _isLoading = true; });
    try {
      final response = await Supabase.instance.client.from('profiles').select('*').order('created_at', ascending: false);
      setState(() {
        _users = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error al cargar usuarios: $e');
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _createUser({required String email, required String password, required String fullName, String? phone, required String role, double commission = 0.0}) async {
    try {
      final authResponse = await Supabase.instance.client.auth.signUp(email: email, password: password);
      if (authResponse.user == null) throw Exception('No se pudo crear el usuario');
      final userId = authResponse.user!.id;
      await Supabase.instance.client.from('profiles').insert({'id': userId, 'email': email, 'full_name': fullName, 'phone': phone ?? '', 'role': role, 'commission_rate': commission, 'is_active': true});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ Usuario $fullName creado correctamente'), backgroundColor: Colors.green));
      }
      await _loadUsers();
    } catch (e) {
      print('❌ Error al crear usuario: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _updateUser(Map<String, dynamic> user) async {
    try {
      await Supabase.instance.client.from('profiles').update({'full_name': user['full_name'], 'phone': user['phone'] ?? '', 'role': user['role'], 'commission_rate': user['commission_rate'] ?? 0.0}).eq('id', user['id']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Usuario actualizado'), backgroundColor: Colors.green));
      }
      await _loadUsers();
    } catch (e) {
      print('❌ Error al actualizar: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _deleteUser(String userId, String userName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar usuario'),
        content: Text('¿Eliminar a $userName?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await Supabase.instance.client.from('profiles').delete().eq('id', userId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Usuario eliminado'), backgroundColor: Colors.green));
        }
        await _loadUsers();
      } catch (e) {
        print('❌ Error al eliminar: $e');
      }
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

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'Editar Usuario' : 'Nuevo Usuario'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: emailController, decoration: InputDecoration(labelText: 'Email *', border: const OutlineInputBorder(), enabled: !isEditing, filled: isEditing, fillColor: isEditing ? Colors.grey[200] : null), keyboardType: TextInputType.emailAddress, readOnly: isEditing),
                const SizedBox(height: 12),
                if (!isEditing) ...[
                  TextField(controller: passwordController, decoration: const InputDecoration(labelText: 'Contraseña *', border: OutlineInputBorder()), obscureText: true),
                  const SizedBox(height: 12),
                ],
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nombre completo *', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Teléfono', border: OutlineInputBorder()), keyboardType: TextInputType.phone),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(value: selectedRole, decoration: const InputDecoration(labelText: 'Rol', border: OutlineInputBorder()), items: const [DropdownMenuItem(value: 'admin', child: Text('Administrador')), DropdownMenuItem(value: 'cashier', child: Text('Cajero/Recepción')), DropdownMenuItem(value: 'barber', child: Text('Barbero'))], onChanged: (value) => setDialogState(() => selectedRole = value!)),
                const SizedBox(height: 12),
                TextField(controller: commissionController, decoration: const InputDecoration(labelText: '% Comisión (barberos)', border: OutlineInputBorder()), keyboardType: TextInputType.number),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El nombre es obligatorio')));
                  return;
                }
                if (!isEditing) {
                  if (emailController.text.trim().isEmpty || passwordController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email y contraseña son obligatorios')));
                    return;
                  }
                  Navigator.pop(context);
                  await _createUser(email: emailController.text.trim(), password: passwordController.text, fullName: nameController.text.trim(), phone: phoneController.text.trim(), role: selectedRole, commission: double.tryParse(commissionController.text) ?? 0.0);
                } else {
                  Navigator.pop(context);
                  await _updateUser({'id': user!['id'], 'full_name': nameController.text.trim(), 'phone': phoneController.text.trim(), 'role': selectedRole, 'commission_rate': double.tryParse(commissionController.text) ?? 0.0});
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin': return Colors.purple;
      case 'cashier': return Colors.blue;
      case 'barber': return Colors.orange;
      default: return Colors.grey;
    }
  }

  String _getRoleText(String role) {
    switch (role) {
      case 'admin': return 'Administrador';
      case 'cashier': return 'Cajero/Recepción';
      case 'barber': return 'Barbero';
      default: return role;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Text('←', style: TextStyle(fontSize: 24, color: Colors.white)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Gestión de Usuarios'),
        backgroundColor: Colors.indigo[700],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Text('👥', style: TextStyle(fontSize: 64)), const SizedBox(height: 16), Text('No hay usuarios registrados', style: TextStyle(color: Colors.grey[400], fontSize: 16))]))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _users.length,
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(backgroundColor: _getRoleColor(user['role'] ?? 'cashier').withOpacity(0.2), child: Text(user['role'] == 'admin' ? '👑' : user['role'] == 'barber' ? '✂️' : '💰', style: TextStyle(fontSize: 24))),
                        title: Text(user['full_name'] ?? 'Sin nombre', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user['email'] ?? '', style: const TextStyle(fontSize: 12)),
                            if (user['phone'] != null && user['phone'].toString().isNotEmpty) Text('📱 ${user['phone']}', style: const TextStyle(fontSize: 12)),
                            const SizedBox(height: 4),
                            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: _getRoleColor(user['role'] ?? 'cashier').withOpacity(0.2), borderRadius: BorderRadius.circular(12)), child: Text(_getRoleText(user['role'] ?? 'cashier'), style: TextStyle(color: _getRoleColor(user['role'] ?? 'cashier'), fontSize: 12, fontWeight: FontWeight.bold))),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Text('✏️', style: TextStyle(fontSize: 20)), onPressed: () => _showUserDialog(user: user)),
                            IconButton(icon: const Text('🗑️', style: TextStyle(fontSize: 20)), onPressed: () => _deleteUser(user['id'], user['full_name'] ?? 'Usuario')),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(onPressed: () => _showUserDialog(), backgroundColor: Colors.indigo[700], child: const Text('➕', style: TextStyle(fontSize: 24))),
    );
  }
}