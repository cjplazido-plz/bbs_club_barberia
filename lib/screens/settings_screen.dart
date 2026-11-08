// lib/screens/settings_screen.dart - PREMIUM ORDENADO - Colores POS + Contenido ordenado
// Orden: 01 Datos negocio -> 02 Moneda -> 03 Logos (App COLOR / Ticket B/N + previews) -> 04 Ticket (Encabezado/Pie) -> 05 Folios e Impresion
// Fix: Ticket logo = LOGOTICKET.bmp (no jpeg App), Encabezado = BBS CLUB F.C separado de Nombre = BBS CLUB BARBERIA, bucket sin espacios.
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/settings_service.dart';
import '../services/ticket_config_service.dart';

class SettingsScreen extends StatefulWidget {
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;
  final _shopNameCtrl = TextEditingController();
  final _rifCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _reservasWhatsAppCtrl = TextEditingController(); // solo cjplazido
  final _emailCtrl = TextEditingController();
  final _shopLogoCtrl = TextEditingController();
  final _ticketLogoCtrl = TextEditingController();
  final _currencySymbolCtrl = TextEditingController();
  final _currencyCodeCtrl = TextEditingController();
  final _ticketHeaderCtrl = TextEditingController();
  final _ticketFooterCtrl = TextEditingController();
  final _prefijoCtrl = TextEditingController();
  final _folioCtrl = TextEditingController();
  String _ancho = '80mm';
  bool _autoPrint = true;

