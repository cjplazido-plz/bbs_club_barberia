import 'package:flutter/material.dart';
import '../models/local_client.dart';
import '../repositories/client_repository.dart';
import '../services/settings_service.dart';

class ClientsScreen extends StatefulWidget {
  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> with TickerProviderStateMixin {
  final _clientRepo = ClientRepository();
  List<LocalClient> _clients = [];
  List<LocalClient> _filteredClients = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();
  late AnimationController _mainController;

  @override
  void initState() {
    super.initState();
    _mainController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _loadClients();
  }

  @override
  void dispose() {
    _mainController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadClients() async {
    setState(() { _isLoading = true; });
    final clients = await _clientRepo.getAllClients();
    setState(() {
      _clients = clients;
      _filteredClients = clients;
      _isLoading = false;
    });
    _mainController.forward(from: 0);
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
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(client == null ? 'Nuevo Cliente' : 'Editar Cliente', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _premiumField(nameController, 'Nombre *', '👤', isDark),
                const SizedBox(height: 12),
                _premiumField(phoneController, 'Teléfono', '📱', isDark, keyboardType: TextInputType.phone),
                const SizedBox(height: 12),
                _premiumField(emailController, 'Email', '📧', isDark, keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 12),
                _premiumField(notesController, 'Notas', '📝', isDark, maxLines: 3),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancelar', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]))),
            Container(
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF818CF8)]), borderRadius: BorderRadius.circular(10)),
              child: ElevatedButton(
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
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(client == null ? '✅ Cliente creado' : '✅ Cliente actualizado'), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                child: const Text('Guardar', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _premiumField(TextEditingController controller, String label, String icon, bool isDark, {int maxLines = 1, TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        prefixText: '$icon  ',
        labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13),
        filled: true,
        fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey[50],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.2))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2)),
      ),
    );
  }

  Future<void> _deleteClient(LocalClient client) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Confirmar eliminación'),
          content: Text('¿Eliminar a ${client.name}?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text('Eliminar')),
          ],
        );
      },
    );
    if (confirm == true) {
      await _clientRepo.deleteClient(client.remoteId!);
      await _loadClients();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cliente eliminado'), backgroundColor: Colors.orange, behavior: SnackBarBehavior.floating));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: const Text('Clientes Premium', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre o teléfono...',
                  hintStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[400]),
                  prefixIcon: const Padding(padding: EdgeInsets.all(12), child: Text('🔍', style: TextStyle(fontSize: 20))),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                onChanged: _filterClients,
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
                : _filteredClients.isEmpty
                    ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Text('👥', style: TextStyle(fontSize: 64)), const SizedBox(height: 16), Text('No hay clientes', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey, fontSize: 16))]))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredClients.length,
                        itemBuilder: (context, index) {
                          final client = _filteredClients[index];
                          return AnimatedBuilder(
                            animation: _mainController,
                            builder: (context, child) {
                              final delay = index * 0.05;
                              final anim = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _mainController, curve: Interval(delay, 0.5 + delay, curve: Curves.easeOutCubic)));
                              return FadeTransition(opacity: anim, child: SlideTransition(position: Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(anim), child: child));
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1)),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.04), blurRadius: 10, offset: const Offset(0, 4))],
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                leading: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF818CF8)]),
                                    shape: BoxShape.circle,
                                    boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.3), blurRadius: 8)],
                                  ),
                                  child: Center(child: Text(client.name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                ),
                                title: Text(client.name, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (client.phone != null) Text('📱 ${client.phone}', style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                                    if (client.email != null) Text('✉️ ${client.email}', style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[500] : Colors.grey[500])),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                                      child: Text('Visitas: ${client.totalVisits} | ${SettingsService.formatCurrency(client.totalSpent)}', style: const TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100], borderRadius: BorderRadius.circular(10)), child: IconButton(icon: const Text('✏️', style: TextStyle(fontSize: 16)), onPressed: () => _showClientDialog(client: client))),
                                    const SizedBox(width: 6),
                                    Container(decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: IconButton(icon: const Text('🗑️', style: TextStyle(fontSize: 16)), onPressed: () => _deleteClient(client))),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF818CF8)]), borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 6))]),
        child: FloatingActionButton(onPressed: () => _showClientDialog(), backgroundColor: Colors.transparent, elevation: 0, child: const Icon(Icons.add_rounded, color: Colors.white, size: 28)),
      ),
    );
  }
}
