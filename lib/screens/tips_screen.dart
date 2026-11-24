import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../services/settings_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// PANTALLA PROPINAS - Acumuladas y pagables semanal o a solicitud
// Patricio: filtra por fecha + barbero, totaliza, paga por barbero por periodo.
// Una propina es 100% del barbero, NO va al 50% de comisiones.
// Fuente: transaction_items donde service_name == 'Propina' (o service_id == 'propina')
// Pago: se guarda en tips_paid + cash_movements (salida 'Pago propina'), igual que comisiones.
// Si el barbero pide pago antes de la semana, Patricio elige periodo Personalizado y paga ese rango.
class TipsScreen extends StatefulWidget {
  @override
  State<TipsScreen> createState() => _TipsScreenState();
}

class _TipsScreenState extends State<TipsScreen> {
  bool _isLoading = true;
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  DateTime _endDate = DateTime.now();
  List<Map<String, dynamic>> _tipsPerBarber = [];
  List<Map<String, dynamic>> _detail = [];
  double _totalTips = 0;
  int _totalCount = 0;
  String _selectedBarberId = 'all';
  String _activeQuickFilter = 'today';
  String _filterEstado = 'todos'; // todos | pendiente | pagado
  Map<String, String> _paidFolios = {};

  bool get _isAdmin {
    final user = Supabase.instance.client.auth.currentUser;
    final e = (user?.email ?? '').toLowerCase().trim();
    if (e.contains('cjplazido') || e.contains('patriciosan')) return true;
    final role = (user?.userMetadata?['role'] ?? user?.userMetadata?['rol'] ?? '').toString().toLowerCase();
    if (role.contains('admin') || role.contains('desarrollador') || role.contains('developer')) return true;
    return false;
  }

  List<Map<String, dynamic>> get _filteredPerBarber {
    var list = _selectedBarberId == 'all' ? _tipsPerBarber : _tipsPerBarber.where((b) => (b['barber_id']?.toString() ?? '') == _selectedBarberId).toList();
    if (_filterEstado == 'pendiente') list = list.where((b) => !_paidFolios.containsKey((b['barber_id'] ?? '').toString())).toList();
    if (_filterEstado == 'pagado') list = list.where((b) => _paidFolios.containsKey((b['barber_id'] ?? '').toString())).toList();
    return list;
  }
  double get _filteredTotal => _filteredPerBarber.fold(0.0, (s, b) => s + (b['total_tips'] as double));
  int get _filteredCount => _filteredPerBarber.fold(0, (s, b) => s + (b['count'] as int));
  List<Map<String, dynamic>> get _filteredDetail {
    var list = _detail;
    if (_selectedBarberId != 'all') list = list.where((d) => (d['barber_id']?.toString() ?? '') == _selectedBarberId).toList();
    if (_filterEstado == 'pendiente') list = list.where((d) => !_paidFolios.containsKey((d['barber_id'] ?? '').toString())).toList();
    if (_filterEstado == 'pagado') list = list.where((d) => _paidFolios.containsKey((d['barber_id'] ?? '').toString())).toList();
    return list;
  }

  @override
  void initState() { super.initState(); _loadTips(); }

  Future<void> _loadPaidStatus() async {
    try {
      final ini = DateFormat('yyyy-MM-dd').format(_startDate);
      final fin = DateFormat('yyyy-MM-dd').format(_endDate);
      final res = await Supabase.instance.client.from('tips_paid').select('barber_id, folio').eq('periodo_inicio', ini).eq('periodo_fin', fin);
      final map = <String, String>{};
      for (final r in (res as List)) { map[(r['barber_id'] ?? '').toString()] = (r['folio'] ?? '').toString(); }
      if (mounted) setState(() => _paidFolios = map);
    } catch (e) { print('tips_paid no existe o error: $e'); }
  }

