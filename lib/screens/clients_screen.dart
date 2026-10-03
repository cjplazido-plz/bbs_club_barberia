import 'package:flutter/material.dart';
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
  List<LocalClient> _filteredClients = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  Future<void> _loadClients() async {
    setState(() { _isLoading = true; });
    final clients = await _clientRepo.getAllClients();
    setState(() {
      _clients = clients;
      _filteredClients = clients;
      _isLoading = false;
    });
  }

  void _filterClients(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredClients = _clients;
      } else {
        final lowerQuery = query.toLowerCase();
        _filteredClients = _clients.where((c) => c.name.toLowerCase().contains(lowerQuery) || (c.phone ?? '').contains(query)).toList();
      }
    });
  }

  void _showClientDialog({LocalClient? client}) {
    final nameController = TextEditingController(text: client?.name ?? '');
    final phoneController = TextEditingController(text: client?.phone ?? '');
    final emailController = TextEditingController(text: client?.email ?? '');
    final notesController = TextEditingController(text: client?.notes ?? '');

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
              TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 8),
              TextField(controller: notesController, decoration: const InputDecoration(labelText: 'Notas'), maxLines: 3),
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
              if (client == null) {
                await _clientRepo.createClient(name: nameController.text.trim(), phone: phoneController.text.trim(), email: emailController.text.trim(), notes: notesController.text.trim());
              } else {
                client.name = nameController.text.trim();
                client.phone = phoneController.text.trim();
                client.email = emailController.text.trim();
                client.notes = notesController.text.trim();
                await _clientRepo.updateClient(client);
              }
              Navigator.pop(context);
              await _loadClients();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(client == null ? '✅ Cliente creado' : '✅ Cliente actualizado'), backgroundColor: Colors.green));
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
      await _clientRepo.deleteClient(client.remoteId!);
      await _loadClients();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cliente eliminado'), backgroundColor: Colors.orange));
      }
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
        title: const Text('Gestión de Clientes'),
        backgroundColor: Colors.indigo[700],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(hintText: 'Buscar por nombre o teléfono...', prefixIcon: const Text('🔍', style: TextStyle(fontSize: 20)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
              onChanged: _filterClients,
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredClients.isEmpty
                    ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Text('👥', style: TextStyle(fontSize: 64)), const SizedBox(height: 16), Text('No hay clientes registrados', style: TextStyle(color: Colors.grey[400], fontSize: 16))]))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredClients.length,
                        itemBuilder: (context, index) {
                          final client = _filteredClients[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              leading: CircleAvatar(backgroundColor: Colors.indigo[100], child: Text(client.name[0].toUpperCase(), style: TextStyle(color: Colors.indigo[700]))),
                              title: Text(client.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (client.phone != null) Text('📱 ${client.phone}'),
                                  if (client.email != null) Text(' ${client.email}'),
                                  const SizedBox(height: 4),
                                  Text('Visitas: ${client.totalVisits} | Total: ${SettingsService.formatCurrency(client.totalSpent)}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(icon: const Text('️✏️', style: TextStyle(fontSize: 20)), onPressed: () => _showClientDialog(client: client)),
                                  IconButton(icon: const Text('🗑️', style: TextStyle(fontSize: 20)), onPressed: () => _deleteClient(client)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(onPressed: () => _showClientDialog(), backgroundColor: Colors.indigo[700], child: const Text('➕', style: TextStyle(fontSize: 24))),
    );
  }
}