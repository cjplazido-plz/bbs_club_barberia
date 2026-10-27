import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/local_client.dart';
import '../repositories/client_repository.dart';
import '../services/settings_service.dart';

class ClientsScreen extends StatefulWidget {
  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  final _clientRepo = ClientRepository();
  List<LocalClient> _clients = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<LocalClient> get _filteredClients {
    if (_searchQuery.trim().isEmpty) return _clients;
    final q = _searchQuery.trim().toLowerCase();
    return _clients.where((c) {
      final name = c.name.toLowerCase();
      final phone = (c.phone ?? '').toLowerCase();
      return name.contains(q) || phone.contains(q);
    }).toList();
  }

  Future<void> _loadClients() async {
    setState(() { _isLoading = true; });
    final clients = await _clientRepo.getAllClients();
    setState(() {
      _clients = clients;
      _isLoading = false;
    });
  }

  void _showClientDialog({LocalClient? client}) {
    final nameController = TextEditingController(text: client?.name ?? '');
    final phoneController = TextEditingController(text: client?.phone ?? '');
    final emailController = TextEditingController(text: client?.email ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(client == null ? 'Nuevo Cliente' : 'Editar Cliente'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nombre *')),
              const SizedBox(height: 8),
              TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Teléfono'), keyboardType: TextInputType.phone),
              const SizedBox(height: 8),
              TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El nombre es obligatorio'), backgroundColor: Colors.red));
                return;
              }
              final newId = client?.remoteId ?? 'cli-${DateTime.now().millisecondsSinceEpoch}';
              final data = {
                'id': newId,
                'name': nameController.text.trim(),
                'phone': phoneController.text.trim(),
                'email': emailController.text.trim(),
              };
              if (client == null) {
                await Supabase.instance.client.from('clients').insert(data);
              } else {
                await Supabase.instance.client.from('clients').update(data).eq('id', client.remoteId!);
              }
              Navigator.pop(context);
              await _loadClients();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(client == null ? 'Cliente creado' : 'Cliente actualizado'), backgroundColor: Colors.green));
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteClient(LocalClient client) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text('¿Eliminar a ${client.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirm == true) {
      await Supabase.instance.client.from('clients').delete().eq('id', client.remoteId!);
      await _loadClients();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cliente eliminado'), backgroundColor: Colors.orange));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _filteredClients;
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.people, size: 22),
            SizedBox(width: 8),
            Expanded(child: Text('Gestión de Clientes', overflow: TextOverflow.ellipsis)),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o teléfono...',
                hintStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[500], fontSize: 13),
                prefixIcon: Icon(Icons.search, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(icon: Icon(Icons.clear, color: isDark ? Colors.grey[400] : Colors.grey[600]), onPressed: () { _searchController.clear(); setState(() => _searchQuery = ''); })
                    : null,
                filled: true,
                fillColor: isDark ? const Color(0xFF334155) : Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF6366F1))),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline, size: 64, color: isDark ? Colors.grey[600] : Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(_searchQuery.isNotEmpty ? 'Sin resultados para "$_searchQuery"' : 'No hay clientes registrados', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[400], fontSize: 16)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final client = filtered[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              leading: CircleAvatar(
                                backgroundColor: isDark ? const Color(0xFF312E81) : Colors.indigo[100],
                                child: Text(
                                  client.name.isNotEmpty ? client.name[0].toUpperCase() : '?',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF818CF8) : Colors.indigo[700]),
                                ),
                              ),
                              title: Text(
                                client.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : Colors.black87),
                              ),
                              subtitle: Text(
                                client.phone ?? 'Sin teléfono',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(icon: const Icon(Icons.edit, color: Colors.amber, size: 20), onPressed: () => _showClientDialog(client: client)),
                                  IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20), onPressed: () => _deleteClient(client)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showClientDialog(),
        backgroundColor: const Color(0xFF6366F1),
        child: const Icon(Icons.add),
      ),
    );
  }
}