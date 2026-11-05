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
  final _ticketLogoUrlController = TextEditingController();
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
      _ticketLogoUrlController.text = SettingsService.ticketLogoUrl;
      _currencySymbolController.text = SettingsService.currencySymbol;
      _currencyCodeController.text = SettingsService.currencyCode;
      _ticketHeaderController.text = SettingsService.ticketHeader;
      _ticketFooterController.text = SettingsService.ticketFooter;
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ Completa campos obligatorios'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
      return;
    }
    setState(() { _isSaving = true; });
    try {
      final success = await SettingsService.updateMultiple({
        'shop_name': _shopNameController.text.trim(),
        'shop_rif': _shopRifController.text.trim(),
        'shop_address': _shopAddressController.text.trim(),
        'shop_phone': _shopPhoneController.text.trim(),
        'shop_email': _shopEmailController.text.trim(),
        'shop_logo_url': _shopLogoUrlController.text.trim(),
        'ticket_logo_url': _ticketLogoUrlController.text.trim(),
        'currency_symbol': _currencySymbolController.text.trim(),
        'currency_code': _currencyCodeController.text.trim(),
        'ticket_header': _ticketHeaderController.text.trim(),
        'ticket_footer': _ticketFooterController.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success ? '✅ Guardado correctamente' : '⚠️ Algunos valores no se guardaron'), backgroundColor: success ? Colors.green : Colors.orange, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
    } finally {
      if (mounted) setState(() { _isSaving = false; });
    }
  }

  @override
  void dispose() {
    _shopNameController.dispose(); _shopRifController.dispose(); _shopAddressController.dispose(); _shopPhoneController.dispose(); _shopEmailController.dispose(); _shopLogoUrlController.dispose(); _ticketLogoUrlController.dispose(); _currencySymbolController.dispose(); _currencyCodeController.dispose(); _ticketHeaderController.dispose(); _ticketFooterController.dispose();
    super.dispose();
  }

  Widget _premiumField(TextEditingController c, String label, String icon, {int maxLines = 1, String? hint}) {
    return TextFormField(
      controller: c,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: '$icon  ',
        labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
        hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
        filled: true,
        fillColor: const Color(0xFF0F172A),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.white10)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.white10)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2)),
      ),
      validator: (v) => label.contains('*') && (v == null || v.trim().isEmpty) ? 'Requerido' : null,
    );
  }

  Widget _section({required String title, required String icon, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.05)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: Text(icon, style: const TextStyle(fontSize: 16))), const SizedBox(width: 10), Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))]),
        const SizedBox(height: 16),
        child,
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: const Text('Configuración Premium', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF1E293B), Color(0xFF312E81)]), borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))]),
                      child: Row(children: [
                        Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(14)), child: const Text('🏪', style: TextStyle(fontSize: 28))),
                        const SizedBox(width: 16),
                        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('BBS CLUB BARBERÍA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5)), SizedBox(height: 4), Text('Configura tu negocio como un pro', style: TextStyle(color: Colors.white60, fontSize: 12))])),
                      ]),
                    ),
                    const SizedBox(height: 20),
                    _section(title: 'Información del Negocio', icon: '🏪', child: Column(children: [
                      _premiumField(_shopNameController, 'Nombre *', '🏷️'),
                      const SizedBox(height: 12),
                      _premiumField(_shopRifController, 'RUT / RIF', '🆔'),
                      const SizedBox(height: 12),
                      _premiumField(_shopAddressController, 'Dirección', '📍', maxLines: 2),
                      const SizedBox(height: 12),
                      Row(children: [Expanded(child: _premiumField(_shopPhoneController, 'Teléfono', '📱')), const SizedBox(width: 12), Expanded(child: _premiumField(_shopEmailController, 'Email', '📧'))]),
                    ])),
                    const SizedBox(height: 16),
                    _section(title: 'Moneda & Logos', icon: '💰', child: Column(children: [
                      Row(children: [Expanded(child: _premiumField(_currencySymbolController, 'Símbolo *', '💲')), const SizedBox(width: 12), Expanded(child: _premiumField(_currencyCodeController, 'Código', '🏦'))]),
                      const SizedBox(height: 12),
                      _premiumField(_shopLogoUrlController, 'Logo URL (App)', '🖼️', hint: 'https://...'),
                      const SizedBox(height: 12),
                      _premiumField(_ticketLogoUrlController, 'Logo URL (Ticket)', '🧾', hint: 'https://...'),
                    ])),
                    const SizedBox(height: 16),
                    _section(title: 'Ticket', icon: '🧾', child: Column(children: [
                      _premiumField(_ticketHeaderController, 'Encabezado', '📝', hint: 'BARBER_SHOP POS'),
                      const SizedBox(height: 12),
                      _premiumField(_ticketFooterController, 'Pie', '🙏', hint: '¡Gracias por su visita!', maxLines: 2),
                    ])),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: Container(
                        decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF818CF8)]), borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 6))]),
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveSettings,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                          child: _isSaving ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)), SizedBox(width: 12), Text('Guardando...', style: TextStyle(fontWeight: FontWeight.bold))]) : const Text('GUARDAR CONFIGURACIÓN', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.05))),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Vista previa del ticket:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(height: 12),
                        if (_ticketLogoUrlController.text.isNotEmpty) Center(child: Container(height: 50, margin: const EdgeInsets.only(bottom: 8), child: Image.network(_ticketLogoUrlController.text, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox.shrink()))),
                        Center(child: Text(_ticketHeaderController.text.isNotEmpty ? _ticketHeaderController.text : 'BBS CLUB POS', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        if (_shopRifController.text.isNotEmpty) Center(child: Text('RUT: ${_shopRifController.text}', style: const TextStyle(color: Colors.white54, fontSize: 11))),
                        if (_shopAddressController.text.isNotEmpty) Center(child: Text(_shopAddressController.text, style: const TextStyle(color: Colors.white54, fontSize: 11))),
                        if (_shopPhoneController.text.isNotEmpty) Center(child: Text('Tel: ${_shopPhoneController.text}', style: const TextStyle(color: Colors.white54, fontSize: 11))),
                        const Divider(color: Colors.white10, height: 24),
                        Center(child: Text(_ticketFooterController.text.isNotEmpty ? _ticketFooterController.text : '¡Gracias por su visita!', style: const TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic))),
                      ]),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }
}
