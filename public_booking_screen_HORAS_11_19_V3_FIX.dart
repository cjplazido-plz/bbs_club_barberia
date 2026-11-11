// lib/screens/public_booking_screen.dart - PUBLICA - Horas CORREGIDAS 11:00 a 18:30 cada 30 min + Bloqueo
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

// ============================================================
// 👇 EDITAR AQUI TUS DATOS DE TRANSFERENCIA - SOLO AQUI SE CAMBIA
// No hay que buscar en todo el archivo, solo estas 6 lineas.
// Cambialas por tus datos REALES y guardas.
// ============================================================
const String _bancoTransfer = 'Banco Estado';
const String _tipoCuentaTransfer = 'Cuenta RUT';
const String _numeroCuentaTransfer = '12.345.678-9';
const String _rutTransfer = '12.345.678-9';
const String _titularTransfer = 'BBS Club Barberia';
const String _emailTransfer = 'bbsclub@gmail.com';
// ============================================================

class PublicBookingScreen extends StatefulWidget {
  @override
  State<PublicBookingScreen> createState() => _PublicBookingScreenState();
}

class _PublicBookingScreenState extends State<PublicBookingScreen> {
  DateTime _selectedDate = DateTime.now();
  String? _selectedServiceId;
  String? _selectedServiceName;
  double _selectedServicePrice = 0;
  String? _selectedBarberId;
  String? _selectedBarberName;
  String? _selectedTime;
  List<Map<String, dynamic>> _services = [];
  List<Map<String, dynamic>> _barbers = [];
  Set<String> _occupied = {};
  Set<String> _blocked = {};
  bool _isLoading = true;
  bool _isSaving = false;

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _abonoTransfer = false;
  bool _yaTransferi = false;

  // ✅ HORARIO CORRECTO - Solo 11:00 a 18:30 cada 30 min = 16 slots
  static const List<String> _allTimes = [
    '11:00', '11:30', '12:00', '12:30',
    '13:00', '13:30', '14:00', '14:30',
    '15:00', '15:30', '16:00', '16:30',
    '17:00', '17:30', '18:00', '18:30',
  ];

  String get _fechaStr => DateFormat('yyyy-MM-dd').format(_selectedDate);
  String get _fechaBonita => DateFormat('EEEE, dd MMMM yyyy', 'es').format(_selectedDate);

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    try {
      final svc = await Supabase.instance.client.from('services').select('id, name, price').order('name');
      final brb = await Supabase.instance.client.from('barbers').select('id, name').order('name');
      if (mounted) {
        setState(() {
          _services = List<Map<String, dynamic>>.from(svc as List);
          _barbers = List<Map<String, dynamic>>.from(brb as List);
        });
      }
    } catch (_) {}
    await _loadDay();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadDay() async {
    try {
      // Bloqueadas por el salon
      final blk = await Supabase.instance.client.from('blocked_slots').select('hora').eq('fecha', _fechaStr);
      final bSet = <String>{};
      for (final r in (blk as List)) {
        bSet.add((r['hora'] ?? '').toString());
      }
      // Ocupadas por citas
      final start = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      final end = start.add(const Duration(days: 1));
      final appts = await Supabase.instance.client
          .from('appointments')
          .select('appointment_date')
          .gte('appointment_date', start.toIso8601String())
          .lt('appointment_date', end.toIso8601String())
          .neq('status', 'cancelled');
      final oSet = <String>{};
      for (final a in (appts as List)) {
        final d = DateTime.parse(a['appointment_date'].toString());
        final hh = d.hour.toString().padLeft(2, '0');
        final mm = d.minute.toString().padLeft(2, '0');
        oSet.add('$hh:$mm');
      }
      if (mounted) {
        setState(() {
          _blocked = bSet;
          _occupied = oSet;
          // Si la hora seleccionada quedo bloqueada/ocupada, deseleccionar
          if (_selectedTime != null && (_blocked.contains(_selectedTime) || _occupied.contains(_selectedTime))) {
            _selectedTime = null;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _pickDate() async {
    final p = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      builder: (c, ch) => Theme(
        data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: Color(0xFF6366F1))),
        child: ch!,
      ),
    );
    if (p != null) {
      setState(() {
        _selectedDate = p;
        _selectedTime = null;
      });
      await _loadDay();
    }
  }

  void _onTapTime(String time) {
    if (_blocked.contains(time)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Esa hora esta bloqueada por el salon'), backgroundColor: Colors.red),
      );
      return;
    }
    if (_occupied.contains(time)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Esa hora ya esta ocupada'), backgroundColor: Colors.orange),
      );
      return;
    }
    setState(() => _selectedTime = time);
  }

  String _normalizePhone(String raw) {
    var digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('0')) digits = digits.substring(1);
    if (!digits.startsWith('56') && digits.length == 9) digits = '56$digits';
    return '+$digits';
  }

