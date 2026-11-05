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

  InputDecoration _dec(String label, String icon) {
    return InputDecoration(
      labelText: label,
      prefixText: '$icon  ',
      labelStyle: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
      floatingLabelStyle: const TextStyle(color: Color(0xFF6366F1), fontSize: 13, fontWeight: FontWeight.bold),
      filled: true,
      fillColor: const Color(0xFF0F172A),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.white10)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.white10)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2)),
    );
  }

  Widget _fieldLabel(String icon, String label, bool required) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Row(children: [
        Text(icon, style: const TextStyle(fontSize: 13)),
        const SizedBox(width: 6),
        Text(required ? "$label *" : label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  void _showClientDialog({LocalClient? client}) {
    final nameController = TextEditingController(text: client?.name ?? '');
    final phoneController = TextEditingController(text: client?.phone ?? '');
    final emailController = TextEditingController(text: client?.email ?? '');
    final notesController = TextEditingController(text: client?.notes ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(client == null ? 'Nuevo Cliente' : 'Editar Cliente', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _fieldLabel('👤', 'Nombre Completo', true),
            TextField(controller: nameController, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500), decoration: _dec('Nombre *', '')),
            const SizedBox(height: 14),
            _fieldLabel('📱', 'Telefono / WhatsApp', false),
            TextField(controller: phoneController, style: const TextStyle(color: Colors.white, fontSize: 14), decoration: _dec('Telefono', ''), keyboardType: TextInputType.phone),
            const SizedBox(height: 14),
            _fieldLabel('✉️', 'Email de Contacto', false),
            TextField(controller: emailController, style: const TextStyle(color: Colors.white, fontSize: 14), decoration: _dec('Email', ''), keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 14),
            _fieldLabel('📝', 'Notas / Preferencias', false),
            TextField(controller: notesController, style: const TextStyle(color: Colors.white, fontSize: 14), decoration: _dec('Notas', ''), maxLines: 3),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey, fontSize: 13))),
          Container(decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF818CF8)]), borderRadius: BorderRadius.circular(10)), child: ElevatedButton(onPressed: () async {
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
          }, style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text('Guardar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)))),
        ],
      ),
    );
  }

  Future<void> _deleteClient(LocalClient client) async {
    final confirm = await showDialog<bool>(context: context, builder: (context) => AlertDialog(backgroundColor: const Color(0xFF1E293B), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), title: const Text('Confirmar eliminacion', style: TextStyle(color: Colors.white, fontSize: 15)), content: Text('¿Eliminar a ${client.name}?', style: const TextStyle(color: Colors.white70, fontSize: 13)), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))), ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text('Eliminar', style: TextStyle(fontSize: 13)))]));
    if (confirm == true) {
      await _clientRepo.deleteClient(client.remoteId!);
      await _loadClients();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cliente eliminado'), backgroundColor: Colors.orange));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)), title: const Text('Clientes Premium', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), backgroundColor: const Color(0xFF1E293B), foregroundColor: Colors.white, elevation: 0),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(16), child: TextField(controller: _searchController, style: const TextStyle(color: Colors.white, fontSize: 14), decoration: InputDecoration(hintText: 'Buscar por nombre o telefono...', hintStyle: const TextStyle(color: Colors.white38, fontSize: 13), prefixIcon: const Padding(padding: EdgeInsets.all(12), child: Text('🔍', style: TextStyle(fontSize: 18))), filled: true, fillColor: const Color(0xFF1E293B), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)), onChanged: _filterClients)),
        Expanded(child: _isLoading ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1))) : _filteredClients.isEmpty ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('👥', style: TextStyle(fontSize: 64)), SizedBox(height: 16), Text('No hay clientes registrados', style: TextStyle(color: Colors.white54, fontSize: 15))])) : ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: _filteredClients.length, itemBuilder: (context, index) {
          final client = _filteredClients[index];
          final phoneText = client.phone != null ? "📱 ${client.phone}" : "";
          final visitsText = "Visitas: ${client.totalVisits} | Total: ${SettingsService.formatCurrency(client.totalSpent)}";
          return Container(margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.05)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 12, offset: const Offset(0,4))]), child: ListTile(contentPadding: const EdgeInsets.all(14), leading: CircleAvatar(backgroundColor: const Color(0xFF6366F1).withOpacity(0.15), child: Text(client.name.isNotEmpty ? client.name[0].toUpperCase() : '?', style: const TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold, fontSize: 14))), title: Text(client.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)), subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [if (phoneText.isNotEmpty) Text(phoneText, style: const TextStyle(color: Colors.white70, fontSize: 12)), if (client.email != null && client.email!.isNotEmpty) Text("✉️ ${client.email}", style: const TextStyle(color: Colors.white54, fontSize: 11)), const SizedBox(height: 4), Text(visitsText, style: const TextStyle(color: Colors.white38, fontSize: 11))]), trailing: Row(mainAxisSize: MainAxisSize.min, children: [Container(decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(10)), child: IconButton(icon: const Text('✏️', style: TextStyle(fontSize: 16)), onPressed: () => _showClientDialog(client: client))), const SizedBox(width: 6), Container(decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: IconButton(icon: const Text('🗑️', style: TextStyle(fontSize: 16)), onPressed: () => _deleteClient(client)))])));
        })),
      ]),
      floatingActionButton: Container(decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF818CF8)]), borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.4), blurRadius: 12, offset: const Offset(0,6))]), child: FloatingActionButton(onPressed: () => _showClientDialog(), backgroundColor: Colors.transparent, elevation: 0, child: const Icon(Icons.add_rounded, color: Colors.white, size: 28))),
    );
  }
}
