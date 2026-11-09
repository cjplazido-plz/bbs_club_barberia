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

  // Horario salon: 11:00 a 19:00 cada 30 min - ultimo inicio 18:30
  final List<String> _availableTimes = ['11:00','11:30','12:00','12:30','13:00','13:30','14:00','14:30','15:00','15:30','16:00','16:30','17:00','17:30','18:00','18:30'];
  Set<String> _blockedTimes = {};
  String _blockedMotivo = 'No disponible';

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
      // Bloqueadas por admin ese dia
      Set<String> blocked = {};
      String motivo = 'No disponible';
      try {
        final fechaStr = DateFormat('yyyy-MM-dd').format(date);
        final bl = await Supabase.instance.client.from('blocked_slots').select('hora, motivo').eq('fecha', fechaStr);
        for (final r in (bl as List)) { blocked.add((r['hora'] ?? '').toString()); if ((r['motivo'] ?? '').toString().isNotEmpty) motivo = (r['motivo'] ?? '').toString(); }
      } catch (_) {}
      setState(() { _existingAppointments = List<Map<String, dynamic>>.from(appointments); _blockedTimes = blocked; _blockedMotivo = motivo; if (_selectedTime != null && _blockedTimes.contains(_selectedTime)) _selectedTime = null; });
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

  // ✅ NUEVO: Crear o actualizar cliente automáticamente
  Future<String?> _ensureClientExists(String name, String phone, String email) async {
    try {
      final normalizedPhone = phone.trim();
      // Buscar cliente existente por teléfono
      final existing = await Supabase.instance.client.from('clients').select('id, phone, total_visits').eq('phone', normalizedPhone).limit(1);
      
      if (existing.isNotEmpty) {
        final clientId = existing.first['id'] as String;
        // Actualizar datos si hay email nuevo y visitas
        await Supabase.instance.client.from('clients').update({
          'name': name,
          'email': email.isNotEmpty ? email : existing.first['email'],
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', clientId);
        print('✅ Cliente existente actualizado: $name - $phone');
        return clientId;
      } else {
        // Crear nuevo cliente
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
        print('✅ Nuevo cliente creado: $name - $phone - $newId');
        return newId;
      }
    } catch (e) {
      print('⚠️ Error al crear/actualizar cliente (no bloquea reserva): $e');
      // No bloquea la reserva si falla el cliente, sigue con null
      return null;
    }
  }

  Future<void> _submitBooking() async {
    if (_selectedServiceIds.isEmpty) { _showError('Selecciona al menos un servicio'); return; }
    if (_selectedTime == null) { _showError('Selecciona un horario'); return; }
    if (_blockedTimes.contains(_selectedTime)) { _showError('Esa hora esta bloqueada por el salon ($_blockedMotivo)'); return; }
    if (_nameController.text.trim().isEmpty) { _showError('Ingresa tu nombre'); return; }
    final phoneClean = _phoneController.text.trim();
    if (phoneClean == '+56' || phoneClean.length < 8) { _showError('Ingresa tu telefono completo'); return; }

    setState(() { _isSubmitting = true; });
    try {
      // ✅ PASO 1: Crear/actualizar cliente automáticamente
      final clientId = await _ensureClientExists(_nameController.text.trim(), phoneClean, _emailController.text.trim());

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
        'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        'source': 'web_booking',
      });

      await _sendConfirmationWhatsApp(appointmentDateTime, serviceNames);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Reserva enviada y cliente guardado'), backgroundColor: Colors.green));
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
      final phone = SettingsService.shopPhone.replaceAll(RegExp(r'[^0-9+]'), '');
      if (phone.isEmpty) return;
      final formattedDate = DateFormat('EEEE dd/MM/yyyy HH:mm', 'es').format(dateTime);
      final message = "Hola! Nueva reserva:%0A%0A👤 ${_nameController.text}%0A📱 ${_phoneController.text}%0A✂️ $services%0A📅 $formattedDate%0A💰 ${SettingsService.formatCurrency(_totalPrice)}";
      final url = Uri.parse("https://wa.me/$phone?text=$message");
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
          Text('📊 $availableCount disponibles • $occupiedCount ocupados • $blockedCount bloqueados', style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600)),
          if (_occupiedTimes.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('⛔ Ocupados: ${_occupiedTimes.join(', ')}', style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w500))),
          if (_blockedTimes.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('🔒 Bloqueadas por el salon ($_blockedMotivo): ${_blockedTimes.join(', ')}', style: const TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.w500))),
        ])),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: _availableTimes.map((time) {
          final isOccupied = _occupiedTimes.contains(time);
          final isBlocked = _blockedTimes.contains(time);
          final isDisabled = isOccupied || isBlocked;
          final isSelected = _selectedTime == time;
          return InkWell(onTap: isDisabled ? null : () => setState(() => _selectedTime = time), child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), decoration: BoxDecoration(color: isBlocked ? Colors.orange.withOpacity(0.15) : isOccupied ? Colors.red.withOpacity(0.12) : isSelected ? const Color(0xFF6366F1) : const Color(0xFF1E293B), borderRadius: BorderRadius.circular(10), border: Border.all(color: isBlocked ? Colors.orange : isOccupied ? Colors.red.withOpacity(0.3) : isSelected ? const Color(0xFF6366F1) : Colors.white10, width: isSelected ? 2 : 1)), child: Text(isBlocked ? '🔒 $time' : time, style: TextStyle(color: isBlocked ? Colors.orange : isOccupied ? Colors.redAccent.withOpacity(0.7) : isSelected ? Colors.white : Colors.white70, fontWeight: FontWeight.bold, fontSize: 13, decoration: isDisabled ? TextDecoration.lineThrough : null))));
        }).toList()),

        const SizedBox(height: 20),
        _buildSectionTitle('4️⃣ Tus datos'),
        const SizedBox(height: 12),
        _fieldLabel('👤', 'Nombre Completo', true),
        TextField(controller: _nameController, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500), decoration: _dec('Nombre completo *', '')),
        const SizedBox(height: 14),
        _fieldLabel('📱', 'Telefono con +56', true),
        TextField(controller: _phoneController, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold), decoration: _dec('Ej: +56 9 1234 5678', '').copyWith(hintText: '+56 9 XXXX XXXX', prefixIcon: Container(margin: const EdgeInsets.all(8), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: const Text('🇨🇱 +56', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)))), keyboardType: TextInputType.phone),
        const SizedBox(height: 14),
        _fieldLabel('✉️', 'Email (opcional)', false),
        TextField(controller: _emailController, style: const TextStyle(color: Colors.white, fontSize: 14), decoration: _dec('Email (opcional)', ''), keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 14),
        _fieldLabel('📝', 'Notas (opcional)', false),
        TextField(controller: _notesController, style: const TextStyle(color: Colors.white, fontSize: 14), decoration: _dec('Notas (opcional)', ''), maxLines: 3),

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