  // Colores premium POS
  static const _bg = Color(0xFF0F172A);
  static const _card = Color(0xFF1E293B);
  static const _input = Color(0xFF0F172A);
  static const _indigo = Color(0xFF6366F1);
  static const _violet = Color(0xFF818CF8);
  static const _emerald = Color(0xFF10B981);
  static const _amber = Color(0xFFF59E0B);

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      await SettingsService.loadSettings();
      await TicketConfigService.load();
      final cfg = TicketConfigService.config;
      _shopNameCtrl.text = SettingsService.shopName.isNotEmpty ? SettingsService.shopName : TicketConfigService.nombreNegocio;
      _rifCtrl.text = SettingsService.shopRif.isNotEmpty ? SettingsService.shopRif : TicketConfigService.rut;
      _addressCtrl.text = SettingsService.shopAddress.isNotEmpty ? SettingsService.shopAddress : TicketConfigService.direccion;
      _phoneCtrl.text = SettingsService.shopPhone.isNotEmpty ? SettingsService.shopPhone : TicketConfigService.telefono;
      if (SettingsService.canSeeReservasWhatsApp) _reservasWhatsAppCtrl.text = SettingsService.reservasWhatsApp;
      _emailCtrl.text = SettingsService.shopEmail;
      // App = COLOR jpeg (WhatsApp Image...), Ticket = B/N bmp (LOGOTICKET.bmp) - NO mezclar
      _shopLogoCtrl.text = SettingsService.shopLogoUrl.isNotEmpty ? SettingsService.shopLogoUrl : TicketConfigService.appLogoUrl;
      _ticketLogoCtrl.text = SettingsService.ticketLogoUrl.isNotEmpty ? SettingsService.ticketLogoUrl : TicketConfigService.ticketLogoUrl;
      _currencySymbolCtrl.text = SettingsService.currencySymbol.isNotEmpty ? SettingsService.currencySymbol : r'$';
      _currencyCodeCtrl.text = SettingsService.currencyCode.isNotEmpty ? SettingsService.currencyCode : 'CLP';
      _ticketHeaderCtrl.text = (cfg['encabezado'] ?? cfg['encabezado_ticket'] ?? SettingsService.ticketHeader).toString().isNotEmpty ? (cfg['encabezado'] ?? cfg['encabezado_ticket'] ?? SettingsService.ticketHeader).toString() : 'BBS CLUB F.C';
      _ticketFooterCtrl.text = SettingsService.ticketFooter.isNotEmpty ? SettingsService.ticketFooter : TicketConfigService.mensaje;
      _prefijoCtrl.text = TicketConfigService.prefijo;
      _folioCtrl.text = TicketConfigService.folioActual.toString();
      _ancho = TicketConfigService.ancho;
      _autoPrint = TicketConfigService.autoPrint;
    } catch (e) { debugPrint('Load settings $e'); }
    setState(() => _isLoading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final ok1 = await SettingsService.updateMultiple({
        'shop_name': _shopNameCtrl.text.trim(),
        'shop_rif': _rifCtrl.text.trim(),
        'shop_address': _addressCtrl.text.trim(),
        'shop_phone': _phoneCtrl.text.trim(),
        'shop_email': _emailCtrl.text.trim(),
        'shop_logo_url': _shopLogoCtrl.text.trim(),
        'ticket_logo_url': _ticketLogoCtrl.text.trim(),
        'currency_symbol': _currencySymbolCtrl.text.trim(),
        'currency_code': _currencyCodeCtrl.text.trim(),
        'ticket_header': _ticketHeaderCtrl.text.trim(),
        'ticket_footer': _ticketFooterCtrl.text.trim(),
        if (SettingsService.canSeeReservasWhatsApp) 'reservas_whatsapp': _reservasWhatsAppCtrl.text.trim(),
      });
      // FIX: logo_url = App COLOR, logo_url_ticket = Ticket B/N, encabezado separado de nombre
      final ok2 = await TicketConfigService.save({
        'nombre_negocio': _shopNameCtrl.text.trim(),
        'nombre_local': _shopNameCtrl.text.trim(),
        'encabezado': _ticketHeaderCtrl.text.trim(),
        'encabezado_ticket': _ticketHeaderCtrl.text.trim(),
        'sii_rut_emisor': _rifCtrl.text.trim(),
        'rut': _rifCtrl.text.trim(),
        'direccion': _addressCtrl.text.trim(),
        'sii_direccion': _addressCtrl.text.trim(),
        'telefono': _phoneCtrl.text.trim(),
        'logo_url': _shopLogoCtrl.text.trim(),
        'logo_url_app': _shopLogoCtrl.text.trim(),
        'logo_url_ticket': _ticketLogoCtrl.text.trim(),
        'mensaje': _ticketFooterCtrl.text.trim(),
        'folio_prefijo': _prefijoCtrl.text.trim(),
        'folio_actual': int.tryParse(_folioCtrl.text) ?? 1011,
        'ancho': _ancho,
        'auto_print': _autoPrint,
        'sii_razon': '${_shopNameCtrl.text.trim()} SPA',
        'sii_giro': 'Barberia',
      });
      if (mounted) {
        if (ok1 && ok2) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Configuracion guardada - BBS CLUB'), backgroundColor: Color(0xFF10B981)));
        } else if (ok2) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ticket guardado (algunos campos de app no)'), backgroundColor: Color(0xFF10B981)));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al guardar en Supabase - revisa tabla settings'), backgroundColor: Colors.orange));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally { if (mounted) setState(() => _isSaving = false); }
  }

  Future<void> _pickLogo(bool isTicket) async {
    final ctrl = await showDialog<String>(context: context, builder: (ctx) {
      final tmp = TextEditingController(text: isTicket ? _ticketLogoCtrl.text : _shopLogoCtrl.text);
      return AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isTicket ? 'Logo Ticket URL (B/N)' : 'Logo App URL (COLOR)', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: tmp, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: isTicket ? 'https://.../LOGOTICKET.bmp o bbs-bw.png' : 'https://.../bbs-color.png', labelStyle: const TextStyle(color: Colors.white54), filled: true, fillColor: _bg, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
          const SizedBox(height: 8),
          const Text('Pega la URL de Supabase sin espacios en el bucket (bbs-logos).', style: TextStyle(color: Colors.white54, fontSize: 11)),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))), ElevatedButton(onPressed: () => Navigator.pop(ctx, tmp.text), style: ElevatedButton.styleFrom(backgroundColor: _indigo), child: const Text('Usar'))],
      );
    });
    if (ctrl != null) setState(() { if (isTicket) _ticketLogoCtrl.text = ctrl.trim(); else _shopLogoCtrl.text = ctrl.trim(); });
  }

  @override
  void dispose() {
    _shopNameCtrl.dispose(); _rifCtrl.dispose(); _addressCtrl.dispose(); _phoneCtrl.dispose(); _reservasWhatsAppCtrl.dispose(); _emailCtrl.dispose(); _shopLogoCtrl.dispose(); _ticketLogoCtrl.dispose(); _currencySymbolCtrl.dispose(); _currencyCodeCtrl.dispose(); _ticketHeaderCtrl.dispose(); _ticketFooterCtrl.dispose(); _prefijoCtrl.dispose(); _folioCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(backgroundColor: _bg, body: Center(child: CircularProgressIndicator(color: _indigo)));
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: const Text('Configuracion Premium', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
        centerTitle: true,
        backgroundColor: _card,
        elevation: 0,
        actions: [_buildSaveButton()],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Resumen superior
            _summaryCard(),
            const SizedBox(height: 14),
            // 01 Datos
            _section(number: '01', icon: Icons.store_rounded, color: _indigo, title: 'Datos del negocio', subtitle: 'Nombre, RUT, telefono, email y direccion que salen en el ticket'),
            _field('Nombre del negocio *', _shopNameCtrl, icon: Icons.store_rounded, required: true, hint: 'BBS CLUB BARBERIA'),
            _row2(_field('RUT *', _rifCtrl, icon: Icons.badge_rounded, required: true, hint: '77.000000-0'), _field('Telefono', _phoneCtrl, icon: Icons.phone_rounded, hint: '+56 9 6106 9670')),
            _field('Email', _emailCtrl, icon: Icons.email_rounded, hint: 'contacto@bbsclub.cl'),
            _field('Direccion', _addressCtrl, icon: Icons.location_on_rounded, hint: 'Manuel Montt #460, local 6 - Coronel'),
            // WHATSAPP RESERVAS PRIVADO - solo cjplazido lo ve. patriciosan NO lo ve ni lo edita.
            ... (SettingsService.canSeeReservasWhatsApp ? [
              const SizedBox(height: 10),
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [Icon(Icons.lock, size: 14, color: Color(0xFF10B981)), SizedBox(width: 6), Text('WhatsApp Reservas - SOLO TU cjplazido', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))]),
                const SizedBox(height: 4),
                const Text('Este numero recibe las confirmaciones de reservas de la web. NO es el de Configuracion. Patricio NO lo ve ni lo puede editar.', style: TextStyle(color: Colors.white54, fontSize: 10)),
                const SizedBox(height: 8),
                _field('WhatsApp Reservas', _reservasWhatsAppCtrl, icon: Icons.phone_rounded, hint: '+56972433525'),
              ])),
            ] : []),
            const SizedBox(height: 14),
            // 02 Moneda
            _section(number: '02', icon: Icons.attach_money_rounded, color: _emerald, title: 'Moneda', subtitle: 'Simbolo y codigo que se muestran en precios y ticket'),
            _row2(_field('Simbolo Moneda *', _currencySymbolCtrl, icon: Icons.attach_money_rounded, required: true, hint: '\$'), _field('Codigo (CLP, USD)', _currencyCodeCtrl, icon: Icons.monetization_on_rounded, required: true, hint: 'CLP')),
            const SizedBox(height: 14),
            // 03 Logos
            _section(number: '03', icon: Icons.image_rounded, color: _amber, title: 'Logos - pega URL https', subtitle: 'App a COLOR, Ticket en B/N para 80mm. Sin espacios en el bucket.'),
            _logoField(label: 'Logo URL (App) - COLOR', ctrl: _shopLogoCtrl, isTicket: false, hint: 'https://.../bbs-color.png'),
            _logoField(label: 'Logo URL (Ticket) - SALE EN TICKET 80mm B/N', ctrl: _ticketLogoCtrl, isTicket: true, hint: 'https://.../bbs-bw.png o LOGOTICKET.bmp'),
            const SizedBox(height: 10),
            _logoPreviews(),
            _bucketWarning(),
            const SizedBox(height: 14),
            // 04 Ticket
            _section(number: '04', icon: Icons.receipt_long_rounded, color: _violet, title: 'Personalizacion Ticket', subtitle: 'Encabezado y pie que salen arriba y abajo del ticket'),
            _field('Encabezado del Ticket', _ticketHeaderCtrl, icon: Icons.title_rounded, hint: 'BBS CLUB F.C'),
            _field('Pie de Ticket', _ticketFooterCtrl, icon: Icons.subtitles_rounded, maxLines: 2, hint: 'Gracias por su visita!'),
            const SizedBox(height: 10),
            _previewTicket(),
            const SizedBox(height: 14),
            // 05 Folios e impresion
            _section(number: '05', icon: Icons.print_rounded, color: const Color(0xFF38BDF8), title: 'Folios e impresion', subtitle: 'Ancho del papel, prefijo, proximo folio y auto-imprimir'),
            _row2(
              DropdownButtonFormField<String>(value: _ancho, dropdownColor: _card, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600), decoration: InputDecoration(labelText: 'Ancho papel', labelStyle: const TextStyle(color: Colors.white54), filled: true, fillColor: _input, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)), items: const [DropdownMenuItem(value: '58mm', child: Text('58mm - Seguro')), DropdownMenuItem(value: '80mm', child: Text('80mm - Ancho completo'))], onChanged: (v) => setState(() => _ancho = v!)),
              _switchTile('Auto-imprimir', _autoPrint, (v) => setState(() => _autoPrint = v)),
            ),
            const SizedBox(height: 10),
            _row2(_field('Prefijo folio', _prefijoCtrl, icon: Icons.tag_rounded, hint: 'V-'), _field('Proximo folio', _folioCtrl, icon: Icons.confirmation_number_rounded, isNumber: true, hint: '1011')),
            const SizedBox(height: 6),
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: _indigo.withOpacity(0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: _indigo.withOpacity(0.3))), child: Row(children: [const Icon(Icons.info_rounded, color: _violet, size: 18), const SizedBox(width: 8), Expanded(child: Text('Proximo: ${_prefijoCtrl.text}${_folioCtrl.text}  -  ${_ancho}  -  Impresora 80mm rollo 72.1mm imprimible. En Chrome deja margen 0 y escala 90.', style: const TextStyle(color: Colors.white70, fontSize: 11)))])),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, height: 56, child: Container(decoration: BoxDecoration(gradient: const LinearGradient(colors: [_indigo, _violet]), borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: _indigo.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 6))]), child: ElevatedButton.icon(onPressed: _isSaving ? null : _save, icon: _isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_rounded, color: Colors.white), label: Text(_isSaving ? 'Guardando...' : 'GUARDAR CONFIGURACION', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)), style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))))),
            const SizedBox(height: 30),
          ]),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return Padding(
      padding: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_indigo, _violet]),
          borderRadius: BorderRadius.circular(10),
        ),
        child: TextButton.icon(
          onPressed: _isSaving ? null : _save,
          icon: const Icon(Icons.save_rounded, color: Colors.white, size: 16),
          label: Text(
            _isSaving ? 'Guardando...' : 'Guardar',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
      ),
    );
  }

  Widget _summaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [_indigo, Color(0xFF4F46E5)]), borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: _indigo.withOpacity(0.35), blurRadius: 18, offset: const Offset(0, 8))]),
      child: Row(children: [
        ClipRRect(borderRadius: BorderRadius.circular(8), child: Container(width: 84, height: 38, color: Colors.black, child: _shopLogoCtrl.text.isNotEmpty ? Image.network(_shopLogoCtrl.text, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.store_rounded, color: _indigo)) : const Icon(Icons.store_rounded, color: _indigo))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_shopNameCtrl.text.isNotEmpty ? _shopNameCtrl.text : 'BBS CLUB', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 2),
          Text(_addressCtrl.text.isNotEmpty ? _addressCtrl.text : 'Manuel Montt #460, local 6 - Coronel', style: const TextStyle(color: Colors.white70, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)), child: Text('Proximo folio: ${_prefijoCtrl.text}${_folioCtrl.text}  -  ${_ancho}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
        ])),
      ]),
    );
  }

  Widget _section({required String number, required IconData icon, required Color color, required String title, required String subtitle}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.08))),
      child: Row(children: [
        Container(width: 36, height: 36, decoration: BoxDecoration(color: color.withOpacity(0.18), borderRadius: BorderRadius.circular(10)), child: Center(child: Text(number, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)))),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(icon, color: color, size: 16), const SizedBox(width: 6), Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))]), const SizedBox(height: 2), Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 11))])),
      ]),
    );
  }

  Widget _field(String label, TextEditingController ctrl, {IconData icon = Icons.edit_rounded, bool required = false, bool isNumber = false, int maxLines = 1, String hint = ''}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: ctrl,
        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
        maxLines: maxLines,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        validator: required ? (v) => v == null || v.trim().isEmpty ? 'Obligatorio' : null : null,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint.isNotEmpty ? hint : null,
          hintStyle: const TextStyle(color: Colors.white24, fontSize: 11),
          labelStyle: const TextStyle(color: Colors.white54, fontSize: 11),
          prefixIcon: Icon(icon, color: Colors.white38, size: 18),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _indigo, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          filled: true,
          fillColor: _input,
        ),
      ),
    );
  }

  Widget _row2(Widget a, Widget b) { return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: a), const SizedBox(width: 10), Expanded(child: b)]); }

  Widget _logoField({required String label, required TextEditingController ctrl, required bool isTicket, required String hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Expanded(child: _field(label, ctrl, icon: Icons.link_rounded, hint: hint)),
        const SizedBox(width: 8),
        Container(decoration: BoxDecoration(color: const Color(0xFF334155), borderRadius: BorderRadius.circular(12)), child: TextButton(onPressed: () => _pickLogo(isTicket), child: const Text('URL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)))),
      ]),
    );
  }

  Widget _logoPreviews() {
    // Solo 2 logos: COLOR y B/N. Sin textos, sin 3er preview (el preview grande ya esta en 04 Personalizacion Ticket).
    return Row(children: [
      Expanded(child: _previewBox(url: _shopLogoCtrl.text, isApp: true)),
      const SizedBox(width: 10),
      Expanded(child: _previewBox(url: _ticketLogoCtrl.text, isApp: false)),
    ]);
  }

  Widget _previewBox({required String url, required bool isApp}) {
    // Solo el logo, sin textos (sin APP / COLOR / TICKET 80mm / B/N / EJEMPLO).
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        color: isApp ? Colors.black : Colors.white,
        width: double.infinity,
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: url.isNotEmpty
            ? Image.network(url, fit: BoxFit.contain, width: double.infinity, errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported_rounded, color: Colors.grey))
            : const Icon(Icons.image_rounded, color: Colors.grey),
      ),
    );
  }

  Widget _bucketWarning() {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(12), border: Border.all(color: _amber.withOpacity(0.5))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.warning_amber_rounded, color: Color(0xFF92400E), size: 18),
        const SizedBox(width: 8),
        const Expanded(child: Text('Si tu bucket es "LOGO BBSCLUB" (con espacio), Supabase lo bloquea en Windows. Crea un bucket nuevo sin espacios: bbs-logos (publico), sube los 2 png renombrados: bbs-color.png y bbs-bw.png. Copia sus URLs nuevas y pegalas aqui. Asi cargara 100%.', style: TextStyle(color: Color(0xFF92400E), fontSize: 11, fontWeight: FontWeight.w500))),
      ]),
    );
  }

  Widget _previewTicket() {
    // FIX MUESTRA: antes estirado a todo el ancho -> se veia deformado (image_19bea1). Ahora centrado, ancho fijo 300 = ticket 80mm, solo para la muestra.
    return Center(
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.black12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 12, offset: const Offset(0, 4))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
        if (_ticketLogoCtrl.text.isNotEmpty) Image.network(_ticketLogoCtrl.text, height: 40, width: 180, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
        const SizedBox(height: 6),
        Text(_ticketHeaderCtrl.text.isNotEmpty ? _ticketHeaderCtrl.text : 'BBS CLUB', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black), textAlign: TextAlign.center),
        if (_addressCtrl.text.isNotEmpty) Text(_addressCtrl.text, style: const TextStyle(fontSize: 9, color: Colors.black54), textAlign: TextAlign.center),
        if (_phoneCtrl.text.isNotEmpty) Text('Tel: ${_phoneCtrl.text}', style: const TextStyle(fontSize: 9, color: Colors.black54)),
        const Divider(),
        const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Corte + Barba', style: TextStyle(fontSize: 10, color: Colors.black)), Text('\$20.000', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black))]),
        const Divider(),
        const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('TOTAL:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black)), Text('\$20.000', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black))]),
        const SizedBox(height: 6),
        Text(_ticketFooterCtrl.text.isNotEmpty ? _ticketFooterCtrl.text : 'Gracias por su visita!', style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.black)),
        ]),
      ),
    );
  }

  Widget _switchTile(String label, bool value, ValueChanged<bool> onChanged) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: _input, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.1))),
      child: Row(children: [
        const Icon(Icons.print_rounded, color: Colors.white38, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600))),
        Switch(value: value, onChanged: onChanged, activeColor: _indigo),
      ]),
    );
  }
}