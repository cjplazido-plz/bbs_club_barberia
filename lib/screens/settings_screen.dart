import 'package:flutter/material.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;

  final _shopNameController = TextEditingController();
  final _shopRifController = TextEditingController();
  final _shopAddressController = TextEditingController();
  final _shopPhoneController = TextEditingController();
  final _shopEmailController = TextEditingController();
  final _shopLogoUrlController = TextEditingController();
  final _currencySymbolController = TextEditingController();
  final _currencyCodeController = TextEditingController();
  final _ticketHeaderController = TextEditingController();
  final _ticketFooterController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() { _isLoading = true; });
    await SettingsService.loadSettings();
    setState(() {
      _shopNameController.text = SettingsService.shopName;
      _shopRifController.text = SettingsService.shopRif;
      _shopAddressController.text = SettingsService.shopAddress;
      _shopPhoneController.text = SettingsService.shopPhone;
      _shopEmailController.text = SettingsService.shopEmail;
      _shopLogoUrlController.text = SettingsService.shopLogoUrl;
      _currencySymbolController.text = SettingsService.currencySymbol;
      _currencyCodeController.text = SettingsService.currencyCode;
      _ticketHeaderController.text = SettingsService.ticketHeader;
      _ticketFooterController.text = SettingsService.ticketFooter;
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Por favor completa todos los campos obligatorios'), backgroundColor: Colors.red),
      );
      return;
    }
    setState(() { _isSaving = true; });
    try {
      print('🔄 Guardando configuración...');
      final success = await SettingsService.updateMultiple({
        'shop_name': _shopNameController.text.trim(),
        'shop_rif': _shopRifController.text.trim(),
        'shop_address': _shopAddressController.text.trim(),
        'shop_phone': _shopPhoneController.text.trim(),
        'shop_email': _shopEmailController.text.trim(),
        'shop_logo_url': _shopLogoUrlController.text.trim(),
        'currency_symbol': _currencySymbolController.text.trim(),
        'currency_code': _currencyCodeController.text.trim(),
        'ticket_header': _ticketHeaderController.text.trim(),
        'ticket_footer': _ticketFooterController.text.trim(),
      });
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Configuración guardada correctamente'), backgroundColor: Colors.green, duration: Duration(seconds: 3)),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('⚠️ Algunos valores no se pudieron guardar'), backgroundColor: Colors.orange, duration: Duration(seconds: 3)),
          );
        }
      }
    } catch (e) {
      print('❌ Error al guardar: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red, duration: const Duration(seconds: 5)),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isSaving = false; });
      }
    }
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _shopRifController.dispose();
    _shopAddressController.dispose();
    _shopPhoneController.dispose();
    _shopEmailController.dispose();
    _shopLogoUrlController.dispose();
    _currencySymbolController.dispose();
    _currencyCodeController.dispose();
    _ticketHeaderController.dispose();
    _ticketFooterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Text('←', style: TextStyle(fontSize: 24, color: Colors.white)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Configuración de la Barbería'),
        backgroundColor: Colors.indigo[700],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.indigo[100], borderRadius: BorderRadius.circular(12)),
                          child: const Text('🏪', style: TextStyle(fontSize: 32)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Información de la Barbería', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text('Configura los datos que aparecerán en tickets y reportes', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    _buildSection(title: 'Nombre de la barbería', icon: '🏪', child: TextFormField(
                      controller: _shopNameController,
                      decoration: const InputDecoration(labelText: 'Nombre *', hintText: 'Ej: Barbería El Clásico', border: OutlineInputBorder()),
                      validator: (value) { if (value == null || value.trim().isEmpty) return 'El nombre es obligatorio'; return null; },
                    )),
                    const SizedBox(height: 16),
                    _buildSection(title: 'RUT', icon: '', child: TextFormField(
                      controller: _shopRifController,
                      decoration: const InputDecoration(labelText: 'RUT', hintText: 'Ej: J-12345678-9', border: OutlineInputBorder()),
                    )),
                    const SizedBox(height: 16),
                    _buildSection(title: 'Dirección', icon: '', child: TextFormField(
                      controller: _shopAddressController,
                      decoration: const InputDecoration(labelText: 'Dirección', hintText: 'Ej: Av. Principal, Local 5', border: OutlineInputBorder()),
                      maxLines: 2,
                    )),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildSection(title: 'Teléfono', icon: '', child: TextFormField(
                          controller: _shopPhoneController,
                          decoration: const InputDecoration(labelText: 'Teléfono', hintText: '+56 9 1234 5678', border: OutlineInputBorder()),
                          keyboardType: TextInputType.phone,
                        ))),
                        const SizedBox(width: 16),
                        Expanded(child: _buildSection(title: 'Email', icon: '📧', child: TextFormField(
                          controller: _shopEmailController,
                          decoration: const InputDecoration(labelText: 'Email', hintText: 'contacto@barberia.com', border: OutlineInputBorder()),
                          keyboardType: TextInputType.emailAddress,
                        ))),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildSection(title: 'Logo', icon: '🖼️', child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _shopLogoUrlController,
                          decoration: const InputDecoration(labelText: 'URL del logo', hintText: 'https://ejemplo.com/logo.png', border: OutlineInputBorder(), helperText: 'Pega aquí la URL de tu logo'),
                        ),
                        const SizedBox(height: 8),
                        if (_shopLogoUrlController.text.isNotEmpty)
                          Container(
                            height: 80,
                            decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(8)),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                _shopLogoUrlController.text,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) => const Center(child: Text('❌', style: TextStyle(fontSize: 40))),
                              ),
                            ),
                          ),
                      ],
                    )),
                    const SizedBox(height: 32),
                    const Text('Moneda', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildSection(title: 'Símbolo', icon: '💲', child: TextFormField(
                          controller: _currencySymbolController,
                          decoration: const InputDecoration(labelText: 'Símbolo', hintText: '\$', border: OutlineInputBorder()),
                          validator: (value) { if (value == null || value.trim().isEmpty) return 'El símbolo es obligatorio'; return null; },
                        ))),
                        const SizedBox(width: 16),
                        Expanded(child: _buildSection(title: 'Código', icon: '', child: TextFormField(
                          controller: _currencyCodeController,
                          decoration: const InputDecoration(labelText: 'Código', hintText: 'CLP', border: OutlineInputBorder()),
                          validator: (value) { if (value == null || value.trim().isEmpty) return 'El código es obligatorio'; return null; },
                        ))),
                      ],
                    ),
                    const SizedBox(height: 32),
                    const Text('Ticket', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    _buildSection(title: 'Encabezado del ticket', icon: '📝', child: TextFormField(
                      controller: _ticketHeaderController,
                      decoration: const InputDecoration(labelText: 'Encabezado', hintText: 'BARBERFLOW POS', border: OutlineInputBorder()),
                      validator: (value) { if (value == null || value.trim().isEmpty) return 'El encabezado es obligatorio'; return null; },
                    )),
                    const SizedBox(height: 16),
                    _buildSection(title: 'Pie del ticket', icon: '📄', child: TextFormField(
                      controller: _ticketFooterController,
                      decoration: const InputDecoration(labelText: 'Pie', hintText: '¡Gracias por su visita!', border: OutlineInputBorder()),
                    )),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveSettings,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo[700], disabledBackgroundColor: Colors.grey[300], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        child: _isSaving
                            ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)), SizedBox(width: 12), Text('Guardando...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))])
                            : const Text('GUARDAR CONFIGURACIÓN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[300]!)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Vista previa del ticket:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 12),
                          Center(child: Text(_ticketHeaderController.text.isNotEmpty ? _ticketHeaderController.text : 'BARBER_PLZ POS', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                          if (_shopRifController.text.isNotEmpty) Center(child: Text('RUT: ${_shopRifController.text}', style: const TextStyle(fontSize: 12))),
                          if (_shopAddressController.text.isNotEmpty) Center(child: Text(_shopAddressController.text, style: const TextStyle(fontSize: 12))),
                          if (_shopPhoneController.text.isNotEmpty) Center(child: Text('Tel: ${_shopPhoneController.text}', style: const TextStyle(fontSize: 12))),
                          const SizedBox(height: 12),
                          const Divider(),
                          const SizedBox(height: 12),
                          Center(child: Text(_ticketFooterController.text.isNotEmpty ? _ticketFooterController.text : '¡Gracias por su visita!', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey[600]))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSection({required String title, required String icon, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(icon, style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}