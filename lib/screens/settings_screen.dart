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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    SettingsService.shopName = _shopNameController.text.trim();
    SettingsService.shopRif = _shopRifController.text.trim();
    SettingsService.shopAddress = _shopAddressController.text.trim();
    SettingsService.shopPhone = _shopPhoneController.text.trim();
    SettingsService.shopLogoUrl = _shopLogoController.text.trim();
    SettingsService.ticketLogoUrl = _ticketLogoController.text.trim();
    SettingsService.ticketHeader = _ticketHeaderController.text.trim();
    SettingsService.ticketFooter = _ticketFooterController.text.trim();

    try {
      // ✅ CORREGIDO: Guardar en Supabase directamente
      await Supabase.instance.client
          .from('settings')
          .upsert({
            'key': 'shop_name',
            'value': SettingsService.shopName,
            'description': 'Nombre de la barbería',
          });
      await Supabase.instance.client
          .from('settings')
          .upsert({
            'key': 'shop_rif',
            'value': SettingsService.shopRif,
            'description': 'RUT de la barbería',
          });
      await Supabase.instance.client
          .from('settings')
          .upsert({
            'key': 'shop_address',
            'value': SettingsService.shopAddress,
            'description': 'Dirección de la barbería',
          });
      await Supabase.instance.client
          .from('settings')
          .upsert({
            'key': 'shop_phone',
            'value': SettingsService.shopPhone,
            'description': 'Teléfono de la barbería',
          });
      await Supabase.instance.client
          .from('settings')
          .upsert({
            'key': 'shop_logo_url',
            'value': SettingsService.shopLogoUrl,
            'description': 'URL del logo principal',
          });
      await Supabase.instance.client
          .from('settings')
          .upsert({
            'key': 'ticket_logo_url',
            'value': SettingsService.ticketLogoUrl,
            'description': 'URL del logo para tickets',
          });
      await Supabase.instance.client
          .from('settings')
          .upsert({
            'key': 'ticket_header',
            'value': SettingsService.ticketHeader,
            'description': 'Encabezado del ticket',
          });
      await Supabase.instance.client
          .from('settings')
          .upsert({
            'key': 'ticket_footer',
            'value': SettingsService.ticketFooter,
            'description': 'Pie del ticket',
          });

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('⚙️ Configuración'),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Información de la Barbería',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _shopNameController,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                labelText: 'Nombre de la barbería',
                labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                filled: true,
                fillColor: isDark ? const Color(0xFF334155) : Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _shopRifController,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                labelText: 'RUT',
                labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                filled: true,
                fillColor: isDark ? const Color(0xFF334155) : Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _shopAddressController,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                labelText: 'Dirección',
                labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                filled: true,
                fillColor: isDark ? const Color(0xFF334155) : Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _shopPhoneController,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                labelText: 'Teléfono',
                labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                filled: true,
                fillColor: isDark ? const Color(0xFF334155) : Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Logo Principal (App)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _shopLogoController,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                labelText: 'URL del logo principal',
                labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                helperText: 'Se muestra en la app',
                helperStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[400]),
                filled: true,
                fillColor: isDark ? const Color(0xFF334155) : Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 8),
            if (SettingsService.shopLogoUrl.isNotEmpty)
              Container(
                height: 100,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: isDark ? Colors.grey[600]! : Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                ),
                child: Image.network(
                  SettingsService.shopLogoUrl,
                  errorBuilder: (context, error, stackTrace) => Center(
                    child: Text('❌ Error al cargar', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            Text(
              'Logo para Ticket (Impresora)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
            ),
            const SizedBox(height: 8),
            Text(
              'Usa un logo en blanco y negro o con buen contraste para impresoras térmicas',
              style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _ticketLogoController,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                labelText: 'URL del logo para ticket',
                labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                helperText: 'Recomendado: PNG con fondo blanco o transparente',
                helperStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[400]),
                filled: true,
                fillColor: isDark ? const Color(0xFF334155) : Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 8),
            if (SettingsService.ticketLogoUrl.isNotEmpty)
              Container(
                height: 100,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: isDark ? Colors.grey[600]! : Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                ),
                child: Image.network(
                  SettingsService.ticketLogoUrl,
                  errorBuilder: (context, error, stackTrace) => Center(
                    child: Text('❌ Error al cargar', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            Text(
              'Configuración del Ticket',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _ticketHeaderController,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                labelText: 'Encabezado del ticket',
                labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                filled: true,
                fillColor: isDark ? const Color(0xFF334155) : Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ticketFooterController,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                labelText: 'Pie del ticket',
                labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                filled: true,
                fillColor: isDark ? const Color(0xFF334155) : Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saveSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('💾 Guardar Configuración', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}