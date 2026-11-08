// lib/screens/settings_screen.dart - COMPLETA BBS CLUB - FIX 5 puntos
// 1: guarda web OK (Supabase + TicketConfig), 2: logos con upload, 3: completa como antes, 4: formato Hierba Viva 80mm, 5: ticket grande
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      await SettingsService.loadSettings();
      await TicketConfigService.load();
      _shopNameCtrl.text = SettingsService.shopName.isNotEmpty ? SettingsService.shopName : TicketConfigService.nombreNegocio;
      _rifCtrl.text = SettingsService.shopRif.isNotEmpty ? SettingsService.shopRif : TicketConfigService.rut;
      _addressCtrl.text = SettingsService.shopAddress.isNotEmpty ? SettingsService.shopAddress : TicketConfigService.direccion;
      _phoneCtrl.text = SettingsService.shopPhone.isNotEmpty ? SettingsService.shopPhone : TicketConfigService.telefono;
      if (SettingsService.canSeeReservasWhatsApp) _reservasWhatsAppCtrl.text = SettingsService.reservasWhatsApp;
      _emailCtrl.text = SettingsService.shopEmail;
      _shopLogoCtrl.text = SettingsService.shopLogoUrl;
      _ticketLogoCtrl.text = SettingsService.ticketLogoUrl.isNotEmpty ? SettingsService.ticketLogoUrl : TicketConfigService.logoUrl;
      _currencySymbolCtrl.text = SettingsService.currencySymbol.isNotEmpty ? SettingsService.currencySymbol : '\$';
      _currencyCodeCtrl.text = SettingsService.currencyCode.isNotEmpty ? SettingsService.currencyCode : 'CLP';
      _ticketHeaderCtrl.text = SettingsService.ticketHeader.isNotEmpty ? SettingsService.ticketHeader : 'BBS CLUB F.C';
      _ticketFooterCtrl.text = SettingsService.ticketFooter.isNotEmpty ? SettingsService.ticketFooter : TicketConfigService.mensaje;
      _prefijoCtrl.text = TicketConfigService.prefijo;
      _folioCtrl.text = TicketConfigService.folioActual.toString();
      _ancho = TicketConfigService.ancho;
      _autoPrint = TicketConfigService.autoPrint;
    } catch (e) {
      print('Load settings $e');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      // 1. Guardar en SettingsService (tabla settings de barberflow - shop_*)
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

      // 2. Guardar en TicketConfigService (para impresión 80mm estilo Hierba Viva)
      final ok2 = await TicketConfigService.save({
        'nombre_negocio': _shopNameCtrl.text.trim(),
        'sii_rut_emisor': _rifCtrl.text.trim(),
        'rut': _rifCtrl.text.trim(),
        'direccion': _addressCtrl.text.trim(),
        'sii_direccion': _addressCtrl.text.trim(),
        'telefono': _phoneCtrl.text.trim(),
        'logo_url': _ticketLogoCtrl.text.trim().isNotEmpty ? _ticketLogoCtrl.text.trim() : _shopLogoCtrl.text.trim(),
        'mensaje': _ticketFooterCtrl.text.trim(),
        'folio_prefijo': _prefijoCtrl.text.trim(),
        'folio_actual': int.tryParse(_folioCtrl.text) ?? 1009,
        'ancho': _ancho,
        'auto_print': _autoPrint,
        'sii_razon': '${_shopNameCtrl.text.trim()} SPA',
        'sii_giro': 'Barberia',
      });

      if (mounted) {
        if (ok1 && ok2) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Configuración guardada - BBS CLUB'), backgroundColor: Colors.green));
        } else if (ok2) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Ticket guardado (algunos campos de app no)'), backgroundColor: Colors.green));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ Error al guardar en Supabase - revisa tabla settings'), backgroundColor: Colors.orange));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // Simula upload logo - en web pide URL, en desktop futuro file picker
  Future<void> _pickLogo(bool isTicket) async {
    final ctrl = await showDialog<String>(context: context, builder: (ctx){
      final tmp = TextEditingController(text: isTicket ? _ticketLogoCtrl.text : _shopLogoCtrl.text);
      return AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(isTicket ? 'Logo Ticket URL' : 'Logo App URL', style: const TextStyle(color: Colors.white)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: tmp, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'https://...png', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          const Text('Pega URL de imgur, Supabase storage o Drive público. En próxima versión sube archivo directo.', style: TextStyle(color: Colors.white54, fontSize: 11)),
        ]),
        actions: [TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text('Cancelar')), ElevatedButton(onPressed: ()=>Navigator.pop(ctx, tmp.text), child: const Text('Guardar'))],
      );
    });
    if (ctrl != null) {
      setState(() {
        if (isTicket) _ticketLogoCtrl.text = ctrl.trim(); else _shopLogoCtrl.text = ctrl.trim();
      });
    }
  }

  @override
  void dispose() {
    _shopNameCtrl.dispose(); _rifCtrl.dispose(); _addressCtrl.dispose(); _phoneCtrl.dispose(); _reservasWhatsAppCtrl.dispose(); _emailCtrl.dispose(); _shopLogoCtrl.dispose(); _ticketLogoCtrl.dispose(); _currencySymbolCtrl.dispose(); _currencyCodeCtrl.dispose(); _ticketHeaderCtrl.dispose(); _ticketFooterCtrl.dispose(); _prefijoCtrl.dispose(); _folioCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: ()=>Navigator.pop(context)), title: const Text('Configuración Premium BBS CLUB'), backgroundColor: const Color(0xFF1E293B)),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _section('🏪 Datos del negocio', [
          _row2(_field('Nombre *', _shopNameCtrl, required: true), _field('RUT *', _rifCtrl, required: true)),
          _row2(_field('Teléfono', _phoneCtrl), _field('Email', _emailCtrl)),
          // WHATSAPP RESERVAS PRIVADO - solo cjplazido lo ve. patriciosan NO lo ve ni lo edita.
          ... (SettingsService.canSeeReservasWhatsApp ? [
            const SizedBox(height: 12),
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [Icon(Icons.lock, size: 14, color: Color(0xFF10B981)), SizedBox(width: 6), Text('WhatsApp Reservas - SOLO TU cjplazido', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))]),
              const SizedBox(height: 4),
              const Text('Este numero recibe las confirmaciones de reservas de la web. NO es el de Configuracion. Patricio NO lo ve ni lo puede editar.', style: TextStyle(color: Colors.white54, fontSize: 10)),
              const SizedBox(height: 8),
              _field('WhatsApp Reservas', _reservasWhatsAppCtrl),
            ])),
          ] : []),
          _field('Dirección', _addressCtrl),
        ]),
        _section('💲 Moneda', [
          _row2(_field('Símbolo', _currencySymbolCtrl), _field('Código', _currencyCodeCtrl)),
        ]),
        _section('🖼️ Logos (ahora sí guarda - pega URL)', [
          _logoField('Logo URL (App)', _shopLogoCtrl, false),
          _logoField('Logo URL (Ticket) - aparece en ticket 80mm', _ticketLogoCtrl, true),
        ]),
        _section('🎫 Ticket y folios - estilo Hierba Viva ${ _ancho }', [
          _row2(
            DropdownButtonFormField<String>(value: _ancho, dropdownColor: const Color(0xFF1E293B), style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: 'Ancho papel', labelStyle: const TextStyle(color: Colors.white54), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), items: const [DropdownMenuItem(value: '58mm', child: Text('58mm - Seguro')), DropdownMenuItem(value: '80mm', child: Text('80mm - Ancho completo (recomendado 80mm rollo)'))], onChanged: (v)=>setState(()=>_ancho=v!)),
            Row(children: [Checkbox(value: _autoPrint, onChanged: (v)=>setState(()=>_autoPrint=v!)), const Text('Auto-imprimir', style: TextStyle(color: Colors.white70, fontSize: 12))]),
          ),
          const SizedBox(height: 10),
          _row2(_field('Prefijo folio', _prefijoCtrl), _field('Próximo folio', _folioCtrl, isNumber: true)),
          Text('Próximo: ${_prefijoCtrl.text}${_folioCtrl.text} - ${_ancho} - Tu impresora 80mm rollo 72.1mm imprimible - si usas 80mm pon margen 0 en Chrome', style: const TextStyle(color: Colors.white38, fontSize: 10)),
        ]),
        _section('🧾 Personalización Ticket (igual que antes)', [
          _field('Encabezado del Ticket', _ticketHeaderCtrl),
          _field('Pie de Ticket', _ticketFooterCtrl, maxLines: 2),
        ]),
        _preview(),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, height: 56, child: ElevatedButton.icon(onPressed: _isSaving?null:_save, icon: _isSaving? const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)): const Icon(Icons.save), label: Text(_isSaving?'Guardando...':'💾 GUARDAR CONFIGURACIÓN'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
        const SizedBox(height: 30),
      ]))),
    );
  }

  Widget _section(String title, List<Widget> children){
    return Container(margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)), const SizedBox(height: 10), ...children.map((w)=>Padding(padding: const EdgeInsets.only(bottom: 8), child: w))]));
  }

  Widget _field(String label, TextEditingController ctrl, {bool required=false, bool isNumber=false, int maxLines=1}){
    return TextFormField(controller: ctrl, style: const TextStyle(color: Colors.white, fontSize: 13), maxLines: maxLines, keyboardType: isNumber? TextInputType.number: TextInputType.text, validator: required? (v)=> v==null||v.trim().isEmpty? 'Obligatorio':null: null, decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: Colors.white54, fontSize: 11), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10), filled: true, fillColor: const Color(0xFF0F172A)));
  }

  Widget _row2(Widget a, Widget b){ return Row(children: [Expanded(child: a), const SizedBox(width: 8), Expanded(child: b)]); }

  Widget _logoField(String label, TextEditingController ctrl, bool isTicket){
    return Row(children: [
      Expanded(child: _field(label, ctrl)),
      const SizedBox(width: 8),
      ElevatedButton(onPressed: ()=>_pickLogo(isTicket), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF334155), minimumSize: const Size(70, 44)), child: const Text('URL', style: TextStyle(fontSize: 11))),
    ]);
  }

  Widget _preview(){
    return Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)), child: Column(children: [
      if(_ticketLogoCtrl.text.isNotEmpty) Image.network(_ticketLogoCtrl.text, height: 50, errorBuilder: (_,__,___)=> const SizedBox.shrink()),
      const SizedBox(height: 6),
      Text(_ticketHeaderCtrl.text.isNotEmpty? _ticketHeaderCtrl.text: 'BBS CLUB', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), textAlign: TextAlign.center),
      if(_rifCtrl.text.isNotEmpty) Text('RUT: ${_rifCtrl.text}', style: const TextStyle(fontSize: 10)),
      if(_addressCtrl.text.isNotEmpty) Text(_addressCtrl.text, style: const TextStyle(fontSize: 10), textAlign: TextAlign.center),
      const Divider(),
      const Text('Ejemplo items - formato 80mm Hierba Viva', style: TextStyle(fontSize: 10, color: Colors.grey)),
      const SizedBox(height: 6),
      Text(_ticketFooterCtrl.text.isNotEmpty? _ticketFooterCtrl.text: '¡Gracias por su visita!', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
    ]));
  }
}