  Future<void> _confirmar() async {
    if (_selectedServiceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Elige un servicio')));
      return;
    }
    if (_selectedBarberId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Elige un barbero')));
      return;
    }
    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Elige un horario')));
      return;
    }
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Falta tu nombre')));
      return;
    }
    if (_phoneCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Falta tu telefono')));
      return;
    }
    // Doble chequeo antes de guardar - por si alguien reservo justo ahora
    await _loadDay();
    if (_blocked.contains(_selectedTime)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Esa hora acaba de ser bloqueada por el salon'), backgroundColor: Colors.red));
      return;
    }
    if (_occupied.contains(_selectedTime)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Esa hora acaba de ser ocupada'), backgroundColor: Colors.orange));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final name = _nameCtrl.text.trim();
      final phoneNorm = _normalizePhone(_phoneCtrl.text.trim());
      final parts = _selectedTime!.split(':');
      final dt = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, int.parse(parts[0]), int.parse(parts[1]));

      // Buscar o crear cliente
      String? clientId;
      try {
        final digitsOnly = phoneNorm.replaceAll(RegExp(r'[^0-9]'), '');
        final existing = await Supabase.instance.client.from('clients').select('id').or('phone.ilike.%$digitsOnly%,name.ilike.%$name%').limit(1);
        if ((existing as List).isNotEmpty) {
          clientId = (existing[0]['id'] ?? '').toString();
        }
      } catch (_) {}
      if (clientId == null) {
        try {
          final ins = await Supabase.instance.client.from('clients').insert({'name': name, 'phone': phoneNorm, 'source': 'web_booking'}).select('id').single();
          clientId = (ins['id'] ?? '').toString();
        } catch (_) {}
      }

      final abonoAmt = (_selectedServicePrice / 2).round();
      final abonoTag = _abonoTransfer
          ? '[Abono: $abonoAmt | Transferencia | ${_yaTransferi ? 'Pendiente' : 'Pendiente'}]'
          : '';
      final notes = abonoTag;

      await Supabase.instance.client.from('appointments').insert({
        'client_id': clientId,
        'client_name': name,
        'client_phone': phoneNorm,
        'barber_id': _selectedBarberId,
        'barber_name': _selectedBarberName,
        'service_id': _selectedServiceId,
        'service_name': _selectedServiceName,
        'appointment_date': dt.toIso8601String(),
        'status': 'pending',
        'notes': notes,
        'source': 'web_booking',
      });

      // WhatsApp a reservas privada
      final dateStr = DateFormat('dd/MM/yyyy').format(dt);
      final msg = 'Hola $name, tu cita en BBS Club Barberia ha sido *REGISTRADA*.\n\n\u{1F4C5} Fecha: $dateStr\n\u{23F0} Hora: $_selectedTime\n\u{2702} Servicio: $_selectedServiceName\n\u{1F488} Barbero: $_selectedBarberName\n\nTe confirmamos pronto.';
      final url = 'https://wa.me/56972433525?text=${Uri.encodeComponent(msg)}';
      final uri = Uri.parse(url);
      try {
        if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reserva registrada! Te confirmamos pronto.'), backgroundColor: Color(0xFF10B981)));
        setState(() {
          _selectedTime = null;
          _nameCtrl.clear();
          _phoneCtrl.clear();
        });
        await _loadDay();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    final disponibles = _allTimes.where((t) => !_blocked.contains(t) && !_occupied.contains(t)).length;
    final ocupadas = _occupied.length;
    final bloqueadas = _blocked.length;
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: const Text('Reservar Cita', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Fecha
                      InkWell(
                        onTap: _pickDate,
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: const Color(0xFF6366F1), borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_rounded, color: Colors.white, size: 18),
                              const SizedBox(width: 10),
                              Expanded(child: Text(_fechaBonita, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
                              const Icon(Icons.calendar_month, color: Colors.white70, size: 18),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Servicio
                      const Text('1  Servicio', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedServiceId,
                        dropdownColor: const Color(0xFF1E293B),
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(filled: true, fillColor: const Color(0xFF1E293B), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                        hint: const Text('Elige un servicio', style: TextStyle(color: Colors.white54, fontSize: 13)),
                        items: _services.map((s) {
                          return DropdownMenuItem<String>(value: (s['id'] ?? '').toString(), child: Text('${s['name']} - \$${s['price']}', style: const TextStyle(fontSize: 13)));
                        }).toList(),
                        onChanged: (v) {
                          final s = _services.firstWhere((e) => (e['id'] ?? '').toString() == v, orElse: () => {});
                          setState(() {
                            _selectedServiceId = v;
                            _selectedServiceName = s['name']?.toString();
                            _selectedServicePrice = double.tryParse((s['price'] ?? '0').toString()) ?? 0;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text('2  Barbero', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedBarberId,
                        dropdownColor: const Color(0xFF1E293B),
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(filled: true, fillColor: const Color(0xFF1E293B), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                        hint: const Text('Elige un barbero', style: TextStyle(color: Colors.white54, fontSize: 13)),
                        items: _barbers.map((b) {
                          return DropdownMenuItem<String>(value: (b['id'] ?? '').toString(), child: Text((b['name'] ?? '').toString(), style: const TextStyle(fontSize: 13)));
                        }).toList(),
                        onChanged: (v) {
                          final b = _barbers.firstWhere((e) => (e['id'] ?? '').toString() == v, orElse: () => {});
                          setState(() {
                            _selectedBarberId = v;
                            _selectedBarberName = b['name']?.toString();
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      // Horario - CORREGIDO 11:00-18:30
                      const Text('3  Selecciona el horario', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(width: 10, height: 10, decoration: BoxDecoration(color: const Color(0xFF6366F1), borderRadius: BorderRadius.circular(5))),
                                const SizedBox(width: 5),
                                const Text('Seleccionado', style: TextStyle(color: Colors.white70, fontSize: 11)),
                                const SizedBox(width: 12),
                                Container(width: 10, height: 10, decoration: BoxDecoration(color: Colors.transparent, border: Border.all(color: Colors.white38), borderRadius: BorderRadius.circular(5))),
                                const SizedBox(width: 5),
                                const Text('Disponible', style: TextStyle(color: Colors.white70, fontSize: 11)),
                                const SizedBox(width: 12),
                                Container(width: 10, height: 10, decoration: BoxDecoration(color: Colors.red.withOpacity(0.3), borderRadius: BorderRadius.circular(5))),
                                const SizedBox(width: 5),
                                const Text('Ocupado', style: TextStyle(color: Colors.white70, fontSize: 11)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('$disponibles disponibles - $ocupadas ocupadas${bloqueadas > 0 ? ' - $bloqueadas bloqueadas' : ''}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                            if (bloqueadas > 0) ...[
                              const SizedBox(height: 6),
                              Text('Bloqueadas por el salon (Salon cerrado): ${(_blocked.toList()..sort()).join(', ')}', style: const TextStyle(color: Colors.redAccent, fontSize: 11)),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _allTimes.map((time) {
                          final isBlocked = _blocked.contains(time);
                          final isOccupied = _occupied.contains(time);
                          final isSelected = _selectedTime == time;
                          Color bg;
                          Color border;
                          Color txt;
                          String label = time;
                          if (isSelected) {
                            bg = const Color(0xFF6366F1);
                            border = const Color(0xFF6366F1);
                            txt = Colors.white;
                          } else if (isBlocked) {
                            bg = Colors.red.withOpacity(0.18);
                            border = Colors.redAccent;
                            txt = Colors.redAccent;
                            label = '🔒 $time';
                          } else if (isOccupied) {
                            bg = Colors.white10;
                            border = Colors.white24;
                            txt = Colors.white38;
                          } else {
                            bg = const Color(0xFF1E293B);
                            border = Colors.white10;
                            txt = Colors.white;
                          }
                          return InkWell(
                            onTap: () => _onTapTime(time),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: border, width: isSelected || isBlocked ? 2 : 1)),
                              child: Text(label, style: TextStyle(color: txt, fontWeight: FontWeight.bold, fontSize: 12, decoration: isOccupied ? TextDecoration.lineThrough : null)),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      const Text('4  Tus datos', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 8),
                      const Text('Nombre Completo *', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      TextField(controller: _nameCtrl, style: const TextStyle(color: Colors.white, fontSize: 13), decoration: InputDecoration(hintText: 'Nombre completo *', hintStyle: const TextStyle(color: Colors.white38, fontSize: 13), filled: true, fillColor: const Color(0xFF1E293B), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12))),
                      const SizedBox(height: 10),
                      const Text('Telefono *', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      TextField(controller: _phoneCtrl, keyboardType: TextInputType.phone, style: const TextStyle(color: Colors.white, fontSize: 13), decoration: InputDecoration(hintText: 'Ej: +56 9 6106 9670', hintStyle: const TextStyle(color: Colors.white38, fontSize: 13), filled: true, fillColor: const Color(0xFF1E293B), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12))),
                      const SizedBox(height: 16),
                      // Abono
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('5  Abono (opcional - 50%)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Checkbox(value: _abonoTransfer, activeColor: const Color(0xFF6366F1), onChanged: (v) => setState(() => _abonoTransfer = v ?? false)),
                                Expanded(child: Text(_selectedServicePrice > 0 ? 'Transferir abono de \$${(_selectedServicePrice / 2).round()} (50%)' : 'Transferir abono 50%', style: const TextStyle(color: Colors.white70, fontSize: 12))),
                              ],
                            ),
                            if (_abonoTransfer) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(8)),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Datos para transferir:', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 6),
                                    Text('Banco: $_bancoTransfer', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                    Text('Tipo: $_tipoCuentaTransfer', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                    Text('N° Cuenta: $_numeroCuentaTransfer', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                    Text('RUT: $_rutTransfer', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                    Text('Titular: $_titularTransfer', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                    Text('Email: $_emailTransfer', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                    const SizedBox(height: 6),
                                    const Text('Edita estos datos arriba en el archivo (EDITAR AQUI TUS DATOS DE TRANSFERENCIA).', style: TextStyle(color: Colors.white38, fontSize: 10)),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  Checkbox(value: _yaTransferi, activeColor: const Color(0xFF10B981), onChanged: (v) => setState(() => _yaTransferi = v ?? false)),
                                  const Expanded(child: Text('Ya transferi / mando comprobante por WhatsApp', style: TextStyle(color: Colors.white70, fontSize: 11))),
                                ],
                              ),
                            ],
                            if (!_abonoTransfer) const Text('O paga en el local el dia de tu cita.', style: TextStyle(color: Colors.white54, fontSize: 11)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _confirmar,
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          child: Text(_isSaving ? 'Reservando...' : 'Confirmar Reserva', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Center(child: Text('Horario de atencion: 11:00 a 19:00 - Ultima cita 18:30', style: TextStyle(color: Colors.white38, fontSize: 11))),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
