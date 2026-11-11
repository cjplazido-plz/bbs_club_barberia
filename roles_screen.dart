// lib/screens/roles_screen.dart
// Editar Rol - igual a la foto de ejemplo pero con permisos BBS.
// Admin prende/apaga con checkbox. Guarda en Supabase tabla role_permissions.
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/role_permissions.dart';

class RolesScreen extends StatefulWidget {
  @override
  State<RolesScreen> createState() => _RolesScreenState();
}

class _RolesScreenState extends State<RolesScreen> {
  String _selectedRole = 'barber';
  Color _selectedColor = const Color(0xFFF59E0B);
  Set<String> _checked = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadForRole(_selectedRole);
  }

  void _loadForRole(String role) {
    setState(() {
      _selectedRole = role;
      _checked = Set.from(RolePermissions.defaults[role] ?? {});
      _selectedColor = Color(RolePermissions.roleColors[role] ?? 0xFF6C5CE7);
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      // Borra permisos viejos de ese rol y guarda los nuevos
      await Supabase.instance.client.from('role_permissions').delete().eq('role', _selectedRole);
      for (final p in _checked) {
        await Supabase.instance.client.from('role_permissions').insert({
          'role': _selectedRole,
          'permission': p,
        });
      }
      await RolePermissions.loadFromSupabase();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Rol ${RolePermissions.roleNames[_selectedRole]} guardado - ${_checked.length} permisos'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      // Si la tabla no existe aún, avisa el SQL que hay que correr
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Crea la tabla role_permissions con el SQL de ROLES_SQL.sql y vuelve a guardar. Error: $e'),
          backgroundColor: Colors.orange,
        ));
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: const Text('Editar Rol', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF1E293B),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Nombre', style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _selectedRole,
            dropdownColor: const Color(0xFF1E293B),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(filled: true, fillColor: const Color(0xFF0F172A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            items: RolePermissions.roleNames.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
            onChanged: (v) { if (v != null) _loadForRole(v); },
          ),
          const SizedBox(height: 12),
          const Text('Color', style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 6),
          Container(height: 36, decoration: BoxDecoration(color: _selectedColor, borderRadius: BorderRadius.circular(8))),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 2.8, crossAxisSpacing: 8, mainAxisSpacing: 8),
            itemCount: BbsPerm.all.length,
            itemBuilder: (context, i) {
              final perm = BbsPerm.all[i];
              final on = _checked.contains(perm);
              return InkWell(
                onTap: () => setState(() { on ? _checked.remove(perm) : _checked.add(perm); }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(10), border: Border.all(color: on ? const Color(0xFF6366F1) : Colors.white10)),
                  child: Row(children: [
                    Checkbox(value: on, activeColor: const Color(0xFF6366F1), onChanged: (v) => setState(() { v == true ? _checked.add(perm) : _checked.remove(perm); })),
                    Expanded(child: Text(BbsPerm.labels[perm] ?? perm, style: const TextStyle(color: Colors.white, fontSize: 11))),
                  ]),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: const Text('Barbero no edita ni elimina clientes, porque van y vienen. Cajero ve cuadratura pero no edita ni borra nada.', style: TextStyle(color: Colors.white70, fontSize: 11)),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: ElevatedButton(onPressed: _saving ? null : _save, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF166534), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: Text(_saving ? 'Guardando...' : 'Guardar', style: const TextStyle(fontWeight: FontWeight.bold)))),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: Colors.white24, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text('Cancelar'))),
          ]),
        ]),
      ),
    );
  }
}
