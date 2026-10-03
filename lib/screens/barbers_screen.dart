import 'package:flutter/material.dart';
import '../models/local_barber.dart';
import '../repositories/barber_repository.dart';

class BarbersScreen extends StatefulWidget {
  @override
  State<BarbersScreen> createState() => _BarbersScreenState();
}

class _BarbersScreenState extends State<BarbersScreen> {
  final _barberRepo = BarberRepository();
  List<LocalBarber> _barbers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBarbers();
  }

  Future<void> _loadBarbers() async {
    setState(() { _isLoading = true; });
    final barbers = await _barberRepo.getAllBarbers();
    setState(() {
      _barbers = barbers;
      _isLoading = false;
    });
  }

  void _showBarberDialog({LocalBarber? barber}) {
    final nameController = TextEditingController(text: barber?.name ?? '');
    final phoneController = TextEditingController(text: barber?.phone ?? '');
    final commissionController = TextEditingController(text: barber?.commissionValue.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(barber == null ? 'Nuevo Barbero' : 'Editar Barbero'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nombre *')),
              const SizedBox(height: 8),
              TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Teléfono'), keyboardType: TextInputType.phone),
              const SizedBox(height: 8),
              TextField(controller: commissionController, decoration: const InputDecoration(labelText: 'Comisión (%)'), keyboardType: TextInputType.number),
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
              final newBarber = LocalBarber()
                ..remoteId = barber?.remoteId ?? 'barber-${DateTime.now().millisecondsSinceEpoch}'
                ..name = nameController.text.trim()
                ..phone = phoneController.text.trim()
                ..commissionValue = double.tryParse(commissionController.text) ?? 0.0
                ..commissionRate = double.tryParse(commissionController.text) ?? 0.0
                ..isActive = true;

              if (barber == null) {
                await _barberRepo.createBarber(newBarber);
              } else {
                await _barberRepo.updateBarber(newBarber);
              }
              Navigator.pop(context);
              await _loadBarbers();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(barber == null ? '✅ Barbero creado' : '✅ Barbero actualizado'), backgroundColor: Colors.green));
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteBarber(LocalBarber barber) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text('¿Eliminar a ${barber.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirm == true) {
      await _barberRepo.deleteBarber(barber.remoteId!);
      await _loadBarbers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Barbero eliminado'), backgroundColor: Colors.orange));
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
        title: const Text('Gestión de Barberos'),
        backgroundColor: Colors.indigo[700],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _barbers.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Text('✂️', style: TextStyle(fontSize: 64)), const SizedBox(height: 16), Text('No hay barberos registrados', style: TextStyle(color: Colors.grey[400], fontSize: 16))]))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _barbers.length,
                  itemBuilder: (context, index) {
                    final barber = _barbers[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(backgroundColor: Colors.indigo[100], child: Text(barber.name[0].toUpperCase(), style: TextStyle(color: Colors.indigo[700]))),
                        title: Text(barber.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (barber.phone != null) Text('📱 ${barber.phone}'),
                            Text('💰 Comisión: ${barber.commissionValue}%', style: TextStyle(color: Colors.grey[600])),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Text('✏️', style: TextStyle(fontSize: 20)), onPressed: () => _showBarberDialog(barber: barber)),
                            IconButton(icon: const Text('️🗑️', style: TextStyle(fontSize: 20)), onPressed: () => _deleteBarber(barber)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(onPressed: () => _showBarberDialog(), backgroundColor: Colors.indigo[700], child: const Text('➕', style: TextStyle(fontSize: 24))),
    );
  }
}