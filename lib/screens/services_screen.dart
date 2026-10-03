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

  @override
  void initState() {
    super.initState();
    _loadServices();
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
    final commissionType = service?.commissionType ?? 'percentage';
    final commissionController = TextEditingController(text: service?.commissionValue.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
              DropdownButtonFormField<String>(value: commissionType, decoration: const InputDecoration(labelText: 'Tipo de comisión'), items: const [DropdownMenuItem(value: 'percentage', child: Text('Porcentaje')), DropdownMenuItem(value: 'fixed', child: Text('Fija'))], onChanged: (value) {}),
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
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(service == null ? '✅ Servicio creado' : '✅ Servicio actualizado'), backgroundColor: Colors.green));
              }
            },
            child: const Text('Guardar'),
          ),
        ],
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
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Text('←', style: TextStyle(fontSize: 24, color: Colors.white)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Gestión de Servicios'),
        backgroundColor: Colors.indigo[700],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _services.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Text('✂️', style: TextStyle(fontSize: 64)), const SizedBox(height: 16), Text('No hay servicios registrados', style: TextStyle(color: Colors.grey[400], fontSize: 16))]))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _services.length,
                  itemBuilder: (context, index) {
                    final service = _services[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.indigo[100], shape: BoxShape.circle), child: const Text('✂️', style: TextStyle(fontSize: 24))),
                        title: Text(service.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('💰 ${SettingsService.formatCurrency(service.price)}', style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.bold)),
                            Text('️ ${service.durationMinutes} min | Comisión: ${service.commissionValue}%', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Text('✏️', style: TextStyle(fontSize: 20)), onPressed: () => _showServiceDialog(service: service)),
                            IconButton(icon: const Text('🗑️', style: TextStyle(fontSize: 20)), onPressed: () => _deleteService(service)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(onPressed: () => _showServiceDialog(), backgroundColor: Colors.indigo[700], child: const Text('➕', style: TextStyle(fontSize: 24))),
    );
  }
}