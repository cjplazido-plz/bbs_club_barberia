// lib/screens/blocked_hours_screen.dart - Solo admin: bloquear horas 11:00-19:00 cada 30 min
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class BlockedHoursScreen extends StatefulWidget {
  @override
  State<BlockedHoursScreen> createState() => _BlockedHoursScreenState();
}

class _BlockedHoursScreenState extends State<BlockedHoursScreen> {
  DateTime _selectedDate = DateTime.now();
  Set<String> _blocked = {};
  Set<String> _occupied = {};
  final TextEditingController _motivoCtrl = TextEditingController(text: 'No disponible');
  bool _isLoading = true;
  bool _isSaving = false;

  static const List<String> _allTimes = [
    '11:00', '11:30', '12:00', '12:30',
    '13:00', '13:30', '14:00', '14:30',
    '15:00', '15:30', '16:00', '16:30',
    '17:00', '17:30', '18:00', '18:30',
  ];

  @override
  void initState() {
    super.initState();
    _loadDay();
  }

  String get _fechaStr => DateFormat('yyyy-MM-dd').format(_selectedDate);

  Future<void> _loadDay() async {
    setState(() => _isLoading = true);
    try {
      final blocked = await Supabase.instance.client
          .from('blocked_slots')
          .select('hora')
          .eq('fecha', _fechaStr);
      final bSet = <String>{};
      for (final r in (blocked as List)) {
        bSet.add((r['hora'] ?? '').toString());
      }
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
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final email = Supabase.instance.client.auth.currentUser?.email ?? '';
      final motivo = _motivoCtrl.text.trim().isEmpty ? 'No disponible' : _motivoCtrl.text.trim();
      await Supabase.instance.client.from('blocked_slots').delete().eq('fecha', _fechaStr);
      if (_blocked.isNotEmpty) {
        final rows = _blocked.map((h) {
          return {'fecha': _fechaStr, 'hora': h, 'motivo': motivo, 'creado_por': email};
        }).toList();
        await Supabase.instance.client.from('blocked_slots').insert(rows);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_blocked.isEmpty ? 'Dia desbloqueado - todas las horas libres' : 'Guardado: ${_blocked.length} horas bloqueadas'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _isSaving = false);
  }

  void _onTapTime(String time, bool isBlocked, bool isOccupied) {
    if (isOccupied) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$time ya tiene cita, no se puede bloquear'), backgroundColor: Colors.orange),
      );
      return;
    }
    setState(() {
      if (isBlocked) {
        _blocked.remove(time);
      } else {
        _blocked.add(time);
      }
    });
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
      setState(() => _selectedDate = p);
      _loadDay();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Bloquear Horas - Solo Admin', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, color: Color(0xFF818CF8)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              DateFormat('EEEE, dd MMMM yyyy', 'es').format(_selectedDate),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                          const Text('Cambiar', style: TextStyle(color: Color(0xFF818CF8), fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_rounded, color: Color(0xFF818CF8), size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Horario 11:00 a 19:00 cada 30 min. Toca una hora para bloquearla / desbloquearla. La reserva web no dejara agendar las bloqueadas.',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Motivo (se muestra al cliente como No disponible)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _motivoCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Ej: Salon cerrado, almuerzo, personal...',
                      hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('Horas del dia', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      const Spacer(),
                      Text('${_blocked.length} bloqueadas', style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _blocked = Set.from(_allTimes)..removeAll(_occupied);
                            });
                          },
                          child: const Text('Bloquear todo el dia', style: TextStyle(fontSize: 12, color: Colors.redAccent)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => setState(() => _blocked.clear()),
                          child: const Text('Desbloquear todo', style: TextStyle(fontSize: 12, color: Color(0xFF10B981))),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _allTimes.map((time) {
                      final isBlocked = _blocked.contains(time);
                      final isOccupied = _occupied.contains(time);
                      final icon = isOccupied
                          ? Icons.event_busy_rounded
                          : isBlocked
                              ? Icons.lock_rounded
                              : Icons.lock_open_rounded;
                      final iconColor = isOccupied
                          ? Colors.white38
                          : isBlocked
                              ? Colors.redAccent
                              : const Color(0xFF10B981);
                      final bg = isOccupied
                          ? Colors.white10
                          : isBlocked
                              ? Colors.red.withOpacity(0.18)
                              : const Color(0xFF1E293B);
                      final borderColor = isOccupied
                          ? Colors.white24
                          : isBlocked
                              ? Colors.redAccent
                              : Colors.white10;
                      final textColor = isOccupied
                          ? Colors.white38
                          : isBlocked
                              ? Colors.redAccent
                              : Colors.white;
                      return InkWell(
                        onTap: () => _onTapTime(time, isBlocked, isOccupied),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: borderColor, width: isBlocked ? 2 : 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(icon, size: 14, color: iconColor),
                              const SizedBox(width: 6),
                              Text(
                                time,
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  decoration: isOccupied ? TextDecoration.lineThrough : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  if (_occupied.isNotEmpty)
                    Text('Ocupadas (con cita): ${_occupied.join(', ')}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _save,
                      icon: const Icon(Icons.save_rounded),
                      label: Text(_isSaving ? 'Guardando...' : 'Guardar bloqueo', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Solo admin (cjplazido / patriciosan) puede ver esta pantalla. El cliente en la web vera las horas bloqueadas en rojo con candado y no podra agendarlas.',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
    );
  }
}
