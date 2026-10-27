import 'package:flutter/material.dart';
import '../models/local_service.dart';
import '../repositories/service_repository.dart';
import '../services/settings_service.dart';

class ServicesScreen extends StatefulWidget {
  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  final _serviceRepo = ServiceRepository();
  List<LocalService> _services = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<LocalService> get _filteredServices {
    if (_searchQuery.trim().isEmpty) return _services;
    final q = _searchQuery.trim().toLowerCase();
    return _services.where((s) => s.name.toLowerCase().contains(q)).toList();
  }

  Future<void> _loadServices() async {
    setState(() { _isLoading = true; });
    final services = await _serviceRepo.getAllServices();
    setState(() {
      _services = services;
      _isLoading = false;
    });
  }

  void _showServiceDialog({LocalService? service}) {
    final nameController = TextEditingController(text: service?.name ?? '');
    final priceController = TextEditingController(text: service?.price.toString());
    final durationController = TextEditingController(text: service?.durationMinutes.toString());
    String commissionType = service?.commissionType ?? 'percentage';
    final commissionController = TextEditingController(text: service?.commissionValue.toString());

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(service == null ? 'Nuevo Servicio' : 'Editar Servicio'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nombre *')),
                const SizedBox(height: 8),
                TextField(controller: priceController, decoration: const InputDecoration(labelText: 'Precio *'), keyboardType: TextInputType.number),
                const SizedBox(height: 8),
                TextField(controller: durationController, decoration: const InputDecoration(labelText: 'Duración (minutos)'), keyboardType: TextInputType.number),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: commissionType,
                  decoration: const InputDecoration(labelText: 'Tipo de comisión'),
                  items: const [
                    DropdownMenuItem(value: 'percentage', child: Text('Porcentaje')),
                    DropdownMenuItem(value: 'fixed', child: Text('Fija')),
                  ],
                  onChanged: (value) => setDialogState(() => commissionType = value ?? 'percentage'),
                ),
                const SizedBox(height: 8),
                TextField(controller: commissionController, decoration: const InputDecoration(labelText: 'Comisión'), keyboardType: TextInputType.number),
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
                final newService = LocalService()
                  ..remoteId = service?.remoteId ?? 'srv-${DateTime.now().millisecondsSinceEpoch}'
                  ..name = nameController.text.trim()
                  ..price = double.tryParse(priceController.text) ?? 0.0
                  ..durationMinutes = int.tryParse(durationController.text) ?? 30
                  ..commissionType = commissionType
                  ..commissionValue = double.tryParse(commissionController.text) ?? 0.0
                  ..isActive = true;
                if (service == null) {
                  await _serviceRepo.createService(newService);
                } else {
                  await _serviceRepo.updateService(newService);
                }
                Navigator.pop(context);
                await _loadServices();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(service == null ? 'Servicio creado' : 'Servicio actualizado'), backgroundColor: Colors.green));
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteService(LocalService service) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text('¿Eliminar ${service.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirm == true) {
      await _serviceRepo.deleteService(service.remoteId!);
      await _loadServices();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Servicio eliminado'), backgroundColor: Colors.orange));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _filteredServices;
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.content_cut, size: 22),
            SizedBox(width: 8),
            Expanded(child: Text('Gestión de Servicios', overflow: TextOverflow.ellipsis)),
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
                hintText: 'Buscar servicio por nombre...',
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
                            Icon(Icons.content_cut, size: 64, color: isDark ? Colors.grey[600] : Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(_searchQuery.isNotEmpty ? 'Sin resultados para "$_searchQuery"' : 'No hay servicios registrados', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[400], fontSize: 16)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final service = filtered[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              leading: CircleAvatar(
                                backgroundColor: isDark ? const Color(0xFF312E81) : Colors.indigo[100],
                                child: Icon(Icons.content_cut, size: 20, color: isDark ? const Color(0xFF818CF8) : Colors.indigo[700]),
                              ),
                              title: Text(
                                service.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : Colors.black87),
                              ),
                              subtitle: Text(
                                '${SettingsService.formatCurrency(service.price)} · ${service.durationMinutes} min · Comisión ${service.commissionType == 'percentage' ? '${service.commissionValue}%' : SettingsService.formatCurrency(service.commissionValue)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(icon: const Icon(Icons.edit, color: Colors.amber, size: 20), onPressed: () => _showServiceDialog(service: service)),
                                  IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20), onPressed: () => _deleteService(service)),
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
        onPressed: () => _showServiceDialog(),
        backgroundColor: const Color(0xFF6366F1),
        child: const Icon(Icons.add),
      ),
    );
  }
}