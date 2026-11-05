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

  Set<String> _selectedServiceIds = {};
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  String? _selectedTime;
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController(text: '+56 ');
  final _emailController = TextEditingController();
  final _notesController = TextEditingController();

  final List<String> _availableTimes = [
    '09:00', '09:30', '10:00', '10:30', '11:00', '11:30',
    '12:00', '12:30', '14:00', '14:30', '15:00', '15:30',
    '16:00', '16:30', '17:00', '17:30', '18:00', '18:30',
    '19:00', '19:30', '20:00',
  ];

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_enforcePrefixFixed);
    _loadData();
  }

  // ✅ FIX 1: Prefijo fijo sin borrar 56 interno
  void _enforcePrefixFixed() {
    final text = _phoneController.text;
    final selection = _phoneController.selection;

    // Si está vacío, reset a +56
    if (text.isEmpty) {
      _phoneController.value = const TextEditingValue(text: '+56 ', selection: TextSelection.collapsed(offset: 4));
      return;
    }

    // Si no empieza con +56, forzarlo
    if (!text.startsWith('+56')) {
      // Solo deja dígitos del resto
      final digitsOnly = text.replaceAll(RegExp(r'[^0-9]'), '');
      // Quita 56 inicial si ya viene
      String cleanDigits = digitsOnly;
      if (cleanDigits.startsWith('56')) cleanDigits = cleanDigits.substring(2);
      final newText = '+56 $cleanDigits';
      final offset = newText.length;
      _phoneController.value = TextEditingValue(text: newText, selection: TextSelection.collapsed(offset: offset));
      return;
    }

    // Ya empieza con +56, asegurar solo dígitos después
    if (text.length > 4) {
      final afterPrefix = text.substring(3); // después de +56
      final digitsOnly = afterPrefix.replaceAll(RegExp(r'[^0-9]'), '');
      // Limitar a 9 dígitos (formato chileno 9 XXXX XXXX)
      final limited = digitsOnly.length > 9 ? digitsOnly.substring(0, 9) : digitsOnly;
      final newText = '+56 $limited';
      if (newText != text) {
        int newOffset = selection.baseOffset;
        if (newOffset > newText.length) newOffset = newText.length;
        if (newOffset < 4) newOffset = newText.length;
        _phoneController.value = TextEditingValue(text: newText, selection: TextSelection.collapsed(offset: newOffset));
      }
    }
  }

  String get _digitsOnly {
    // Retorna solo dígitos sin + ni espacios, ej: 56972435252
    return _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
  }

  String get _formattedPhone {
    // Retorna +56 9 7243 5252 bonito para guardar
    final d = _digitsOnly;
    if (d.isEmpty) return '+56 ';
    if (d.startsWith('56')) {
      final rest = d.substring(2);
      return '+56 $rest';
    }
    return '+56 $d';
  }

  bool get _isPhoneValid {
    final d = _digitsOnly;
    // Chile: 56 + 9 dígitos = 11 dígitos totales. Aceptamos 10 u 11 por si falta uno
    // Ej: 5697243525 (10) o 56972435252 (11) ambos pasan
    if (d.length < 10) return false; // mínimo 56 + 8
    if (d.length > 11) return false;
    if (!d.startsWith('56')) return false;
    return true;
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
      setState(() { _existingAppointments = List<Map<String, dynamic>>.from(appointments); });
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ $msg', style: const TextStyle(fontSize: 13)), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
  }

  Future<String?> _ensureClientExists(String name, String phone, String email) async {
    try {
      final normalizedPhone = phone.trim(); // +56 9...
      final digits = normalizedPhone.replaceAll(RegExp(r'[^0-9]'), '');
      // Buscar por dígitos (con y sin +)
      final existing = await Supabase.instance.client.from('clients').select('id').or('phone.eq.$normalizedPhone,phone.eq.$digits,phone.eq.+$digits').limit(1);
      if (existing.isNotEmpty) {
        final clientId = existing.first['id'] as String;
        await Supabase.instance.client.from('clients').update({'name': name, 'phone': normalizedPhone, 'email': email.isNotEmpty ? email : null, 'updated_at': DateTime.now().toIso8601String()}).eq('id', clientId);
        return clientId;
      } else {
        final newId = 'client-${DateTime.now().millisecondsSinceEpoch}';
        await Supabase.instance.client.from('clients').insert({
          'id': newId,
          'name': name,
          'phone': normalizedPhone,
          'email': email.isNotEmpty ? email : null,
          'notes': 'Creado desde reserva web el ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
          'total_visits': 0,
          'total_spent': 0,
          'is_active': true,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
        return newId;
      }
    } catch (e) {
      print('⚠️ Error cliente: $e');
      return null;
    }
  }

  Future<void> _submitBooking() async {
    if (_selectedServiceIds.isEmpty) { _showError('Selecciona al menos un servicio'); return; }
    if (_selectedTime == null) { _showError('Selecciona un horario'); return; }
    if (_nameController.text.trim().isEmpty) { _showError('Ingresa tu nombre'); return; }
    
    // ✅ FIX VALIDACION REAL
    if (!_isPhoneValid) {
      _showError('Teléfono inválido. Debe ser 9 dígitos: Ej: 9 7243 5252 (total 11 con +56)');
      return;
    }

    setState(() { _isSubmitting = true; });
    try {
      final phoneToSave = _formattedPhone; // +56 97243525
      final clientId = await _ensureClientExists(_nameController.text.trim(), phoneToSave, _emailController.text.trim());

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
        'client_phone': phoneToSave,
        'client_email': _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        'barber_id': barber != null ? barber['id'] : null,
        'barber_name': barber != null ? barber['name'] : 'Sin asignar',
        'service_id': selectedServices.first['id'],
        'service_name': serviceNames,
        'service_price': _totalPrice,
        'appointment_date': appointmentDateTime.toIso8601String(),
        'status': 'pending',
        'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        'source': 'web_booking',
      });

      await _sendConfirmationWhatsApp(appointmentDateTime, serviceNames);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Reserva enviada y cliente guardado'), backgroundColor: Color(0xFF10B981)));
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
      // ✅ FIX 2: wa.me sin + y sin espacios
      String shopPhoneRaw = SettingsService.shopPhone; // puede ser +56...
      if (shopPhoneRaw.isEmpty) {
        // Si no hay shopPhone, usa el de la tienda por defecto o no envía
        print('⚠️ shopPhone vacío, no se envía WhatsApp');
        return;
      }
      String digits = shopPhoneRaw.replaceAll(RegExp(r'[^0-9]'), ''); // solo números
      if (digits.isEmpty) return;
      // Asegura que empiece con 56, si empieza con 9 agregale 56
      if (digits.startsWith('9') && digits.length == 9) digits = '56$digits';
      if (digits.startsWith('0')) digits = digits.substring(1);
      
      final formattedDate = DateFormat('EEEE dd/MM/yyyy HH:mm', 'es').format(dateTime);
      final message = Uri.encodeComponent("Hola! Nueva reserva:\n\n👤 ${_nameController.text}\n📱 ${_formattedPhone}\n✂️ $services\n📅 $formattedDate\n💰 ${SettingsService.formatCurrency(_totalPrice)}");
      final url = Uri.parse("https://wa.me/$digits?text=$message");
      print('📲 Intentando WhatsApp a: $digits - $url');
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        print('❌ No se pudo abrir WhatsApp');
      }
    } catch (e) {
      print('❌ Error WhatsApp: $e');
    }
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
    final availableCount = _availableTimes.length - occupiedCount;
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(backgroundColor: const Color(0xFF1E293B), title: const Text('📅 Reservar Cita', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), centerTitle: true, foregroundColor: Colors.white, elevation: 0),
      body: _isLoading ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1))) : SingleChildScrollView(padding: EdgeInsets.all(isMobile ? 16 : 24), child: Center(child: Container(constraints: const BoxConstraints(maxWidth: 700), decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withOpacity(0.05))), padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Column(children: [
          if (SettingsService.shopLogoUrl.isNotEmpty) ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(SettingsService.shopLogoUrl, height: 70, errorBuilder: (_,__,___) => const SizedBox.shrink())),
          const SizedBox(height: 10),
          Text(SettingsService.shopName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center),
        ])),
        const SizedBox(height: 20),
        _buildSectionTitle('1️⃣ Servicios'),
        const SizedBox(height: 10),
        ..._services.map((s) => _buildServiceCardMulti(s)),
        if (_selectedServiceIds.isNotEmpty) Container(margin: const EdgeInsets.only(top: 10), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Total:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)), Text(SettingsService.formatCurrency(_totalPrice), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF818CF8)))])),

        const SizedBox(height: 20),
        _buildSectionTitle('2️⃣ Fecha'),
        const SizedBox(height: 10),
        InkWell(onTap: () async {
          final picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 30)), locale: const Locale('es'), builder: (context, child) { return Theme(data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: Color(0xFF6366F1), surface: Color(0xFF1E293B)), dialogBackgroundColor: const Color(0xFF0F172A)), child: child!); });
          if (picked != null) { setState(() { _selectedDate = picked; _selectedTime = null; }); await _loadAppointmentsForDate(picked); }
        }, child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF1E293B), Color(0xFF312E81)]), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3))), child: Row(children: [const Text('📅', style: TextStyle(fontSize: 20)), const SizedBox(width: 10), Expanded(child: Text(DateFormat('EEEE, dd MMMM yyyy', 'es').format(_selectedDate), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white))), const Icon(Icons.calendar_month_rounded, color: Color(0xFF6366F1), size: 20)]))),

        const SizedBox(height: 20),
        _buildSectionTitle('3️⃣ Horario'),
        const SizedBox(height: 8),
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [_legendDot(const Color(0xFF6366F1), 'Sel'), const SizedBox(width: 12), _legendDot(Colors.white, 'Libre'), const SizedBox(width: 12), _legendDot(Colors.red.withOpacity(0.4), 'Ocup')]),
          const SizedBox(height: 8),
          Text('📊 $availableCount libres • $occupiedCount ocup', style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600)),
          if (_occupiedTimes.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('⛔ Ocup: ${_occupiedTimes.join(', ')}', style: const TextStyle(color: Colors.redAccent, fontSize: 11))),
        ])),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: _availableTimes.map((time) {
          final isOccupied = _occupiedTimes.contains(time);
          final isSelected = _selectedTime == time;
          return InkWell(onTap: isOccupied ? null : () => setState(() => _selectedTime = time), child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), decoration: BoxDecoration(color: isOccupied ? Colors.red.withOpacity(0.12) : isSelected ? const Color(0xFF6366F1) : const Color(0xFF1E293B), borderRadius: BorderRadius.circular(10), border: Border.all(color: isOccupied ? Colors.red.withOpacity(0.3) : isSelected ? const Color(0xFF6366F1) : Colors.white10)), child: Text(time, style: TextStyle(color: isOccupied ? Colors.redAccent.withOpacity(0.7) : isSelected ? Colors.white : Colors.white70, fontWeight: FontWeight.bold, fontSize: 13, decoration: isOccupied ? TextDecoration.lineThrough : null))));
        }).toList()),

        const SizedBox(height: 20),
        _buildSectionTitle('4️⃣ Tus datos'),
        const SizedBox(height: 12),
        _fieldLabel('👤', 'Nombre', true),
        TextField(controller: _nameController, style: const TextStyle(color: Colors.white, fontSize: 14), decoration: _dec('Nombre completo *', '')),
        const SizedBox(height: 14),
        _fieldLabel('📱', 'Telefono +56', true),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(controller: _phoneController, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold), decoration: InputDecoration(labelText: 'Teléfono con +56 *', prefixIcon: Container(margin: const EdgeInsets.all(8), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: const Text('🇨🇱 +56', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white))), labelStyle: const TextStyle(color: Colors.white70, fontSize: 13), hintText: '9 1234 5678', hintStyle: const TextStyle(color: Colors.white30, fontSize: 12), filled: true, fillColor: const Color(0xFF1E293B), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.white10)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _isPhoneValid || _digitsOnly.length < 4 ? Colors.white10 : Colors.red.withOpacity(0.5))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _isPhoneValid ? const Color(0xFF10B981) : const Color(0xFF6366F1), width: 2)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18)), keyboardType: TextInputType.phone),
          const SizedBox(height: 6),
          Text(_isPhoneValid ? '✅ Válido: ${_formattedPhone} (${_digitsOnly.length} dígitos)' : 'Digits: ${_digitsOnly} (${_digitsOnly.length}/11) - Ej: 9 7243 5252', style: TextStyle(color: _isPhoneValid ? const Color(0xFF10B981) : Colors.white38, fontSize: 10)),
        ]),
        const SizedBox(height: 14),
        _fieldLabel('✉️', 'Email (opcional)', false),
        TextField(controller: _emailController, style: const TextStyle(color: Colors.white, fontSize: 14), decoration: _dec('Email', '')),
        const SizedBox(height: 14),
        _fieldLabel('📝', 'Notas (opcional)', false),
        TextField(controller: _notesController, style: const TextStyle(color: Colors.white, fontSize: 14), decoration: _dec('Notas', ''), maxLines: 3),

        const SizedBox(height: 24),
        SizedBox(width: double.infinity, height: 54, child: Container(decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF818CF8)]), borderRadius: BorderRadius.circular(14)), child: ElevatedButton(onPressed: _isSubmitting ? null : _submitBooking, style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: _isSubmitting ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)), SizedBox(width: 12), Text('Enviando...', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white))]) : const Text('✅ CONFIRMAR RESERVA', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white))))),

      ])))),
    );
  }

  Widget _legendDot(Color color, String label) { return Row(children: [Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white24))), const SizedBox(width: 4), Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10))]); }
  Widget _buildSectionTitle(String title) { return Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)); }
  Widget _buildServiceCardMulti(Map<String, dynamic> service) {
    final isSelected = _selectedServiceIds.contains(service['id']);
    final price = (service['price'] as num?)?.toDouble() ?? 0.0;
    return InkWell(onTap: () { setState(() { if (isSelected) _selectedServiceIds.remove(service['id']); else _selectedServiceIds.add(service['id']); }); }, child: Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: isSelected ? const Color(0xFF6366F1).withOpacity(0.15) : const Color(0xFF0F172A), border: Border.all(color: isSelected ? const Color(0xFF6366F1) : Colors.white10, width: isSelected ? 2 : 1), borderRadius: BorderRadius.circular(12)), child: Row(children: [Container(width: 26, height: 26, decoration: BoxDecoration(color: isSelected ? const Color(0xFF6366F1) : Colors.transparent, borderRadius: BorderRadius.circular(6), border: Border.all(color: isSelected ? const Color(0xFF6366F1) : Colors.white24)), child: isSelected ? const Icon(Icons.check_rounded, color: Colors.white, size: 16) : null), const SizedBox(width: 12), const Text('✂️', style: TextStyle(fontSize: 22)), const SizedBox(width: 10), Expanded(child: Text(service['name'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isSelected ? Colors.white : Colors.white70))), Text(SettingsService.formatCurrency(price), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF818CF8)))])));
  }
  @override
  void dispose() { _phoneController.removeListener(_enforcePrefixFixed); _nameController.dispose(); _phoneController.dispose(); _emailController.dispose(); _notesController.dispose(); super.dispose(); }
}
