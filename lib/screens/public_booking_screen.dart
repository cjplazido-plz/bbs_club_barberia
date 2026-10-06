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

  // ✅ CAMBIO: Ahora es una lista de IDs (selección múltiple)
  Set<String> _selectedServiceIds = {};
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  String? _selectedTime;
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
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
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; });
    try {
      final services = await Supabase.instance.client
          .from('services')
          .select('*')
          .eq('is_active', true)
          .order('name');

      final barbers = await Supabase.instance.client
          .from('barbers')
          .select('*')
          .eq('is_active', true)
          .order('name');

      setState(() {
        _services = List<Map<String, dynamic>>.from(services);
        _barbers = List<Map<String, dynamic>>.from(barbers);
        _isLoading = false;
      });

      await _loadAppointmentsForDate(_selectedDate);
    } catch (e) {
      print('❌ Error al cargar datos: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar datos: $e'), backgroundColor: Colors.red),
        );
      }
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _loadAppointmentsForDate(DateTime date) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final appointments = await Supabase.instance.client
          .from('appointments')
          .select('*')
          .gte('appointment_date', startOfDay.toIso8601String())
          .lt('appointment_date', endOfDay.toIso8601String())
          .neq('status', 'cancelled');

      setState(() {
        _existingAppointments = List<Map<String, dynamic>>.from(appointments);
      });
    } catch (e) {
      print('⚠️ Error al cargar citas: $e');
    }
  }

  List<String> get _occupiedTimes {
    return _existingAppointments
        .map((apt) {
          final date = DateTime.parse(apt['appointment_date']);
          return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
        })
        .toSet()
        .toList();
  }

  // ✅ Calcular total de servicios seleccionados
  double get _totalPrice {
    double total = 0;
    for (var id in _selectedServiceIds) {
      final service = _services.firstWhere((s) => s['id'] == id, orElse: () => {});
      if (service.isNotEmpty) {
        total += (service['price'] as num?)?.toDouble() ?? 0.0;
      }
    }
    return total;
  }

  Future<void> _submitBooking() async {
    // ✅ Validación: al menos un servicio
    if (_selectedServiceIds.isEmpty) {
      _showError('Por favor selecciona al menos un servicio');
      return;
    }
    if (_selectedTime == null) {
      _showError('Por favor selecciona un horario');
      return;
    }
    if (_nameController.text.trim().isEmpty) {
      _showError('Por favor ingresa tu nombre');
      return;
    }
    if (_phoneController.text.trim().isEmpty) {
      _showError('Por favor ingresa tu teléfono');
      return;
    }

    setState(() { _isSubmitting = true; });

    try {
      final barber = _barbers.isNotEmpty ? _barbers.first : null;

      final timeParts = _selectedTime!.split(':');
      final appointmentDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        int.parse(timeParts[0]),
        int.parse(timeParts[1]),
      );

      final appointmentId = 'apt-${DateTime.now().millisecondsSinceEpoch}';

      // ✅ Crear lista de servicios seleccionados
      final selectedServices = _services.where((s) => _selectedServiceIds.contains(s['id'])).toList();
      final serviceNames = selectedServices.map((s) => s['name'] as String).join(', ');
      final serviceIds = selectedServices.map((s) => s['id'] as String).toList();
      final servicePrices = selectedServices.map((s) => (s['price'] as num?)?.toDouble() ?? 0.0).toList();

      // ✅ Insertar cita con múltiples servicios
      await Supabase.instance.client.from('appointments').insert({
        'id': appointmentId,
        'client_id': null,
        'client_name': _nameController.text.trim(),
        'client_phone': _phoneController.text.trim(),
        'client_email': _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        'barber_id': barber != null ? barber['id'] : null,
        'barber_name': barber != null ? barber['name'] : 'Sin asignar',
        'service_id': serviceIds.first, // ID principal (primer servicio)
        'service_name': serviceNames, // ✅ Nombres concatenados
        'service_price': _totalPrice, // ✅ Precio total
        'service_ids': serviceIds, // ✅ Lista de IDs (si la columna existe)
        'appointment_date': appointmentDateTime.toIso8601String(),
        'status': 'pending',
        'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        'source': 'web_booking',
      });

      await _sendConfirmationWhatsApp(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        serviceNames: serviceNames,
        totalPrice: _totalPrice,
        date: appointmentDateTime,
      );

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      print('❌ Error al guardar cita: $e');
      _showError('Error al guardar la cita: $e');
    } finally {
      if (mounted) {
        setState(() { _isSubmitting = false; });
      }
    }
  }

  Future<void> _sendConfirmationWhatsApp({
    required String name,
    required String phone,
    required String serviceNames,
    required double totalPrice,
    required DateTime date,
  }) async {
    String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.startsWith('0')) cleanPhone = cleanPhone.substring(1);
    if (!cleanPhone.startsWith('56') && cleanPhone.length == 9) cleanPhone = '56$cleanPhone';

    final dateStr = DateFormat('dd/MM/yyyy').format(date);
    final timeStr = DateFormat('HH:mm').format(date);
    final totalStr = SettingsService.formatCurrency(totalPrice);

    final message = 'Hola $name, tu solicitud de reserva en ${SettingsService.shopName} ha sido recibida.%0A%0A'
        '📅 *Fecha:* $dateStr%0A'
        '⏰ *Hora:* $timeStr%0A'
        '✂️ *Servicios:* $serviceNames%0A'
        '💰 *Total estimado:* $totalStr%0A%0A'
        'Te contactaremos pronto para confirmar. ¡Gracias! 💈';

    final url = 'https://api.whatsapp.com/send/?phone=$cleanPhone&text=$message';
    final uri = Uri.parse(url);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, webOnlyWindowName: '_blank');
        print('✅ WhatsApp abierto para confirmación');
      } else {
        print('️ No se pudo abrir WhatsApp');
      }
    } catch (e) {
      print(' Error al abrir WhatsApp: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Text('✅', style: TextStyle(fontSize: 32)),
            SizedBox(width: 8),
            Text('¡Reserva enviada!'),
          ],
        ),
        content: const Text(
          'Tu solicitud de reserva ha sido recibida exitosamente. Te contactaremos pronto para confirmar tu cita.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _nameController.clear();
              _phoneController.clear();
              _emailController.clear();
              _notesController.clear();
              setState(() {
                _selectedServiceIds.clear();
                _selectedTime = null;
              });
            },
            style: TextButton.styleFrom(
              backgroundColor: Colors.indigo[700],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Nueva reserva', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Text('←', style: TextStyle(fontSize: 24, color: Colors.white)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('📅 Reservar Cita'),
        backgroundColor: Colors.indigo[700],
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 16 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Center(
                    child: Column(
                      children: [
                        if (SettingsService.shopLogoUrl.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              SettingsService.shopLogoUrl,
                              height: isMobile ? 70 : 100,
                              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                            ),
                          ),
                        const SizedBox(height: 12),
                        Text(
                          SettingsService.shopName,
                          style: TextStyle(
                            fontSize: isMobile ? 22 : 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        if (SettingsService.shopAddress.isNotEmpty)
                          Text(
                            SettingsService.shopAddress,
                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        if (SettingsService.shopPhone.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Tel: ${SettingsService.shopPhone}',
                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Paso 1: Servicios (selección múltiple)
                  _buildSectionTitle('1️⃣ Selecciona los servicios'),
                  const SizedBox(height: 4),
                  Text(
                    'Puedes seleccionar varios servicios',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  if (_services.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(8)),
                      child: const Text('No hay servicios disponibles', style: TextStyle(color: Colors.orange)),
                    )
                  else
                    ..._services.map((service) => _buildServiceCardMulti(service)),
                  
                  // ✅ Mostrar total seleccionado
                  if (_selectedServiceIds.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.indigo[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.indigo),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total seleccionado:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          Text(
                            SettingsService.formatCurrency(_totalPrice),
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.indigo[700]),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),

                  // Paso 2: Fecha
                  _buildSectionTitle('2️⃣ Selecciona la fecha'),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                      );
                      if (picked != null) {
                        setState(() {
                          _selectedDate = picked;
                          _selectedTime = null;
                        });
                        await _loadAppointmentsForDate(picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.indigo),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.indigo[50],
                      ),
                      child: Row(
                        children: [
                          const Text('', style: TextStyle(fontSize: 22)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              DateFormat('EEEE, dd MMMM yyyy', 'es').format(_selectedDate),
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const Icon(Icons.calendar_today, color: Colors.indigo, size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Paso 3: Horario
                  _buildSectionTitle('3️⃣ Selecciona el horario'),
                  const SizedBox(height: 10),
                  if (_occupiedTimes.length >= _availableTimes.length)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8)),
                      child: const Text('No hay horarios disponibles para esta fecha', style: TextStyle(color: Colors.red)),
                    )
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _availableTimes.map((time) {
                        final isOccupied = _occupiedTimes.contains(time);
                        final isSelected = _selectedTime == time;
                        return InkWell(
                          onTap: isOccupied ? null : () => setState(() => _selectedTime = time),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isOccupied
                                  ? Colors.grey[300]
                                  : isSelected
                                      ? Colors.indigo
                                      : Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isOccupied ? Colors.grey : isSelected ? Colors.indigo : Colors.grey[300]!,
                              ),
                            ),
                            child: Text(
                              time,
                              style: TextStyle(
                                color: isOccupied ? Colors.grey[500] : isSelected ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                decoration: isOccupied ? TextDecoration.lineThrough : null,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 20),

                  // Paso 4: Datos
                  _buildSectionTitle('4️⃣ Tus datos'),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre completo *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Teléfono *',
                      hintText: '+56 9 1234 5678',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email (opcional)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notas (opcional)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.note),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),

                  // Botón enviar
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitBooking,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo[700],
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSubmitting
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                                SizedBox(width: 12),
                                Text('Enviando...', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                              ],
                            )
                          : const Text('CONFIRMAR RESERVA', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                        ),
                  const SizedBox(height: 24),

                  // Footer
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: const Row(
                      children: [
                        Text('ℹ️', style: TextStyle(fontSize: 22)),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Tu reserva será confirmada por WhatsApp. Los horarios marcados en gris ya están ocupados.',
                            style: TextStyle(fontSize: 12, color: Colors.blue),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo),
    );
  }

  // ✅ Tarjeta de servicio con selección múltiple (checkbox)
  Widget _buildServiceCardMulti(Map<String, dynamic> service) {
    final isSelected = _selectedServiceIds.contains(service['id']);
    final price = (service['price'] as num?)?.toDouble() ?? 0.0;
    final duration = service['duration'];

    return InkWell(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedServiceIds.remove(service['id']);
          } else {
            _selectedServiceIds.add(service['id']);
          }
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? Colors.indigo[50] : Colors.white,
          border: Border.all(color: isSelected ? Colors.indigo : Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            // ✅ Checkbox visual
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isSelected ? Colors.indigo : Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: isSelected ? Colors.indigo : Colors.grey),
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
            ),
            const SizedBox(width: 12),
            const Text('✂️', style: TextStyle(fontSize: 26)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service['name'],
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isSelected ? Colors.indigo : Colors.black87,
                    ),
                  ),
                  if (duration != null)
                    Text(
                      '$duration min',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                ],
              ),
            ),
            Text(
              SettingsService.formatCurrency(price),
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.indigo[700]),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}