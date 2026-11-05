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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ Por favor completa todos los campos obligatorios'), backgroundColor: Colors.red));
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success ? '✅ Configuracion guardada correctamente' : '⚠️ Algunos valores no se pudieron guardar'), backgroundColor: success ? Colors.green : Colors.orange));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() { _isSaving = false; });
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
    _ticketLogoUrlController.dispose();
    _currencySymbolController.dispose();
    _currencyCodeController.dispose();
    _ticketHeaderController.dispose();
    _ticketFooterController.dispose();
    super.dispose();
  }

  InputDecoration _premiumDecoration(String label, String icon) {
    return InputDecoration(
      labelText: label,
      prefixText: '$icon  ',
      labelStyle: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.3),
      floatingLabelStyle: const TextStyle(color: Color(0xFF6366F1), fontSize: 13, fontWeight: FontWeight.bold),
      hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
      filled: true,
      fillColor: const Color(0xFF0F172A),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.white10)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.white10)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2)),
    );
  }

  Widget _buildPremiumField(TextEditingController controller, String label, String icon, {int maxLines = 1, bool isRequired = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 6),
              Text(isRequired ? "$label *" : label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
            ],
          ),
        ),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
          decoration: _premiumDecoration(label, ''),
          validator: isRequired ? (v) => (v == null || v.trim().isEmpty) ? 'Obligatorio' : null : null,
        ),
      ],
    );
  }

  Widget _sectionCard({required String title, required String icon, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withOpacity(0.05)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 14, offset: const Offset(0, 6))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: Text(icon, style: const TextStyle(fontSize: 16))),
          const SizedBox(width: 10),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 16),
        ...children,
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: const Text('Configuracion Premium', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF1E293B), Color(0xFF312E81)]), borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.25), blurRadius: 20, offset: const Offset(0, 8))]),
                    child: Row(children: [
                      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(14)), child: const Text('🏪', style: TextStyle(fontSize: 28))),
                      const SizedBox(width: 14),
                      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('BBS CLUB BARBERIA', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)), SizedBox(height: 4), Text('Configura tu negocio como un pro', style: TextStyle(color: Colors.white54, fontSize: 12))])),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  _sectionCard(
                    title: 'Informacion del Negocio',
                    icon: '🏢',
                    children: [
                      _buildPremiumField(_shopNameController, 'Nombre del Negocio', '🏷️', isRequired: true),
                      const SizedBox(height: 14),
                      _buildPremiumField(_shopRifController, 'RUT / RIF', '🆔'),
                      const SizedBox(height: 14),
                      _buildPremiumField(_shopAddressController, 'Direccion Completa', '📍', maxLines: 2),
                      const SizedBox(height: 14),
                      Row(children: [
                        Expanded(child: _buildPremiumField(_shopPhoneController, 'Telefono', '📞')),
                        const SizedBox(width: 12),
                        Expanded(child: _buildPremiumField(_shopEmailController, 'Email de Contacto', '✉️')),
                      ]),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _sectionCard(
                    title: 'Moneda & Logos',
                    icon: '💰',
                    children: [
                      Row(children: [
                        Expanded(child: _buildPremiumField(_currencySymbolController, 'Simbolo Moneda', '💵', isRequired: true)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildPremiumField(_currencyCodeController, 'Codigo (CLP, USD)', '🏦')),
                      ]),
                      const SizedBox(height: 14),
                      _buildPremiumField(_shopLogoUrlController, 'Logo URL (App)', '🖼️'),
                      const SizedBox(height: 14),
                      _buildPremiumField(_ticketLogoUrlController, 'Logo URL (Ticket)', '🧾'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _sectionCard(
                    title: 'Personalizacion Ticket',
                    icon: '🎨',
                    children: [
                      _buildPremiumField(_ticketHeaderController, 'Encabezado del Ticket', '🔝'),
                      const SizedBox(height: 14),
                      _buildPremiumField(_ticketFooterController, 'Pie de Ticket', '🔻', maxLines: 2),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: Container(
                      decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF818CF8)]), borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 6))]),
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveSettings,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                        child: _isSaving
                            ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)), SizedBox(width: 12), Text('Guardando...', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white))])
                            : const Text('💾 GUARDAR CONFIGURACION', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ]),
              ),
            ),
    );
  }
}
