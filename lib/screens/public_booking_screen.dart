// lib/screens/public_booking_screen.dart - PREMIUM BLACK & GOLD
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../services/settings_service.dart';

class PublicBookingScreen extends StatefulWidget {
  @override
  State<PublicBookingScreen> createState() => _PublicBookingScreenState();
}

class _PublicBookingScreenState extends State<PublicBookingScreen> {
  // --- PALETA PREMIUM ---
  static const _bgColor = Color(0xFF0A0A0A);
  static const _cardColor = Color(0xFF141414);
  static const _inputColor = Color(0xFF1E1E1E);
  static const _goldColor = Color(0xFFD4AF37);
  static const _goldLight = Color(0xFFFBBF24);

  bool _isLoading = true;
  bool _isSubmitting = false;
  List<Map<String, dynamic>> _services = [];
  List<Map<String, dynamic>> _barbers = [];
  List<Map<String, dynamic>> _existingAppointments = [];
  Set<String> _blockedTimes = {}; 

  Set<String> _selectedServiceIds = {};
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  String? _selectedTime;
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController(text: '+56 ');
  final _emailController = TextEditingController();
  final _notesController = TextEditingController();

  static const String _bankName = 'Mercado Pago';
  static const String _bankAccountType = 'Cuenta Vista';
  static const String _bankAccountNumber = '1012592635';
  static const String _bankRut = '14.212.434-3';
  static const String _bankHolder = 'Patricio Sánchez';

  // Link de Google Maps de BBS Club - lo dio Patricio
  static const String _mapsUrl = 'https://maps.app.goo.gl/9GB1F9anB6sbrNtD7';
  String _depositMethod = 'Transferencia'; 
  bool _depositAlreadyTransferred = false;
  double get _depositAmount => (_totalPrice * 0.5).roundToDouble();

