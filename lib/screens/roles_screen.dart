import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/role_permissions.dart';

class RolesScreen extends StatefulWidget {
  @override
  State<RolesScreen> createState() => _RolesScreenState();
}

class _RolesScreenState extends State<RolesScreen> {
  List<String> _roles = ['admin', 'cashier', 'barber', 'barber_cashier'];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRoles();
  }

  Future<void> _loadRoles() async {
    setState(() => _isLoading = true);
    await RolePermissions.loadFromSupabase(); // Carga los permisos desde Supabase
    try {
      final res = await Supabase.instance.client.from('role_permissions').select('role');
      final Set<String> fromDb = {};
      for (final r in (res as List)) fromDb.add((r['role'] ?? '').toString());
      final all = {...RolePermissions.defaults.keys, ...fromDb}.toList();
      all.sort((a, b) {
        const order = {'admin': 0, 'cashier': 1, 'barber': 2, 'barber_cashier': 3};
        return (order[a] ?? 99).compareTo(order[b] ?? 99);
      });
      if (mounted) setState(() { _roles = all; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() { _roles = ['admin', 'cashier', 'barber', 'barber_cashier']; _isLoading = false; });
    }
  }

  String _descFor(String role) {
    switch (role) {
      case 'admin': return 'Acceso total';
      case 'cashier': return 'Cobra, ve cierre, no edita ni borra';
      case 'barber': return 'Solo sus citas, no edita clientes';
      case 'barber_cashier': return 'Corta y cobra, no edita clientes';
      default: return 'Rol personalizado';
    }
  }

  Future<void> _deleteRole(String role) async {
    if (role == 'admin') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Administrador no se puede borrar'), backgroundColor: Colors.orange));
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Borrar rol', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('¿Borrar rol ${RolePermissions.roleNames[role] ?? role}?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(onPressed: () => Navigator.pop(c, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Borrar')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await Supabase.instance.client.from('role_permissions').delete().eq('role', role);
      await RolePermissions.loadFromSupabase();
      await _loadRoles();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rol borrado'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _newRole() async {
    final nameCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Nuevo Rol', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(controller: nameCtrl, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: 'Nombre del rol', labelStyle: const TextStyle(color: Colors.white54), filled: true, fillColor: const Color(0xFF0F172A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(onPressed: () => Navigator.pop(c, true), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF166534)), child: const Text('Crear')),
        ],
      ),
    );
    if (ok != true) return;
    final raw = nameCtrl.text.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_');
    if (raw.isEmpty) return;
    try {
      for (final p in RolePermissions.defaults['cashier']!) {
        await Supabase.instance.client.from('role_permissions').insert({'role': raw, 'permission': p});
      }
      await RolePermissions.loadFromSupabase();
      await _loadRoles();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Rol $raw creado'), backgroundColor: Colors.green));
        _openEdit(raw, nameCtrl.text.trim());
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.orange));
    }
  }

  Future<void> _openEdit(String role, [String? displayName]) async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => _EditarRolScreen(role: role, displayName: displayName ?? RolePermissions.roleNames[role] ?? role)));
    if (result == true) await _loadRoles();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: const Row(children: [Text('🛡️ ', style: TextStyle(fontSize: 16)), Text('Roles', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))]),
        backgroundColor: const Color(0xFF1E293B),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
            child: ElevatedButton.icon(onPressed: _newRole, icon: const Icon(Icons.add, size: 16), label: const Text('+ Nuevo Rol'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF166534), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)))),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
          : Padding(
              padding: const EdgeInsets.all(16),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 450,
                  mainAxisExtent: 85,
                  crossAxisSpacing: 16, 
                  mainAxisSpacing: 16
                ),
                itemCount: _roles.length,
                itemBuilder: (context, i) {
                  final role = _roles[i];
                  final name = RolePermissions.roleNames[role] ?? role;
                  final color = Color(RolePermissions.roleColors[role] ?? 0xFF6C5CE7);
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.08))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, 
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(children: [
                          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white))),
                          const SizedBox(width: 6),
                          _MiniBtn(label: 'Editar', color: const Color(0xFF166534), onTap: () => _openEdit(role)),
                          const SizedBox(width: 6),
                          _MiniBtn(label: 'Borrar', color: Colors.red, onTap: () => _deleteRole(role)),
                        ]),
                        const SizedBox(height: 6),
                        Text(_descFor(role), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class _MiniBtn extends StatelessWidget {
  final String label; final Color color; final VoidCallback onTap;
  const _MiniBtn({required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(6), child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)), child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))));
  }
}

class _EditarRolScreen extends StatefulWidget {
  final String role; final String displayName;
  const _EditarRolScreen({required this.role, required this.displayName});
  @override
  State<_EditarRolScreen> createState() => _EditarRolScreenState();
}

class _EditarRolScreenState extends State<_EditarRolScreen> {
  late Set<String> _checked;
  bool _saving = false;
  
  @override
  void initState() { 
    super.initState(); 
    _checked = RolePermissions.getPermissions(widget.role); 
  }
  
  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await Supabase.instance.client.from('role_permissions').delete().eq('role', widget.role);
      
      // FIX: Guardar 'none' si está vacío para que no vuelva a los defaults
      if (_checked.isEmpty) {
        await Supabase.instance.client.from('role_permissions').insert({'role': widget.role, 'permission': 'none'});
      } else {
        for (final p in _checked) {
          await Supabase.instance.client.from('role_permissions').insert({'role': widget.role, 'permission': p});
        }
      }
      
      await RolePermissions.loadFromSupabase();
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Rol ${widget.displayName} guardado - ${_checked.length} permisos'), backgroundColor: Colors.green)); Navigator.pop(context, true); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.orange));
    }
    if (mounted) setState(() => _saving = false);
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)), title: Text('Editar Rol - ${widget.displayName}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)), backgroundColor: const Color(0xFF1E293B)),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Nombre', style: TextStyle(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 6),
        Container(width: double.infinity, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12)), child: Text(widget.displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true, 
          physics: const NeverScrollableScrollPhysics(), 
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 300, mainAxisExtent: 50, crossAxisSpacing: 10, mainAxisSpacing: 10), 
          itemCount: BbsPerm.all.length, 
          itemBuilder: (context, i) {
            final perm = BbsPerm.all[i]; final on = _checked.contains(perm);
            return InkWell(
              onTap: () => setState(() { on ? _checked.remove(perm) : _checked.add(perm); }), 
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8), 
                decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(10), border: Border.all(color: on ? const Color(0xFF6366F1) : Colors.white10)), 
                child: Row(children: [
                  Checkbox(value: on, activeColor: const Color(0xFF6366F1), onChanged: (v) => setState(() { v == true ? _checked.add(perm) : _checked.remove(perm); })), 
                  Expanded(child: Text(BbsPerm.labels[perm] ?? perm, style: const TextStyle(color: Colors.white, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis))
                ])
              )
            );
          }
        ),
        const SizedBox(height: 16),
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.12), borderRadius: BorderRadius.circular(10)), child: const Text('Barbero no edita ni elimina clientes, porque van y vienen. Cajero ve cuadratura pero no edita ni borra nada.', style: TextStyle(color: Colors.white70, fontSize: 11))),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: ElevatedButton(onPressed: _saving ? null : _save, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF166534), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: Text(_saving ? 'Guardando...' : 'Guardar', style: const TextStyle(fontWeight: FontWeight.bold)))), 
          const SizedBox(width: 12), 
          Expanded(child: ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: Colors.white24, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text('Cancelar')))
        ]),
      ])),
    );
  }
}