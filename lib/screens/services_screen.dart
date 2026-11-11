import 'package:flutter/material.dart';
import '../models/local_service.dart';
import '../repositories/service_repository.dart';
import '../services/settings_service.dart';
import '../main.dart';
import '../services/role_permissions.dart';

class ServicesScreen extends StatefulWidget {
  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> with TickerProviderStateMixin {
  final _serviceRepo = ServiceRepository();
  List<LocalService> _services = [];
  bool _isLoading = true;
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _loadServices();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _loadServices() async {
    setState(() => _isLoading = true);
    final services = await _serviceRepo.getAllServices();
    setState(() {
      _services = services;
      _isLoading = false;
    });
    _ctrl.forward(from: 0);
  }

  void _showServiceDialog({LocalService? service}) {
    final nameCtrl = TextEditingController(text: service?.name ?? '');
    final priceCtrl = TextEditingController(text: service?.price.toString() ?? '');
    final durationCtrl = TextEditingController(text: service?.durationMinutes.toString() ?? '60');
    final commCtrl = TextEditingController(text: service?.commissionValue.toString() ?? '50');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(service == null ? 'Nuevo Servicio' : 'Editar Servicio', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _field(nameCtrl, 'Nombre *', Icons.cut_rounded),
              const SizedBox(height: 12),
              _field(priceCtrl, 'Precio *', Icons.attach_money_rounded, keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              _field(durationCtrl, 'Duración (min)', Icons.timer_rounded, keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              _field(commCtrl, 'Comisión %', Icons.percent_rounded, keyboardType: TextInputType.number),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
            Container(
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF818CF8)]), borderRadius: BorderRadius.circular(10)),
              child: ElevatedButton(
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El nombre es obligatorio'), backgroundColor: Colors.red));
                    return;
                  }
                  final newService = LocalService()
                    ..remoteId = service?.remoteId ?? 'srv-${DateTime.now().millisecondsSinceEpoch}'
                    ..name = nameCtrl.text.trim()
                    ..price = double.tryParse(priceCtrl.text) ?? 0.0
                    ..durationMinutes = int.tryParse(durationCtrl.text) ?? 60
                    ..commissionType = 'percentage'
                    ..commissionValue = double.tryParse(commCtrl.text) ?? 50.0
                    ..isActive = true;
                  if (service == null) {
                    await _serviceRepo.createService(newService);
                  } else {
                    await _serviceRepo.updateService(newService);
                  }
                  Navigator.pop(context);
                  await _loadServices();
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

  Widget _field(TextEditingController c, String label, IconData icon, {TextInputType? keyboardType}) {
    return TextField(
      controller: c,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18, color: const Color(0xFF818CF8)),
        labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
        filled: true,
        fillColor: const Color(0xFF0F172A),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withOpacity(0.08))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2)),
      ),
    );
  }

  Future<void> _deleteService(LocalService service) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirmar eliminación', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('¿Eliminar ${service.name}?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          Container(decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)), child: ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent), child: const Text('Eliminar'))),
        ],
      ),
    );
    if (confirm == true) {
      await _serviceRepo.deleteService(service.remoteId!);
      await _loadServices();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = RolePermissions.isAdmin(currentUserRole);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: const Text('Servicios Premium', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
          : _services.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: const Color(0xFF1E293B), shape: BoxShape.circle), child: const Icon(Icons.content_cut_rounded, size: 32, color: Colors.white24)), const SizedBox(height: 16), const Text('No hay servicios', style: TextStyle(color: Colors.white38))]))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _services.length,
                  itemBuilder: (context, index) {
                    final s = _services[index];
                    return AnimatedBuilder(
                      animation: _ctrl,
                      builder: (context, child) {
                        final delay = index * 0.06;
                        final anim = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _ctrl, curve: Interval(delay, 0.6 + delay, curve: Curves.easeOutCubic)));
                        return FadeTransition(opacity: anim, child: SlideTransition(position: Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(anim), child: child));
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.06)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 12, offset: const Offset(0, 4))]),
                        child: Material(
                          type: MaterialType.transparency,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            leading: Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.15), shape: BoxShape.circle, border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.25))), child: const Icon(Icons.content_cut_rounded, size: 20, color: Color(0xFF818CF8))),
                            title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)),
                            subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const SizedBox(height: 4),
                              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.15), borderRadius: BorderRadius.circular(20)), child: Text(SettingsService.formatCurrency(s.price), style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold))),
                              const SizedBox(height: 4),
                              Row(children: [const Icon(Icons.timer_outlined, size: 12, color: Colors.white38), const SizedBox(width: 4), Text('${s.durationMinutes} min | ${s.commissionValue.toInt()}%', style: const TextStyle(color: Colors.white38, fontSize: 11))]),
                            ]),
                            trailing: isAdmin ? Row(mainAxisSize: MainAxisSize.min, children: [
                              Container(decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.12), borderRadius: BorderRadius.circular(10)), child: IconButton(icon: const Icon(Icons.edit_rounded, size: 18, color: Color(0xFF818CF8)), onPressed: () => _showServiceDialog(service: s))),
                              const SizedBox(width: 6),
                              Container(decoration: BoxDecoration(color: Colors.red.withOpacity(0.12), borderRadius: BorderRadius.circular(10)), child: IconButton(icon: const Icon(Icons.delete_rounded, size: 18, color: Color(0xFFEF4444)), onPressed: () => _deleteService(s))),
                            ]) : null,
                          ),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: isAdmin ? Container(decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF818CF8)]), borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 6))]), child: FloatingActionButton(onPressed: () => _showServiceDialog(), backgroundColor: Colors.transparent, elevation: 0, child: const Icon(Icons.add_rounded, color: Colors.white, size: 28))) : null,
    );
  }
}