  final List<String> _availableTimes = [
    '11:00', '11:30', '12:00', '12:30',
    '13:00', '13:30', '14:00', '14:30',
    '15:00', '15:30', '16:00', '16:30',
    '17:00', '17:30', '18:00', '18:30',
  ];

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_enforcePrefix);
    _loadData();
  }

  void _enforcePrefix() {
    final text = _phoneController.text;
    if (text.isEmpty) {
      _phoneController.text = '+56 ';
      _phoneController.selection = TextSelection.fromPosition(const TextPosition(offset: 4));
      return;
    }
    if (!text.startsWith('+56')) {
      String cleaned = text.replaceAll(RegExp(r'^\+*56*\s*'), '').trim();
      if (text.startsWith('+')) cleaned = text.replaceAll('+', '').replaceAll('56', '').trim();
      final newText = '+56 ${cleaned.replaceAll('+56', '').trim()}'.trimRight();
      _phoneController.value = TextEditingValue(
        text: newText + (newText == '+56' ? ' ' : ''),
        selection: TextSelection.collapsed(offset: newText.length + (newText == '+56' ? 1 : 0)),
      );
    }
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; });
    try {
      // FIX SERVICIOS VACIOS: Antes .eq('is_active', true) dejaba fuera servicios con is_active = null
      // y si RLS de anon bloqueaba, quedaba lista vacia sin aviso. Ahora traemos todos y filtramos en Dart.
      // Tambien excluimos Propina: la propina no se reserva, solo se cobra en POS.
      final servicesRaw = await Supabase.instance.client.from('services').select('*').order('name');
      final barbers = await Supabase.instance.client.from('barbers').select('*').eq('is_active', true).order('name');
      final servicesFiltered = (servicesRaw as List).where((s) {
        final m = Map<String, dynamic>.from(s as Map);
        final active = m['is_active'];
        final name = (m['name'] ?? '').toString().toLowerCase().trim();
        final id = (m['id'] ?? '').toString().toLowerCase().trim();
        if (name == 'propina' || id == 'propina') return false;
        return active != false; // true o null = visible
      }).toList();
      setState(() {
        _services = List<Map<String, dynamic>>.from(servicesFiltered);
        _barbers = List<Map<String, dynamic>>.from(barbers);
        _isLoading = false;
      });
      await _loadAppointmentsForDate(_selectedDate);
    } catch (e) {
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _loadAppointmentsForDate(DateTime date) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      final appointments = await Supabase.instance.client.from('appointments').select('*').gte('appointment_date', startOfDay.toIso8601String()).lt('appointment_date', endOfDay.toIso8601String()).neq('status', 'cancelled');
      Set<String> blocked = {};
      try {
        final fechaStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        final blk = await Supabase.instance.client.from('blocked_slots').select('hora').eq('fecha', fechaStr);
        for (final r in (blk as List)) {
          blocked.add((r['hora'] ?? '').toString());
        }
      } catch (_) {}
      setState(() {
        _existingAppointments = List<Map<String, dynamic>>.from(appointments);
        _blockedTimes = blocked;
        if (_selectedTime != null && (_blockedTimes.contains(_selectedTime) || _occupiedTimes.contains(_selectedTime))) {
          _selectedTime = null;
        }
      });
    } catch (e) {
      print('Error citas: $e');
    }
  }

  List<String> get _occupiedTimes {
    return _existingAppointments.map((apt) {
      final date = DateTime.parse(apt['appointment_date']);
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }).toSet().toList();
  }

  double get _totalPrice {
    double total = 0;
    for (var id in _selectedServiceIds) {
      final service = _services.firstWhere((s) => s['id'] == id, orElse: () => {});
      if (service.isNotEmpty) total += (service['price'] as num?)?.toDouble() ?? 0.0;
    }
    return total;
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ $msg'), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating));
  }

  Future<void> _openMaps() async {
    final uri = Uri.parse(_mapsUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  String _digits(String p) => p.replaceAll(RegExp(r'[^0-9]'), '');
  String _normPhone(String p) {
    var d = _digits(p);
    if (d.startsWith('56') && d.length == 11) d = d.substring(2);
    if (d.length == 9) return '+56 $d';
    if (d.length == 11 && d.startsWith('56')) return '+56 ${d.substring(2)}';
    return p.trim();
  }

  Future<String?> _ensureClientExists(String name, String phone, String email) async {
    final normalizedPhone = _normPhone(phone);
    final digits = _digits(phone);
    final nameLower = name.trim().toLowerCase();
    try {
      final all = await Supabase.instance.client.from('clients').select('id, name, phone, email').limit(10000);
      final list = List<Map<String, dynamic>>.from(all);
      Map<String, dynamic>? found;
      for (final c in list) {
        final cDigits = _digits((c['phone'] ?? '').toString());
        final cName = (c['name'] ?? '').toString().trim().toLowerCase();
        if (digits.isNotEmpty && cDigits.isNotEmpty && cDigits == digits) { found = c; break; }
        if (cDigits.isNotEmpty && digits.isNotEmpty && cDigits.endsWith(digits.substring(digits.length - 9)) && digits.length >= 9) { found = c; break; }
      }
      found ??= list.where((c) => (c['name'] ?? '').toString().trim().toLowerCase() == nameLower).isNotEmpty ? list.firstWhere((c) => (c['name'] ?? '').toString().trim().toLowerCase() == nameLower) : null;
      if (found != null) {
        final clientId = found['id'].toString();
        try { await Supabase.instance.client.from('clients').update({'name': name.trim(), 'phone': normalizedPhone, if (email.isNotEmpty) 'email': email.trim()}).eq('id', clientId); } catch (_) {}
        return clientId;
      }
      final newId = 'client-${DateTime.now().millisecondsSinceEpoch}';
      try {
        await Supabase.instance.client.from('clients').insert({'id': newId, 'name': name.trim(), 'phone': normalizedPhone, 'email': email.isNotEmpty ? email.trim() : null, 'notes': 'Creado desde reserva web el ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}', 'total_visits': 0, 'total_spent': 0, 'is_active': true, 'created_at': DateTime.now().toIso8601String(), 'updated_at': DateTime.now().toIso8601String()});
      } catch (_) {
        await Supabase.instance.client.from('clients').insert({'id': newId, 'name': name.trim(), 'phone': normalizedPhone, 'email': email.isNotEmpty ? email.trim() : null, 'notes': 'Creado desde reserva web el ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}'});
      }
      return newId;
    } catch (e) {
      return null;
    }
  }

  Future<void> _submitBooking() async {
    if (_selectedServiceIds.isEmpty) { _showError('Selecciona al menos un servicio'); return; }
    if (_selectedTime == null) { _showError('Selecciona un horario'); return; }
    if (_nameController.text.trim().isEmpty) { _showError('Ingresa tu nombre'); return; }
    final phoneRaw = _phoneController.text.trim();
    if (phoneRaw == '+56' || _digits(phoneRaw).length < 9) { _showError('Ingresa tu telefono completo'); return; }
    final phoneClean = _normPhone(phoneRaw);

    await _loadAppointmentsForDate(_selectedDate);
    if (_blockedTimes.contains(_selectedTime)) { _showError('Esa hora acaba de ser bloqueada por el salon'); return; }
    if (_occupiedTimes.contains(_selectedTime)) { _showError('Esa hora acaba de ser ocupada'); return; }

    setState(() { _isSubmitting = true; });
    try {
      var clientId = await _ensureClientExists(_nameController.text.trim(), phoneClean, _emailController.text.trim());
      clientId ??= await _ensureClientExists(_nameController.text.trim(), phoneClean, _emailController.text.trim());

      final barber = _barbers.isNotEmpty ? _barbers.first : null;
      final parts = _selectedTime!.split(':');
      final appointmentDateTime = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, int.parse(parts[0]), int.parse(parts[1]));
      final appointmentId = 'apt-${DateTime.now().millisecondsSinceEpoch}';
      final selectedServices = _services.where((s) => _selectedServiceIds.contains(s['id'])).toList();
      final serviceNames = selectedServices.map((s) => s['name'] as String).join(', ');

      await Supabase.instance.client.from('appointments').insert({
        'id': appointmentId,
        'client_id': clientId,
        'client_name': _nameController.text.trim(),
        'client_phone': phoneClean,
        'client_email': _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        'barber_id': barber != null ? barber['id'] : null,
        'barber_name': barber != null ? barber['name'] : 'Sin asignar',
        'service_id': selectedServices.first['id'],
        'service_name': serviceNames,
        'service_price': _totalPrice,
        'appointment_date': appointmentDateTime.toIso8601String(),
        'status': 'pending',
        'notes': (() {
          final base = _notesController.text.trim();
          if (_depositMethod != 'Transferencia') return base.isEmpty ? null : base;
          final tag = '[Abono: ${_depositAmount.toStringAsFixed(0)} | Transferencia | Pendiente]';
          return base.isEmpty ? tag : '$base $tag';
        })(),
        'source': 'web_booking',
      });

      await _sendConfirmationWhatsApp(appointmentDateTime, serviceNames);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ Reserva enviada. ${_nameController.text.trim()} quedo guardado.'), backgroundColor: const Color(0xFF10B981)));
        setState(() { _selectedServiceIds.clear(); _selectedTime = null; _nameController.clear(); _phoneController.text = '+56 '; _emailController.clear(); _notesController.clear(); });
        await _loadAppointmentsForDate(_selectedDate);
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      if (mounted) setState(() { _isSubmitting = false; });
    }
  }

  Future<void> _sendConfirmationWhatsApp(DateTime dateTime, String services) async {
    try {
      final phone = SettingsService.reservasWhatsApp.replaceAll(RegExp(r'[^0-9+]'), '');
      if (phone.isEmpty) return;
      final dateStr = DateFormat('dd/MM/yyyy').format(dateTime);
      final timeStr = DateFormat('HH:mm').format(dateTime);
      final barberName = _barbers.isNotEmpty ? (_barbers.first['name'] as String? ?? 'Sin asignar') : 'Sin asignar';
      final abonoTxt = _depositMethod == 'Transferencia'
          ? '\n\n\u{1F4B0} Abono: ${SettingsService.formatCurrency(_depositAmount)} por Transferencia - ${_depositAlreadyTransferred ? 'Cliente dice que ya transfirio, verificar comprobante' : 'Pendiente - cliente avisara por WhatsApp'}'
          : '\n\n\u{1F4B0} Abono: Pagara en el local';
      final rawMsg = 'Hola! Nueva reserva en BBS Club Barberia.\n\n\u{1F464} Cliente: ${_nameController.text.trim()}\n\u{1F4F1} Telefono: ${_phoneController.text.trim()}\n\u{1F4C5} Fecha: $dateStr\n\u{23F0} Hora: $timeStr\n\u{2702} Servicio: $services\n\u{1F488} Barbero: $barberName\n\u{1F4B0} Total: ${SettingsService.formatCurrency(_totalPrice)}$abonoTxt';
      final url = Uri.parse("https://wa.me/$phone?text=${Uri.encodeComponent(rawMsg)}");
      if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  InputDecoration _dec(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: _goldColor.withOpacity(0.7), size: 20),
      labelStyle: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
      floatingLabelStyle: const TextStyle(color: _goldColor, fontSize: 13, fontWeight: FontWeight.bold),
      hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
      filled: true,
      fillColor: _inputColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withOpacity(0.05))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _goldColor, width: 1.5)),
    );
  }

  Widget _fieldLabel(String label, bool required) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6), 
      child: Text(required ? "$label *" : label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600))
    ); 
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final occupiedCount = _occupiedTimes.length;
    final blockedCount = _blockedTimes.length;
    final availableCount = _availableTimes.length - occupiedCount - blockedCount;
    
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor, 
        title: const Text('RESERVAR CITA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 1.5)), 
        centerTitle: true, 
        foregroundColor: _goldColor, 
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: _goldColor.withOpacity(0.2), height: 1),
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: _goldColor)) 
        : SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? 16 : 24), 
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 700), 
                decoration: BoxDecoration(
                  color: _cardColor, 
                  borderRadius: BorderRadius.circular(20), 
                  border: Border.all(color: _goldColor.withOpacity(0.15)), 
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 30, offset: const Offset(0,10))]
                ), 
                padding: const EdgeInsets.all(20), 
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, 
                  children: [
                    // --- ENCABEZADO LOGO ---
                    Center(
                      child: Column(children: [
                        if (SettingsService.shopLogoUrl.isNotEmpty) 
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12), 
                            child: Image.network(SettingsService.shopLogoUrl, height: 70, errorBuilder: (_,__,___) => const SizedBox.shrink())
                          ),
                        const SizedBox(height: 12),
                        Text(SettingsService.shopName.toUpperCase(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.2), textAlign: TextAlign.center),
                        const SizedBox(height: 4),
                        Text('Barbería Premium', style: TextStyle(fontSize: 12, color: _goldColor.withOpacity(0.8), fontWeight: FontWeight.w500)),
                        // --- DIRECCION + UBICACION PREMIUM - FIX MOVIL ---
                        // FIX: Antes era un Row con [icono + texto Expanded + boton Como llegar].
                        // En celular de ~360px el boton (130px) + icono dejaban solo ~80px para el texto,
                        // por eso ENCUENTRANOS EN se partia en ENCUE / NTRAN / OS EN y la direccion en silabas.
                        // Ahora es Columna: arriba icono + texto con todo el ancho, abajo boton a todo el ancho.
                        // Asi se ve bien en celular y en PC.
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _goldColor.withOpacity(0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(color: _goldColor.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                                    child: const Icon(Icons.location_on_rounded, color: _goldColor, size: 18),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('ENCUENTRANOS EN', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white38, letterSpacing: 1.2)),
                                        const SizedBox(height: 4),
                                        Text(
                                          SettingsService.shopAddress.isNotEmpty ? SettingsService.shopAddress : 'Ver ubicacion en Google Maps',
                                          style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: InkWell(
                                  onTap: _openMaps,
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                                    decoration: BoxDecoration(color: _goldColor, borderRadius: BorderRadius.circular(10)),
                                    child: const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('Como llegar', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black)),
                                        SizedBox(width: 6),
                                        Icon(Icons.navigation_rounded, size: 16, color: Colors.black),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ])
                    ),
                    const SizedBox(height: 24),
                    // --- SERVICIOS ---
                    _buildSectionTitle('1. Selecciona los servicios'),
                    const SizedBox(height: 10),
                    if (_services.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: Colors.red.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.withOpacity(0.3))),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('No hay servicios disponibles en este momento.', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(height: 4),
                            const Text('Revisa en Supabase: services con is_active = true y que anon pueda leer services. Toca Reintentar.', style: TextStyle(color: Colors.white60, fontSize: 12)),
                            const SizedBox(height: 10),
                            InkWell(
                              onTap: _loadData,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(color: _goldColor, borderRadius: BorderRadius.circular(10)),
                                child: const Text('Reintentar', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ..._services.map((s) => _buildServiceCardMulti(s)),
                    if (_selectedServiceIds.isNotEmpty) 
                      Container(
                        margin: const EdgeInsets.only(top: 10), 
                        padding: const EdgeInsets.all(14), 
                        decoration: BoxDecoration(color: _goldColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: _goldColor.withOpacity(0.3))), 
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                          children: [
                            const Text('Total seleccionado:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white70)), 
                            Text(SettingsService.formatCurrency(_totalPrice), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: _goldColor))
                          ]
                        )
                      ),

                    const SizedBox(height: 24),
                    
                    // --- FECHA ---
                    _buildSectionTitle('2. Selecciona la fecha'),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context, 
                          initialDate: _selectedDate, 
                          firstDate: DateTime.now(), 
                          lastDate: DateTime.now().add(const Duration(days: 30)), 
                          locale: const Locale('es'), 
                          builder: (context, child) { 
                            return Theme(
                              data: ThemeData.dark().copyWith(
                                colorScheme: const ColorScheme.dark(primary: _goldColor, surface: _cardColor), 
                                dialogBackgroundColor: _bgColor
                              ), 
                              child: child!
                            ); 
                          }
                        );
                        if (picked != null) { setState(() { _selectedDate = picked; _selectedTime = null; }); await _loadAppointmentsForDate(picked); }
                      }, 
                      child: Container(
                        padding: const EdgeInsets.all(16), 
                        decoration: BoxDecoration(
                          color: _inputColor, 
                          borderRadius: BorderRadius.circular(14), 
                          border: Border.all(color: _goldColor.withOpacity(0.3))
                        ), 
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_month_rounded, color: _goldColor, size: 22), 
                            const SizedBox(width: 12), 
                            Expanded(child: Text(DateFormat('EEEE, dd MMMM yyyy', 'es').format(_selectedDate), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white))), 
                            Icon(Icons.keyboard_arrow_down_rounded, color: _goldColor.withOpacity(0.5), size: 20)
                          ]
                        )
                      )
                    ),

                    const SizedBox(height: 24),
                    
                    // --- HORARIOS ---
                    _buildSectionTitle('3. Selecciona el horario'),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(14), 
                      decoration: BoxDecoration(color: _inputColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withOpacity(0.05))), 
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start, 
                        children: [
                          Row(
                            children: [
                              _legendDot(_goldColor, 'Libre'),
                              const SizedBox(width: 12),
                              _legendDot(Colors.redAccent.withOpacity(0.8), 'Ocupado'),
                              const SizedBox(width: 12),
                              _legendDot(Colors.orangeAccent, 'Bloqueado'),
                            ]
                          ),
                          const SizedBox(height: 10),
                          Text('Disponibles: $availableCount', style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600)),
                        ]
                      )
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8, 
                      runSpacing: 8, 
                      children: _availableTimes.map((time) {
                        final isOccupied = _occupiedTimes.contains(time);
                        final isBlocked = _blockedTimes.contains(time);
                        final isSelected = _selectedTime == time;
                        final isDisabled = isOccupied || isBlocked;
                        
                        return InkWell(
                          onTap: isDisabled 
                            ? () { if (isBlocked) _showError('Esa hora esta bloqueada por el salon'); else _showError('Esa hora ya esta ocupada'); } 
                            : () => setState(() => _selectedTime = time), 
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), 
                            decoration: BoxDecoration(
                              color: isBlocked 
                                ? Colors.orange.withOpacity(0.1) 
                                : isOccupied 
                                  ? Colors.red.withOpacity(0.05) 
                                  : isSelected 
                                    ? _goldColor 
                                    : _cardColor, 
                              borderRadius: BorderRadius.circular(10), 
                              border: Border.all(
                                color: isBlocked 
                                  ? Colors.orange.withOpacity(0.4) 
                                  : isOccupied 
                                    ? Colors.red.withOpacity(0.3) 
                                    : isSelected 
                                      ? _goldColor 
                                      : Colors.white.withOpacity(0.1), 
                                width: isSelected || isBlocked ? 1.5 : 1
                              )
                            ), 
                            child: Text(
                              isBlocked ? '🔒 $time' : time, 
                              style: TextStyle(
                                color: isBlocked 
                                  ? Colors.orange 
                                  : isOccupied 
                                    ? Colors.redAccent.withOpacity(0.5) 
                                    : isSelected 
                                      ? Colors.black 
                                      : Colors.white70, 
                                fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold, 
                                fontSize: 13, 
                                decoration: isOccupied ? TextDecoration.lineThrough : null
                              )
                            )
                          )
                        );
                      }).toList()
                    ),

                    const SizedBox(height: 24),
                    
                    // --- DATOS ---
                    _buildSectionTitle('4. Tus datos'),
                    const SizedBox(height: 12),
                    _fieldLabel('Nombre Completo', true),
                    TextField(controller: _nameController, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500), decoration: _dec('Ej: Juan Pérez', Icons.person_outline)),
                    const SizedBox(height: 14),
                    _fieldLabel('Teléfono', true),
                    TextField(controller: _phoneController, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold), decoration: _dec('Ej: +56 9 1234 5678', Icons.phone_outlined), keyboardType: TextInputType.phone),
                    const SizedBox(height: 14),
                    _fieldLabel('Email (opcional)', false),
                    TextField(controller: _emailController, style: const TextStyle(color: Colors.white, fontSize: 14), decoration: _dec('tu@email.com', Icons.email_outlined), keyboardType: TextInputType.emailAddress),
                    const SizedBox(height: 14),
                    _fieldLabel('Notas (opcional)', false),
                    TextField(controller: _notesController, style: const TextStyle(color: Colors.white, fontSize: 14), decoration: _dec('Alguna preferencia?', Icons.notes_rounded), maxLines: 2),

                    const SizedBox(height: 24),
                    
                    // --- ABONO ---
                    _buildSectionTitle('5. Abono / Anticipo'),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16), 
                      decoration: BoxDecoration(color: _goldColor.withOpacity(0.05), borderRadius: BorderRadius.circular(14), border: Border.all(color: _goldColor.withOpacity(0.2))), 
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start, 
                        children: [
                          Row(children: [const Icon(Icons.payments_rounded, size: 20, color: _goldColor), const SizedBox(width: 10), const Expanded(child: Text('Abona el 50% para confirmar tu cita', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)))]),
                          const SizedBox(height: 10),
                          if (_selectedServiceIds.isNotEmpty) Text('Total: ${SettingsService.formatCurrency(_totalPrice)}  •  Abono: ${SettingsService.formatCurrency(_depositAmount)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          if (_selectedServiceIds.isEmpty) const Text('Selecciona un servicio para ver el abono.', style: TextStyle(color: Colors.white54, fontSize: 11)),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                            value: _depositMethod, 
                            dropdownColor: _cardColor, 
                            style: const TextStyle(color: Colors.white, fontSize: 13), 
                            decoration: InputDecoration(
                              labelText: 'Como vas a pagar?', 
                              labelStyle: const TextStyle(color: Colors.white54), 
                              filled: true, 
                              fillColor: _inputColor, 
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withOpacity(0.05))),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _goldColor)),
                            ), 
                            items: const [
                              DropdownMenuItem(value: 'Transferencia', child: Text('Transferencia (recomendado)', style: TextStyle(fontSize: 13))), 
                              DropdownMenuItem(value: 'En local', child: Text('Pagare en el local', style: TextStyle(fontSize: 13)))
                            ], 
                            onChanged: (v)=> setState(()=> _depositMethod = v ?? 'Transferencia')
                          ),
                          if (_depositMethod == 'Transferencia') Column(
                            crossAxisAlignment: CrossAxisAlignment.start, 
                            children: [
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12), 
                                decoration: BoxDecoration(color: _bgColor, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white10)), 
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start, 
                                  children: [
                                    const Text('Datos para transferir:', style: TextStyle(color: _goldColor, fontSize: 11, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 6),
                                    Text('Banco: $_bankName', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                    Text('Tipo: $_bankAccountType', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                    Text('N° Cuenta: $_bankAccountNumber', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                    Text('RUT: $_bankRut', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                    Text('Titular: $_bankHolder', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                  ]
                                )
                              ),
                              const SizedBox(height: 8),
                              Material(
                                type: MaterialType.transparency,
                                child: CheckboxListTile(
                                  dense: true, 
                                  value: _depositAlreadyTransferred, 
                                  activeColor: _goldColor, 
                                  title: const Text('Ya transferi, enviare comprobante', style: TextStyle(color: Colors.white, fontSize: 12)), 
                                  subtitle: const Text('Tu cita quedara Pendiente hasta verificar la transferencia.', style: TextStyle(color: Colors.white54, fontSize: 10)), 
                                  onChanged: (v)=> setState(()=> _depositAlreadyTransferred = v ?? false)
                                ),
                              ),
                            ]
                          ),
                        ]
                      )
                    ),
                    
                    const SizedBox(height: 30),
                    
                    // --- BOTON CONFIRMAR ---
                    SizedBox(
                      width: double.infinity, 
                      height: 56, 
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [_goldColor, _goldLight]), 
                          borderRadius: BorderRadius.circular(16), 
                          boxShadow: [BoxShadow(color: _goldColor.withOpacity(0.3), blurRadius: 20, offset: const Offset(0,8))]
                        ), 
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitBooking, 
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent, 
                            shadowColor: Colors.transparent, 
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                          ), 
                          child: _isSubmitting 
                            ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2)), SizedBox(width: 12), Text('Enviando...', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black))]) 
                            : const Text('CONFIRMAR RESERVA', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.black, letterSpacing: 1))
                        )
                      )
                    ),

                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12), 
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(12)), 
                      child: const Row(
                        children: [
                          Icon(Icons.stars_rounded, color: _goldColor, size: 20), 
                          SizedBox(width: 10), 
                          Expanded(child: Text('Al reservar, te agregamos a nuestra lista VIP para futuras promociones.', style: TextStyle(fontSize: 11, color: Colors.white54)))
                        ]
                      )
                    ),
                  ]
                )
              )
            )
          ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 4), Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10))]);
  }

  Widget _buildSectionTitle(String title) {
    return Text(title.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _goldColor, letterSpacing: 1.2));
  }

  Widget _buildServiceCardMulti(Map<String, dynamic> service) {
    final isSelected = _selectedServiceIds.contains(service['id']);
    final price = (service['price'] as num?)?.toDouble() ?? 0.0;
    final duration = service['duration'];
    
    return InkWell(
      onTap: () { setState(() { if (isSelected) _selectedServiceIds.remove(service['id']); else _selectedServiceIds.add(service['id']); }); }, 
      child: Container(
        margin: const EdgeInsets.only(bottom: 8), 
        padding: const EdgeInsets.all(14), 
        decoration: BoxDecoration(
          color: isSelected ? _goldColor.withOpacity(0.1) : _inputColor, 
          border: Border.all(color: isSelected ? _goldColor : Colors.white.withOpacity(0.05), width: isSelected ? 1.5 : 1), 
          borderRadius: BorderRadius.circular(14)
        ), 
        child: Row(
          children: [
            Container(
              width: 24, 
              height: 24, 
              decoration: BoxDecoration(
                color: isSelected ? _goldColor : Colors.transparent, 
                borderRadius: BorderRadius.circular(6), 
                border: Border.all(color: isSelected ? _goldColor : Colors.white24)
              ), 
              child: isSelected ? const Icon(Icons.check_rounded, color: Colors.black, size: 16) : null
            ),
            const SizedBox(width: 14),
            Icon(Icons.content_cut_rounded, color: isSelected ? _goldColor : Colors.white38, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, 
                children: [
                  Text(service['name'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isSelected ? Colors.white : Colors.white70)), 
                  if (duration != null) Text('$duration min', style: const TextStyle(color: Colors.white38, fontSize: 11))
                ]
              )
            ),
            Text(SettingsService.formatCurrency(price), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isSelected ? _goldColor : Colors.white38)),
          ]
        )
      )
    );
  }

  @override
  void dispose() {
    _phoneController.removeListener(_enforcePrefix);
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}