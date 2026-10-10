import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/settings_service.dart';
import '../main.dart';

class SettingsScreen extends StatefulWidget {
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _shopNameController = TextEditingController();
  final _shopRifController = TextEditingController();
  final _shopAddressController = TextEditingController();
  final _shopPhoneController = TextEditingController();
  final _shopLogoController = TextEditingController();
  final _ticketLogoController = TextEditingController();
  final _ticketHeaderController = TextEditingController();
  final _ticketFooterController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _shopNameController.text = SettingsService.shopName;
    _shopRifController.text = SettingsService.shopRif;
    _shopAddressController.text = SettingsService.shopAddress;
    _shopPhoneController.text = SettingsService.shopPhone;
    _shopLogoController.text = SettingsService.shopLogoUrl;
    _ticketLogoController.text = SettingsService.ticketLogoUrl;
    _ticketHeaderController.text = SettingsService.ticketHeader;
    _ticketFooterController.text = SettingsService.ticketFooter;
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _shopRifController.dispose();
    _shopAddressController.dispose();
    _shopPhoneController.dispose();
    _shopLogoController.dispose();
    _ticketLogoController.dispose();
    _ticketHeaderController.dispose();
    _ticketFooterController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    SettingsService.shopName = _shopNameController.text.trim();
    SettingsService.shopRif = _shopRifController.text.trim();
    SettingsService.shopAddress = _shopAddressController.text.trim();
    SettingsService.shopPhone = _shopPhoneController.text.trim();
    SettingsService.shopLogoUrl = _shopLogoController.text.trim();
    SettingsService.ticketLogoUrl = _ticketLogoController.text.trim();
    SettingsService.ticketHeader = _ticketHeaderController.text.trim();
    SettingsService.ticketFooter = _ticketFooterController.text.trim();

    try {
      await Supabase.instance.client.from('settings').upsert({'key': 'shop_name', 'value': SettingsService.shopName});
      await Supabase.instance.client.from('settings').upsert({'key': 'shop_rif', 'value': SettingsService.shopRif});
      await Supabase.instance.client.from('settings').upsert({'key': 'shop_address', 'value': SettingsService.shopAddress});
      await Supabase.instance.client.from('settings').upsert({'key': 'shop_phone', 'value': SettingsService.shopPhone});
      await Supabase.instance.client.from('settings').upsert({'key': 'shop_logo_url', 'value': SettingsService.shopLogoUrl});
      await Supabase.instance.client.from('settings').upsert({'key': 'ticket_logo_url', 'value': SettingsService.ticketLogoUrl});
      await Supabase.instance.client.from('settings').upsert({'key': 'ticket_header', 'value': SettingsService.ticketHeader});
      await Supabase.instance.client.from('settings').upsert({'key': 'ticket_footer', 'value': SettingsService.ticketFooter});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Configuración guardada'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error al guardar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('⚙️ Configuración'),
        backgroundColor: Colors.indigo[700],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Información de la Barbería', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(controller: _shopNameController, decoration: const InputDecoration(labelText: 'Nombre de la barbería', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: _shopRifController, decoration: const InputDecoration(labelText: 'RUT', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: _shopAddressController, decoration: const InputDecoration(labelText: 'Dirección', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: _shopPhoneController, decoration: const InputDecoration(labelText: 'Teléfono', border: OutlineInputBorder())),
            const SizedBox(height: 24),
            const Text('Logo Principal (App)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(controller: _shopLogoController, decoration: const InputDecoration(labelText: 'URL del logo principal', border: OutlineInputBorder(), helperText: 'Se muestra en la app')),
            const SizedBox(height: 8),
            if (SettingsService.shopLogoUrl.isNotEmpty)
              Container(height: 100, padding: const EdgeInsets.all(8), decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)), child: Image.network(SettingsService.shopLogoUrl, errorBuilder: (context, error, stackTrace) => const Center(child: Text(' Error al cargar')))),
            const SizedBox(height: 24),
            const Text('Logo para Ticket (Impresora)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Usa un logo en blanco y negro o con buen contraste para impresoras térmicas', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            const SizedBox(height: 8),
            TextField(controller: _ticketLogoController, decoration: const InputDecoration(labelText: 'URL del logo para ticket', border: OutlineInputBorder(), helperText: 'Recomendado: PNG con fondo blanco o transparente')),
            const SizedBox(height: 8),
            if (SettingsService.ticketLogoUrl.isNotEmpty)
              Container(height: 100, padding: const EdgeInsets.all(8), decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)), child: Image.network(SettingsService.ticketLogoUrl, errorBuilder: (context, error, stackTrace) => const Center(child: Text('❌ Error al cargar')))),
            const SizedBox(height: 24),
            const Text('Configuración del Ticket', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(controller: _ticketHeaderController, decoration: const InputDecoration(labelText: 'Encabezado del ticket', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: _ticketFooterController, decoration: const InputDecoration(labelText: 'Pie del ticket', border: OutlineInputBorder())),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saveSettings,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo[700], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                child: const Text('💾 Guardar Configuración', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}