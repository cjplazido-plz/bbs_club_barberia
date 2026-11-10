// lib/screens/public_booking_screen.dart - LINDO (copia Vercel) + Horas 11:00-18:30 + Bloqueo
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
  bool _isLoading = true;
  bool _isSubmitting = false;
  List<Map<String, dynamic>> _services = [];
  List<Map<String, dynamic>> _barbers = [];
  List<Map<String, dynamic>> _existingAppointments = [];
  Set<String> _blockedTimes = {}; // Horas bloqueadas por el salon en blocked_slots

  Set<String> _selectedServiceIds = {};
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  String? _selectedTime;
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController(text: '+56 ');
  final _emailController = TextEditingController();
  final _notesController = TextEditingController();

  // EDITAR AQUI TUS DATOS DE TRANSFERENCIA - salen en la reserva publica
  static const String _bankName = 'Mercado Pago';
  static const String _bankAccountType = 'Cuenta Vista';
  static const String _bankAccountNumber = '1012592635';
  static const String _bankRut = '14.212.434-3';
  static const String _bankHolder = 'Patricio Sánchez';
  //static const String _bankEmail = 'bbsclub@gmail.com';

  String _depositMethod = 'Transferencia'; // Transferencia | En local
  bool _depositAlreadyTransferred = false;
  double get _depositAmount => (_totalPrice * 0.5).roundToDouble();

  // ✅ HORARIO CORRECTO - 11:00 a 18:30 cada 30 min = 16 slots, con 13:00 y 13:30, sin 19:00
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
      final services = await Supabase.instance.client.from('services').select('*').eq('is_active', true).order('name');
      final barbers = await Supabase.instance.client.from('barbers').select('*').eq('is_active', true).order('name');
      setState(() {
        _services = List<Map<String, dynamic>>.from(services);
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
      // ✅ Bloqueadas por el salon para ese dia
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ $msg'), backgroundColor: Colors.red));
  }

  // Crear o actualizar cliente desde Reservar Cita - ROBUSTO
  // Por que fallaba antes: buscaba eq('phone', '+56 9 1234...') exacto, con un espacio distinto no lo encontraba y duplicaba.
  // Y el insert con total_visits / total_spent / is_active fallaba si la tabla clients no tiene esas columnas -> client_id quedaba null y en Agenda salia "Sin telefono / Agregar como cliente".
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
      // Buscar en Dart por digitos (sin espacios) o por nombre - no por eq exacto
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
        print('Cliente existente actualizado: $name - $normalizedPhone -> $clientId');
        return clientId;
      }
      // Crear nuevo - intento completo, si falla por columnas que no existen, intento minimo (solo id/name/phone/email/notes)
      final newId = 'client-${DateTime.now().millisecondsSinceEpoch}';
      try {
        await Supabase.instance.client.from('clients').insert({'id': newId, 'name': name.trim(), 'phone': normalizedPhone, 'email': email.isNotEmpty ? email.trim() : null, 'notes': 'Creado desde reserva web el ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}', 'total_visits': 0, 'total_spent': 0, 'is_active': true, 'created_at': DateTime.now().toIso8601String(), 'updated_at': DateTime.now().toIso8601String()});
      } catch (_) {
        await Supabase.instance.client.from('clients').insert({'id': newId, 'name': name.trim(), 'phone': normalizedPhone, 'email': email.isNotEmpty ? email.trim() : null, 'notes': 'Creado desde reserva web el ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}'});
      }
      print('Nuevo cliente creado: $name - $normalizedPhone - $newId');
      return newId;
    } catch (e) {
      print('Error al crear/actualizar cliente (no bloquea reserva): $e');
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

    // ✅ Doble chequeo bloqueo - por si alguien bloqueo justo ahora
    await _loadAppointmentsForDate(_selectedDate);
    if (_blockedTimes.contains(_selectedTime)) { _showError('Esa hora acaba de ser bloqueada por el salon'); return; }
    if (_occupiedTimes.contains(_selectedTime)) { _showError('Esa hora acaba de ser ocupada'); return; }

    setState(() { _isSubmitting = true; });
    try {
      // PASO 1: Crear/actualizar cliente automaticamente - si falla, reintentar con minimo
      var clientId = await _ensureClientExists(_nameController.text.trim(), phoneClean, _emailController.text.trim());
      clientId ??= await _ensureClientExists(_nameController.text.trim(), phoneClean, _emailController.text.trim());

      final barber = _barbers.isNotEmpty ? _barbers.first : null;
      final parts = _selectedTime!.split(':');
      final appointmentDateTime = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, int.parse(parts[0]), int.parse(parts[1]));
      final appointmentId = 'apt-${DateTime.now().millisecondsSinceEpoch}';
      final selectedServices = _services.where((s) => _selectedServiceIds.contains(s['id'])).toList();
      final serviceNames = selectedServices.map((s) => s['name'] as String).join(', ');

      // ✅ PASO 2: Crear cita con client_id vinculado
      await Supabase.instance.client.from('appointments').insert({
        'id': appointmentId,
        'client_id': clientId, // ✅ Ahora sí vinculado a clientes
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ Reserva enviada. ${_nameController.text.trim()} quedo guardado como cliente ($phoneClean)'), backgroundColor: Colors.green));
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
      // PRIVADO: WhatsApp de reservas NO es el de Configuracion. Es reservasWhatsApp (+56972433525, solo cjplazido lo ve/edita).
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

  InputDecoration _dec(String label, String icon) {
    return InputDecoration(
      labelText: label,
      prefixText: '$icon  ',
      labelStyle: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
      floatingLabelStyle: const TextStyle(color: Color(0xFF6366F1), fontSize: 13, fontWeight: FontWeight.bold),
      hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
      filled: true,
      fillColor: const Color(0xFF1E293B),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.white10)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.white10)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2)),
    );
  }

  Widget _fieldLabel(String icon, String label, bool required) {
    return Padding(padding: const EdgeInsets.only(left: 4, bottom: 6), child: Row(children: [Text(icon, style: const TextStyle(fontSize: 13)), const SizedBox(width: 6), Text(required ? "$label *" : label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700))])); 
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final occupiedCount = _occupiedTimes.length;
    final blockedCount = _blockedTimes.length;
    final availableCount = _availableTimes.length - occupiedCount - blockedCount;
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(backgroundColor: const Color(0xFF1E293B), title: const Text('📅 Reservar Cita', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), centerTitle: true, foregroundColor: Colors.white, elevation: 0),
      body: _isLoading ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1))) : SingleChildScrollView(padding: EdgeInsets.all(isMobile ? 16 : 24), child: Center(child: Container(constraints: const BoxConstraints(maxWidth: 700), decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withOpacity(0.05)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0,8))]), padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Column(children: [
          if (SettingsService.shopLogoUrl.isNotEmpty) ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(SettingsService.shopLogoUrl, height: 70, errorBuilder: (_,__,___) => const SizedBox.shrink())),
          const SizedBox(height: 10),
          Text(SettingsService.shopName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center),
        ])),
        const SizedBox(height: 20),
        _buildSectionTitle('1️⃣ Selecciona los servicios'),
        const Text('Puedes seleccionar varios servicios', style: TextStyle(color: Colors.white38, fontSize: 11)),
        const SizedBox(height: 10),
        ..._services.map((s) => _buildServiceCardMulti(s)),
        if (_selectedServiceIds.isNotEmpty) Container(margin: const EdgeInsets.only(top: 10), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3))), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Total seleccionado:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)), Text(SettingsService.formatCurrency(_totalPrice), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF818CF8)))])),

        const SizedBox(height: 20),
        _buildSectionTitle('2️⃣ Selecciona la fecha'),
        const SizedBox(height: 10),
        InkWell(onTap: () async {
          final picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 30)), locale: const Locale('es'), builder: (context, child) { return Theme(data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: Color(0xFF6366F1), surface: Color(0xFF1E293B)), dialogBackgroundColor: const Color(0xFF0F172A)), child: child!); });
          if (picked != null) { setState(() { _selectedDate = picked; _selectedTime = null; }); await _loadAppointmentsForDate(picked); }
        }, child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF1E293B), Color(0xFF312E81)]), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3))), child: Row(children: [const Text('📅', style: TextStyle(fontSize: 20)), const SizedBox(width: 10), Expanded(child: Text(DateFormat('EEEE, dd MMMM yyyy', 'es').format(_selectedDate), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white))), const Icon(Icons.calendar_month_rounded, color: Color(0xFF6366F1), size: 20)]))),

        const SizedBox(height: 20),
        _buildSectionTitle('3️⃣ Selecciona el horario'),
        const SizedBox(height: 8),
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _legendDot(const Color(0xFF6366F1), 'Seleccionado'),
            const SizedBox(width: 12),
            _legendDot(Colors.white, 'Disponible'),
            const SizedBox(width: 12),
            _legendDot(Colors.red.withOpacity(0.4), 'Ocupado'),
            const SizedBox(width: 12),
            _legendDot(Colors.orange, 'Bloqueado'),
          ]),
          const SizedBox(height: 8),
          Text('📊 $availableCount disponibles • $occupiedCount ocupados${blockedCount > 0 ? ' • $blockedCount bloqueados' : ''}', style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600)),
          if (_occupiedTimes.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('⛔ Ocupados: ${_occupiedTimes.join(', ')}', style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w500))),
          if (_blockedTimes.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('🔒 Bloqueadas por el salon: ${(_blockedTimes.toList()..sort()).join(', ')}', style: const TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.w500))),
        ])),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: _availableTimes.map((time) {
          final isOccupied = _occupiedTimes.contains(time);
          final isBlocked = _blockedTimes.contains(time);
          final isSelected = _selectedTime == time;
          final isDisabled = isOccupied || isBlocked;
          return InkWell(onTap: isDisabled ? () { if (isBlocked) _showError('Esa hora esta bloqueada por el salon'); else _showError('Esa hora ya esta ocupada'); } : () => setState(() => _selectedTime = time), child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), decoration: BoxDecoration(color: isBlocked ? Colors.orange.withOpacity(0.18) : isOccupied ? Colors.red.withOpacity(0.12) : isSelected ? const Color(0xFF6366F1) : const Color(0xFF1E293B), borderRadius: BorderRadius.circular(10), border: Border.all(color: isBlocked ? Colors.orange.withOpacity(0.5) : isOccupied ? Colors.red.withOpacity(0.3) : isSelected ? const Color(0xFF6366F1) : Colors.white10, width: isSelected || isBlocked ? 2 : 1)), child: Text(isBlocked ? '🔒 $time' : time, style: TextStyle(color: isBlocked ? Colors.orange : isOccupied ? Colors.redAccent.withOpacity(0.7) : isSelected ? Colors.white : Colors.white70, fontWeight: FontWeight.bold, fontSize: 13, decoration: isOccupied ? TextDecoration.lineThrough : null))));
        }).toList()),

        const SizedBox(height: 20),
        _buildSectionTitle('4️⃣ Tus datos'),
        const SizedBox(height: 12),
        _fieldLabel('👤', 'Nombre Completo', true),
        TextField(controller: _nameController, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500), decoration: _dec('Nombre completo *', '')),
        const SizedBox(height: 14),
        _fieldLabel('📱', 'Telefono con +56', true),
        TextField(controller: _phoneController, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold), decoration: _dec('Ej: +56 9 1234 5678', '').copyWith(hintText: '9 1234 5678'), keyboardType: TextInputType.phone),
        const SizedBox(height: 14),
        _fieldLabel('✉️', 'Email (opcional)', false),
        TextField(controller: _emailController, style: const TextStyle(color: Colors.white, fontSize: 14), decoration: _dec('Email (opcional)', ''), keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 14),
        _fieldLabel('📝', 'Notas (opcional)', false),
        TextField(controller: _notesController, style: const TextStyle(color: Colors.white, fontSize: 14), decoration: _dec('Notas (opcional)', ''), maxLines: 3),

        const SizedBox(height: 20),
        _buildSectionTitle('5️⃣ Abono / Anticipo'),
        const SizedBox(height: 8),
        Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFFF59E0B).withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Icon(Icons.payments, size: 16, color: Color(0xFFF59E0B)), const SizedBox(width: 8), const Expanded(child: Text('Para confirmar tu cita, abona el 50% por transferencia', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)))]),
          const SizedBox(height: 8),
          if (_selectedServiceIds.isNotEmpty) Text('Total: ${SettingsService.formatCurrency(_totalPrice)}  •  Abono sugerido: ${SettingsService.formatCurrency(_depositAmount)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
          if (_selectedServiceIds.isEmpty) const Text('Selecciona un servicio para ver el abono.', style: TextStyle(color: Colors.white54, fontSize: 11)),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(value: _depositMethod, dropdownColor: const Color(0xFF1E293B), style: const TextStyle(color: Colors.white, fontSize: 13), decoration: InputDecoration(labelText: 'Como vas a pagar el abono?', labelStyle: const TextStyle(color: Colors.white54), filled: true, fillColor: const Color(0xFF0F172A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))), items: const [DropdownMenuItem(value: 'Transferencia', child: Text('Transferencia (recomendado)', style: TextStyle(fontSize: 13))), DropdownMenuItem(value: 'En local', child: Text('Pagare en el local', style: TextStyle(fontSize: 13)))], onChanged: (v)=> setState(()=> _depositMethod = v ?? 'Transferencia')),
          if (_depositMethod == 'Transferencia') Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 10),
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white10)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Datos para transferir:', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('Banco: $_bankName', style: const TextStyle(color: Colors.white70, fontSize: 11)),
              Text('Tipo: $_bankAccountType', style: const TextStyle(color: Colors.white70, fontSize: 11)),
              Text('N° Cuenta: $_bankAccountNumber', style: const TextStyle(color: Colors.white70, fontSize: 11)),
              Text('RUT: $_bankRut', style: const TextStyle(color: Colors.white70, fontSize: 11)),
              Text('Titular: $_bankHolder', style: const TextStyle(color: Colors.white70, fontSize: 11)),
              // Email oculto a pedido - si queres mostrarlo, descomenta _bankEmail arriba y esta linea
              const SizedBox(height: 6),
              const Text('Edita estos datos arriba en el archivo (EDITAR AQUI TUS DATOS DE TRANSFERENCIA).', style: TextStyle(color: Colors.white38, fontSize: 9)),
            ])),
            const SizedBox(height: 8),
            CheckboxListTile(dense: true, value: _depositAlreadyTransferred, activeColor: const Color(0xFF10B981), title: const Text('Ya transferi, enviare comprobante por WhatsApp', style: TextStyle(color: Colors.white, fontSize: 12)), subtitle: const Text('Tu cita quedara Pendiente hasta que verifiquemos la transferencia en Agenda.', style: TextStyle(color: Colors.white54, fontSize: 10)), onChanged: (v)=> setState(()=> _depositAlreadyTransferred = v ?? false)),
          ]),
          if (_depositMethod == 'En local') const Padding(padding: EdgeInsets.only(top: 8), child: Text('Pagara el total en el local. Tu cita quedara Pendiente hasta que la confirmemos.', style: TextStyle(color: Colors.white54, fontSize: 11))),
        ])),
        const SizedBox(height: 24),
        SizedBox(width: double.infinity, height: 54, child: Container(decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF818CF8)]), borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.4), blurRadius: 16, offset: const Offset(0,6))]), child: ElevatedButton(onPressed: _isSubmitting ? null : _submitBooking, style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: _isSubmitting ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)), SizedBox(width: 12), Text('Enviando...', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white))]) : const Text('✅ CONFIRMAR RESERVA', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5))))),

        const SizedBox(height: 12),
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF10B981).withOpacity(0.2))), child: const Row(children: [Text('👥', style: TextStyle(fontSize: 18)), SizedBox(width: 8), Expanded(child: Text('Al reservar, te agregamos automaticamente a clientes para futuras promociones', style: TextStyle(fontSize: 11, color: Colors.white70)))])),
      ])))),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(children: [Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white24))), const SizedBox(width: 4), Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10))]);
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white));
  }

  Widget _buildServiceCardMulti(Map<String, dynamic> service) {
    final isSelected = _selectedServiceIds.contains(service['id']);
    final price = (service['price'] as num?)?.toDouble() ?? 0.0;
    final duration = service['duration'];
    return InkWell(onTap: () { setState(() { if (isSelected) _selectedServiceIds.remove(service['id']); else _selectedServiceIds.add(service['id']); }); }, child: Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: isSelected ? const Color(0xFF6366F1).withOpacity(0.15) : const Color(0xFF0F172A), border: Border.all(color: isSelected ? const Color(0xFF6366F1) : Colors.white10, width: isSelected ? 2 : 1), borderRadius: BorderRadius.circular(12)), child: Row(children: [
      Container(width: 26, height: 26, decoration: BoxDecoration(color: isSelected ? const Color(0xFF6366F1) : Colors.transparent, borderRadius: BorderRadius.circular(6), border: Border.all(color: isSelected ? const Color(0xFF6366F1) : Colors.white24)), child: isSelected ? const Icon(Icons.check_rounded, color: Colors.white, size: 16) : null),
      const SizedBox(width: 12),
      const Text('✂️', style: TextStyle(fontSize: 22)),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(service['name'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isSelected ? Colors.white : Colors.white70)), if (duration != null) Text('$duration min', style: const TextStyle(color: Colors.white38, fontSize: 11))])),
      Text(SettingsService.formatCurrency(price), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF818CF8))),
    ])));
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