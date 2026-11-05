import 'package:flutter/material.dart';
import '../models/local_service.dart';
import '../repositories/service_repository.dart';
import '../services/settings_service.dart';

class ServicesScreen extends StatefulWidget {
  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> with TickerProviderStateMixin {
  final _serviceRepo = ServiceRepository();
  List<LocalService> _services = [];
  bool _isLoading = true;
  late AnimationController _mainController;

  @override
  void initState() {
    super.initState();
    _mainController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _loadServices();
  }

  @override
  void dispose() {
    _mainController.dispose();
    super.dispose();
  }

  Future<void> _loadServices() async {
    setState(() { _isLoading = true; });
    final services = await _serviceRepo.getAllServices();
    setState(() {
      _services = services;
      _isLoading = false;
    });
    _mainController.forward(from: 0);
  }

  void _showServiceDialog({LocalService? service}) {
    final nameController = TextEditingController(text: service?.name ?? '');
    final priceController = TextEditingController(text: service?.price.toString());
    final durationController = TextEditingController(text: service?.durationMinutes.toString());
    final commissionType = service?.commissionType ?? 'percentage';
    final commissionController = TextEditingController(text: service?.commissionValue.toString());

    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(service == null ? 'Nuevo Servicio' : 'Editar Servicio', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(nameController, 'Nombre *', '✂️', isDark),
                const SizedBox(height: 12),
                _field(priceController, 'Precio *', '💰', isDark, keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                _field(durationController, 'Duración (min)', '⏱️', isDark, keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: commissionType,
                  dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    labelText: 'Tipo de comisión',
                    prefixText: '📊  ',
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey[50],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2)),
                  ),
                  items: const [DropdownMenuItem(value: 'percentage', child: Text('Porcentaje')), DropdownMenuItem(value: 'fixed', child: Text('Fija'))],
                  onChanged: (value) {},
                ),
                const SizedBox(height: 12),
                _field(commissionController, 'Comisión', '💵', isDark, keyboardType: TextInputType.number),
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
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(service == null ? '✅ Servicio creado' : '✅ Servicio actualizado'), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
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

  Widget _field(TextEditingController c, String label, String icon, bool isDark, {TextInputType? keyboardType}) {
    return TextField(
      controller: c,
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

  Future<void> _deleteService(LocalService service) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Confirmar eliminación'),
          content: Text('¿Eliminar ${service.name}?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text('Eliminar')),
          ],
        );
      },
    );
    if (confirm == true) {
      await _serviceRepo.deleteService(service.remoteId!);
      await _loadServices();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Servicio eliminado'), backgroundColor: Colors.orange, behavior: SnackBarBehavior.floating));
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
        title: const Text('Servicios Premium', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
          : _services.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Text('✂️', style: TextStyle(fontSize: 64)), const SizedBox(height: 16), Text('No hay servicios', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey, fontSize: 16))]))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _services.length,
                  itemBuilder: (context, index) {
                    final service = _services[index];
                    return AnimatedBuilder(
                      animation: _mainController,
                      builder: (context, child) {
                        final delay = index * 0.07;
                        final anim = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _mainController, curve: Interval(delay, 0.6 + delay, curve: Curves.easeOutCubic)));
                        return FadeTransition(opacity: anim, child: SlideTransition(position: Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(anim), child: child));
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.08)),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.25 : 0.05), blurRadius: 15, offset: const Offset(0, 6))],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(18),
                          leading: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [const Color(0xFF6366F1).withOpacity(0.15), const Color(0xFF818CF8).withOpacity(0.15)]),
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.2)),
                            ),
                            child: const Text('✂️', style: TextStyle(fontSize: 20)),
                          ),
                          title: Text(service.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : Colors.black87)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                                child: Text('💰 ${SettingsService.formatCurrency(service.price)}', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                              const SizedBox(height: 4),
                              Text('⏱️ ${service.durationMinutes} min | 💼 ${service.commissionValue}%', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 11)),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100], borderRadius: BorderRadius.circular(10)), child: IconButton(icon: const Icon(Icons.edit_rounded, size: 18, color: Color(0xFF6366F1)), onPressed: () => _showServiceDialog(service: service))),
                              const SizedBox(width: 6),
                              Container(decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: IconButton(icon: const Icon(Icons.delete_rounded, size: 18, color: Colors.red), onPressed: () => _deleteService(service))),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: Container(
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF818CF8)]), borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 6))]),
        child: FloatingActionButton(onPressed: () => _showServiceDialog(), backgroundColor: Colors.transparent, elevation: 0, child: const Icon(Icons.add_rounded, color: Colors.white, size: 28)),
      ),
    );
  }
}
