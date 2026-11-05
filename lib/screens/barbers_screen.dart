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
    setState(() { _barbers = barbers; _isLoading = false; });
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
    return Padding(padding: const EdgeInsets.only(left: 4, bottom: 6), child: Row(children: [Text(icon, style: const TextStyle(fontSize: 13)), const SizedBox(width: 6), Text(required ? "$label *" : label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700))])); 
  }

  void _showBarberDialog({LocalBarber? barber}) {
    final nameController = TextEditingController(text: barber?.name ?? '');
    final phoneController = TextEditingController(text: barber?.phone ?? '');
    final commissionController = TextEditingController(text: barber?.commissionValue.toString());

    showDialog(context: context, builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(barber == null ? 'Nuevo Barbero' : 'Editar Barbero', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      content: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _fieldLabel('👤', 'Nombre Completo del Barbero', true),
        TextField(controller: nameController, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500), decoration: _dec('Nombre *', '')),
        const SizedBox(height: 14),
        _fieldLabel('📱', 'Telefono / WhatsApp', false),
        TextField(controller: phoneController, style: const TextStyle(color: Colors.white, fontSize: 14), decoration: _dec('Telefono', ''), keyboardType: TextInputType.phone),
        const SizedBox(height: 14),
        _fieldLabel('💰', 'Porcentaje Comision (%)', false),
        TextField(controller: commissionController, style: const TextStyle(color: Colors.white, fontSize: 14), decoration: _dec('Comision (%)', ''), keyboardType: TextInputType.number),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey, fontSize: 13))),
        Container(decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF818CF8)]), borderRadius: BorderRadius.circular(10)), child: ElevatedButton(onPressed: () async {
          if (nameController.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El nombre es obligatorio'), backgroundColor: Colors.red)); return; }
          final newBarber = LocalBarber()
            ..remoteId = barber?.remoteId ?? 'barber-${DateTime.now().millisecondsSinceEpoch}'
            ..name = nameController.text.trim()
            ..phone = phoneController.text.trim()
            ..commissionValue = double.tryParse(commissionController.text) ?? 0.0
            ..commissionRate = double.tryParse(commissionController.text) ?? 0.0
            ..isActive = true;
          if (barber == null) await _barberRepo.createBarber(newBarber); else await _barberRepo.updateBarber(newBarber);
          Navigator.pop(context);
          await _loadBarbers();
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(barber == null ? '✅ Barbero creado' : '✅ Barbero actualizado'), backgroundColor: Colors.green));
        }, style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text('Guardar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)))),
      ],
    ));
  }

  Future<void> _deleteBarber(LocalBarber barber) async {
    final confirm = await showDialog<bool>(context: context, builder: (context) => AlertDialog(backgroundColor: const Color(0xFF1E293B), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), title: const Text('Confirmar eliminacion', style: TextStyle(color: Colors.white, fontSize: 15)), content: Text('¿Eliminar a ${barber.name}?', style: const TextStyle(color: Colors.white70, fontSize: 13)), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))), ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text('Eliminar', style: TextStyle(fontSize: 13)))]));
    if (confirm == true) { await _barberRepo.deleteBarber(barber.remoteId!); await _loadBarbers(); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Barbero eliminado'), backgroundColor: Colors.orange)); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)), title: const Text('Barberos Premium', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), backgroundColor: const Color(0xFF1E293B), foregroundColor: Colors.white, elevation: 0),
      body: _isLoading ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1))) : _barbers.isEmpty ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('✂️', style: TextStyle(fontSize: 64)), SizedBox(height: 16), Text('No hay barberos registrados', style: TextStyle(color: Colors.white54, fontSize: 15))])) : ListView.builder(padding: const EdgeInsets.all(16), itemCount: _barbers.length, itemBuilder: (context, index) {
        final barber = _barbers[index];
        final phoneText = barber.phone != null ? "📱 ${barber.phone}" : "";
        final commissionText = "💰 Comision: ${barber.commissionValue}%";
        return Container(margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.05)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 12, offset: const Offset(0,4))]), child: ListTile(contentPadding: const EdgeInsets.all(14), leading: CircleAvatar(backgroundColor: const Color(0xFF6366F1).withOpacity(0.15), child: Text(barber.name.isNotEmpty ? barber.name[0].toUpperCase() : '?', style: const TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold, fontSize: 14))), title: Text(barber.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)), subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [if (phoneText.isNotEmpty) Text(phoneText, style: const TextStyle(color: Colors.white70, fontSize: 12)), Text(commissionText, style: const TextStyle(color: Colors.white54, fontSize: 11))]), trailing: Row(mainAxisSize: MainAxisSize.min, children: [Container(decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(10)), child: IconButton(icon: const Text('✏️', style: TextStyle(fontSize: 16)), onPressed: () => _showBarberDialog(barber: barber))), const SizedBox(width: 6), Container(decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: IconButton(icon: const Text('🗑️', style: TextStyle(fontSize: 16)), onPressed: () => _deleteBarber(barber)))])));
      }),
      floatingActionButton: Container(decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF818CF8)]), borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.4), blurRadius: 12, offset: const Offset(0,6))]), child: FloatingActionButton(onPressed: () => _showBarberDialog(), backgroundColor: Colors.transparent, elevation: 0, child: const Icon(Icons.add_rounded, color: Colors.white, size: 28))),
    );
  }
}