  Future<void> _loadTips() async {
    setState(() { _isLoading = true; });
    try {
      final startStr = _startDate.toIso8601String();
      final endStr = _endDate.add(const Duration(days: 1)).toIso8601String();
      final response = await Supabase.instance.client
          .from('transaction_items')
          .select("barber_id, barber_name, price_at_moment, quantity, service_name, service_id, transactions!inner(created_at, status, folio)")
          .eq('item_type', 'service')
          .gte('transactions.created_at', startStr)
          .lt('transactions.created_at', endStr)
          .eq('transactions.status', 'completed');
      final items = List<Map<String, dynamic>>.from(response);
      Map<String, Map<String, dynamic>> barberMap = {};
      List<Map<String, dynamic>> detail = [];
      for (final item in items) {
        final sName = (item['service_name'] ?? '').toString().toLowerCase().trim();
        final sId = (item['service_id'] ?? '').toString().toLowerCase().trim();
        if (sName != 'propina' && sId != 'propina') continue; // solo propinas
        final barberId = (item['barber_id'] ?? 'unknown').toString();
        final barberName = (item['barber_name'] ?? 'Desconocido').toString();
        final price = (item['price_at_moment'] as num?)?.toDouble() ?? 0.0;
        final qty = (item['quantity'] as num?)?.toInt() ?? 1;
        final total = price * qty;
        final tx = item['transactions'] as Map<String, dynamic>?;
        final created = tx?['created_at']?.toString() ?? '';
        final folio = tx?['folio']?.toString() ?? '';
        if (!barberMap.containsKey(barberId)) {
          barberMap[barberId] = {'barber_id': barberId, 'barber_name': barberName, 'total_tips': 0.0, 'count': 0};
        }
        barberMap[barberId]!['total_tips'] = (barberMap[barberId]!['total_tips'] as double) + total;
        barberMap[barberId]!['count'] = (barberMap[barberId]!['count'] as int) + qty;
        detail.add({'barber_id': barberId, 'barber_name': barberName, 'amount': total, 'created_at': created, 'folio': folio});
      }
      detail.sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String));
      final perBarber = barberMap.values.toList();
      perBarber.sort((a, b) => (b['total_tips'] as double).compareTo(a['total_tips'] as double));
      final total = perBarber.fold(0.0, (s, c) => s + (c['total_tips'] as double));
      final count = perBarber.fold(0, (s, c) => s + (c['count'] as int));
      setState(() { _tipsPerBarber = perBarber; _detail = detail; _totalTips = total; _totalCount = count; _isLoading = false; });
      await _loadPaidStatus();
    } catch (e) {
      print('Error propinas: $e');
      setState(() { _isLoading = false; });
    }
  }

  Future<bool> _marcarPagado(Map<String, dynamic> barber, String folio, String metodo) async {
    final name = barber['barber_name'] as String;
    final barberId = (barber['barber_id'] ?? '').toString();
    final total = barber['total_tips'] as double;
    final period = "${DateFormat('dd/MM/yyyy').format(_startDate)} - ${DateFormat('dd/MM/yyyy').format(_endDate)}";
    final ini = DateFormat('yyyy-MM-dd').format(_startDate);
    final fin = DateFormat('yyyy-MM-dd').format(_endDate);
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';
    try {
      await Supabase.instance.client.from('tips_paid').insert({
        'barber_id': barberId, 'barber_name': name,
        'periodo_inicio': ini, 'periodo_fin': fin,
        'monto': total, 'folio': folio, 'metodo': metodo, 'pagado_por': email,
      });
      await Supabase.instance.client.from('cash_movements').insert({
        'tipo': 'salida', 'categoria': 'Pago propina', 'monto': total, 'metodo': metodo, 'folio': folio,
        'motivo': 'Pago propina $name - periodo $period',
        'afecta_caja': metodo == 'cash',
        'created_at': DateTime.now().toIso8601String(),
      });
      await _loadPaidStatus();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pagado propina $name ${SettingsService.formatCurrency(total)} - $folio'), backgroundColor: const Color(0xFF10B981)));
      return true;
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('23505') || msg.contains('duplicate') || msg.contains('unique')) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ya estaba pagado para este periodo'), backgroundColor: Colors.orange));
        await _loadPaidStatus(); return false;
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar pago: $e'), backgroundColor: Colors.red));
      return false;
    }
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(context: context, initialDate: isStart ? _startDate : _endDate, firstDate: DateTime(2024), lastDate: DateTime.now().add(const Duration(days: 1)), helpText: isStart ? 'Fecha inicio' : 'Fecha fin');
    if (picked != null) {
      setState(() {
        if (isStart) _startDate = picked; else _endDate = picked;
        _activeQuickFilter = 'custom';
      });
      _loadTips();
    }
  }

  void _setQuick(String key) {
    final now = DateTime.now();
    setState(() {
      _activeQuickFilter = key;
      if (key == 'today') { _startDate = DateTime(now.year, now.month, now.day); _endDate = now; }
      if (key == 'week') { _startDate = now.subtract(Duration(days: now.weekday - 1)); _endDate = now; }
      if (key == 'month') { _startDate = DateTime(now.year, now.month, 1); _endDate = now; }
    });
    _loadTips();
  }

  void _showComprobanteDialog(Map<String, dynamic> barber, {bool soloImprimir = false}) {
    String metodoPago = 'cash';
    final name = barber['barber_name'] as String;
    final total = barber['total_tips'] as double;
    final count = barber['count'] as int;
    final period = "${DateFormat('dd/MM/yyyy').format(_startDate)} - ${DateFormat('dd/MM/yyyy').format(_endDate)}";
    final folio = 'PROP-${DateTime.now().millisecondsSinceEpoch}';
    final isPaid = _paidFolios.containsKey((barber['barber_id'] ?? '').toString());
    showDialog(context: context, builder: (ctx) => Dialog(
      backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(width: 340, padding: const EdgeInsets.all(20), child: SingleChildScrollView(child: Column(children: [
        Text((SettingsService.shopName.isNotEmpty ? SettingsService.shopName : 'BBS CLUB').toUpperCase(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
        const Text('COMPROBANTE DE PAGO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.black54)),
        const Text('Propinas Acumuladas', style: TextStyle(fontSize: 10, color: Colors.black54)),
        const SizedBox(height: 10), const Divider(color: Colors.black26, height: 1), const SizedBox(height: 10),
        _row('Folio:', folio), _row('Fecha:', DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())), _row('Periodo:', period),
        const SizedBox(height: 10), const Divider(color: Colors.black26, height: 1), const SizedBox(height: 10),
        _row('Barbero:', name), _row('Propinas:', '$count propinas'), _row('Total propinas:', SettingsService.formatCurrency(total)),
        const SizedBox(height: 10),
        Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12), decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('TOTAL A PAGAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)), Text(SettingsService.formatCurrency(total), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))])),
        const SizedBox(height: 18),
        Row(children: const [Expanded(child: Column(children: [Divider(color: Colors.black54), SizedBox(height: 4), Text('Firma Barbero', style: TextStyle(fontSize: 10, color: Colors.black54))])), SizedBox(width: 16), Expanded(child: Column(children: [Divider(color: Colors.black54), SizedBox(height: 4), Text('Firma Admin', style: TextStyle(fontSize: 10, color: Colors.black54))]))]),
        const SizedBox(height: 6),
        Text('Recibí conforme ${SettingsService.formatCurrency(total)} por propinas del periodo.', style: const TextStyle(fontSize: 9, color: Colors.black54), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        if (isPaid) ...[Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.12), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF10B981))), child: Text('✅ YA PAGADO - Folio ${_paidFolios[(barber['barber_id'] ?? '').toString()]}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981)), textAlign: TextAlign.center)), const SizedBox(height: 10)],
        if (!isPaid && _isAdmin && !soloImprimir) ...[
          StatefulBuilder(builder: (ctx2, setD) => Column(children: [
            const Text('Método de pago:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54)), const SizedBox(height: 6),
            SegmentedButton<String>(showSelectedIcon: false, segments: const [ButtonSegment(value: 'cash', label: Text('Efectivo', style: TextStyle(fontSize: 11))), ButtonSegment(value: 'transfer', label: Text('Transferencia', style: TextStyle(fontSize: 11)))], selected: {metodoPago}, onSelectionChanged: (v) => setD(() => metodoPago = v.first)),
            const SizedBox(height: 4),
            Text(metodoPago == 'cash' ? 'Efectivo SI resta de caja.' : 'Transferencia NO resta de caja.', style: const TextStyle(fontSize: 9, color: Colors.black54), textAlign: TextAlign.center),
          ])),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () async {
            final ok = await showDialog<bool>(context: ctx, builder: (c2) => AlertDialog(title: const Text('¿Pagar propinas?'), content: Text('¿Pagar ${SettingsService.formatCurrency(total)} de propinas a $name por el periodo $period?'), actions: [TextButton(onPressed: () => Navigator.pop(c2, false), child: const Text('Cancelar')), ElevatedButton(onPressed: () => Navigator.pop(c2, true), child: const Text('Sí, pagar'))]));
            if (ok == true) { Navigator.pop(ctx); await _marcarPagado(barber, folio, metodoPago); }
          }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37)), child: const Text('Pagar Propinas', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)))),
          const SizedBox(height: 8),
        ],
        SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar'))),
      ])),
    )));
  }

  Widget _row(String k, String v) => Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(k, style: const TextStyle(fontSize: 12, color: Colors.black54)), Text(v, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black))]));

  @override
  Widget build(BuildContext context) {
    final gold = const Color(0xFFD4AF37);
    final period = "${DateFormat('dd/MM/yyyy').format(_startDate)} - ${DateFormat('dd/MM/yyyy').format(_endDate)}";
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(backgroundColor: const Color(0xFF0A0A0A), title: const Text('💰 Propinas Acumuladas', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), iconTheme: const IconThemeData(color: Colors.white), actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loadTips)]),
      body: _isLoading ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37))) : SingleChildScrollView(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // FILTROS - igual estilo que Comisiones / Avanzados
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF141414), borderRadius: BorderRadius.circular(14), border: Border.all(color: gold.withOpacity(0.3))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Filtros', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            _chip('Hoy', 'today'), _chip('Esta Semana', 'week'), _chip('Este Mes', 'month'), _chip('Personalizado', 'custom'),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: InkWell(onTap: () => _pickDate(true), child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFF0A0A0A), borderRadius: BorderRadius.circular(10)), child: Text('Desde: ${DateFormat('dd/MM/yyyy').format(_startDate)}', style: const TextStyle(color: Colors.white, fontSize: 12))))),
            const SizedBox(width: 8),
            Expanded(child: InkWell(onTap: () => _pickDate(false), child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFF0A0A0A), borderRadius: BorderRadius.circular(10)), child: Text('Hasta: ${DateFormat('dd/MM/yyyy').format(_endDate)}', style: const TextStyle(color: Colors.white, fontSize: 12))))),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: Container(padding: const EdgeInsets.symmetric(horizontal: 10), decoration: BoxDecoration(color: const Color(0xFF0A0A0A), borderRadius: BorderRadius.circular(10)), child: DropdownButton<String>(value: _selectedBarberId, isExpanded: true, dropdownColor: const Color(0xFF141414), underline: const SizedBox(), style: const TextStyle(color: Colors.white, fontSize: 12), items: [const DropdownMenuItem(value: 'all', child: Text('Todos los barberos'))] + _tipsPerBarber.map((b) => DropdownMenuItem(value: (b['barber_id'] ?? '').toString(), child: Text(b['barber_name']))).toList(), onChanged: (v) => setState(() => _selectedBarberId = v ?? 'all')))),
            const SizedBox(width: 8),
            Expanded(child: Container(padding: const EdgeInsets.symmetric(horizontal: 10), decoration: BoxDecoration(color: const Color(0xFF0A0A0A), borderRadius: BorderRadius.circular(10)), child: DropdownButton<String>(value: _filterEstado, isExpanded: true, dropdownColor: const Color(0xFF141414), underline: const SizedBox(), style: const TextStyle(color: Colors.white, fontSize: 12), items: const [DropdownMenuItem(value: 'todos', child: Text('Todos')), DropdownMenuItem(value: 'pendiente', child: Text('Pendientes')), DropdownMenuItem(value: 'pagado', child: Text('Pagadas'))], onChanged: (v) => setState(() => _filterEstado = v ?? 'todos')))),
          ]),
          const SizedBox(height: 8),
          Text('Periodo: $period', style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ])),
        const SizedBox(height: 14),
        // TOTALES
        Row(children: [
          Expanded(child: _totalCard('Total Propinas', SettingsService.formatCurrency(_filteredTotal), gold)),
          const SizedBox(width: 10),
          Expanded(child: _totalCard('Cantidad', '$_filteredCount propinas', Colors.white)),
          const SizedBox(width: 10),
          Expanded(child: _totalCard('Barberos', '${_filteredPerBarber.length}', Colors.white)),
        ]),
        const SizedBox(height: 14),
        const Text('Por Barbero', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        if (_filteredPerBarber.isEmpty) Container(width: double.infinity, padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: const Color(0xFF141414), borderRadius: BorderRadius.circular(14)), child: const Text('No hay propinas en este periodo / filtro.', style: TextStyle(color: Colors.white54), textAlign: TextAlign.center)),
        ..._filteredPerBarber.map((b) {
          final isPaid = _paidFolios.containsKey((b['barber_id'] ?? '').toString());
          return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFF141414), borderRadius: BorderRadius.circular(14), border: Border.all(color: isPaid ? const Color(0xFF10B981).withOpacity(0.4) : gold.withOpacity(0.3))), child: Column(children: [
            Row(children: [
              CircleAvatar(backgroundColor: gold.withOpacity(0.15), child: Text((b['barber_name'] as String).isNotEmpty ? (b['barber_name'] as String)[0].toUpperCase() : '?', style: TextStyle(color: gold, fontWeight: FontWeight.bold))),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(b['barber_name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)), Text("${b['count']} propinas • $period", style: const TextStyle(color: Colors.white54, fontSize: 11))])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(SettingsService.formatCurrency(b['total_tips'] as double), style: TextStyle(color: gold, fontWeight: FontWeight.bold, fontSize: 16)), Container(margin: const EdgeInsets.only(top: 4), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: isPaid ? const Color(0xFF10B981).withOpacity(0.15) : Colors.orange.withOpacity(0.15), borderRadius: BorderRadius.circular(20)), child: Text(isPaid ? '✅ PAGADO ${_paidFolios[(b['barber_id'] ?? '').toString()]}' : '⏳ PENDIENTE', style: TextStyle(color: isPaid ? const Color(0xFF10B981) : Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)))]),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              if (_isAdmin && !isPaid) Expanded(child: ElevatedButton.icon(onPressed: () => _showComprobanteDialog(b), icon: const Icon(Icons.payments, size: 16), label: const Text('Pagar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), style: ElevatedButton.styleFrom(backgroundColor: gold, foregroundColor: Colors.black))),
              if (_isAdmin && !isPaid) const SizedBox(width: 8),
              Expanded(child: OutlinedButton.icon(onPressed: () => _showComprobanteDialog(b, soloImprimir: true), icon: const Icon(Icons.print, size: 16), label: Text(isPaid ? 'Ver Comprobante' : 'Solo Imprimir', style: const TextStyle(fontSize: 12)), style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white24)))),
            ]),
          ]));
        }),
        const SizedBox(height: 14),
        const Text('Detalle de Propinas', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        Container(decoration: BoxDecoration(color: const Color(0xFF141414), borderRadius: BorderRadius.circular(14)), child: _filteredDetail.isEmpty ? const Padding(padding: EdgeInsets.all(16), child: Text('Sin detalle en este filtro.', style: TextStyle(color: Colors.white54))) : Column(children: _filteredDetail.map((d) => ListTile(leading: CircleAvatar(backgroundColor: gold.withOpacity(0.15), child: Icon(Icons.monetization_on, color: gold, size: 16)), title: Text(d['barber_name'], style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)), subtitle: Text('Folio ${d['folio']} • ${d['created_at'].toString().isNotEmpty ? DateFormat('dd/MM/yyyy HH:mm').format(DateTime.tryParse(d['created_at'].toString()) ?? DateTime.now()) : ''}', style: const TextStyle(color: Colors.white54, fontSize: 11)), trailing: Text(SettingsService.formatCurrency(d['amount'] as double), style: TextStyle(color: gold, fontWeight: FontWeight.bold, fontSize: 13)))).toList())),
        const SizedBox(height: 12),
        const Text('Tip: Para pagar semanal, elige Esta Semana y paga por barbero. Si un barbero lo pide antes, elige Personalizado con el rango desde el último pago hasta hoy y paga solo ese rango.', style: TextStyle(color: Colors.white38, fontSize: 11)),
      ])),
    );
  }

  Widget _chip(String label, String key) => ChoiceChip(label: Text(label, style: const TextStyle(fontSize: 11)), selected: _activeQuickFilter == key, selectedColor: const Color(0xFFD4AF37), backgroundColor: const Color(0xFF0A0A0A), labelStyle: TextStyle(color: _activeQuickFilter == key ? Colors.black : Colors.white), onSelected: (_) => _setQuick(key));
  Widget _totalCard(String label, String value, Color color) => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF141414), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.3))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)), const SizedBox(height: 4), Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15))]));
}
