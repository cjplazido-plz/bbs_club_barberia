// PREMIUM RESERVAS - Solo colores: fondo 0A0A0A, tarjetas 141414, dorado D4AF37 / FBBF24. Lógica, permisos, mensajes y filtros intactos.
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../services/settings_service.dart';
import '../services/role_permissions.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class CommissionsScreen extends StatefulWidget {
  @override
  State<CommissionsScreen> createState() => _CommissionsScreenState();
}

class _CommissionsScreenState extends State<CommissionsScreen> {
  bool _isLoading = true;
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  DateTime _endDate = DateTime.now();
  List<Map<String, dynamic>> _commissions = [];
  double _totalCommissions = 0;
  double _totalSales = 0;
  String _selectedBarberId = 'all';
  String _activeQuickFilter = 'today';
  Map<String, String> _paidFolios = {};

  bool get _isAdmin {
    final user = Supabase.instance.client.auth.currentUser;
    final e = (user?.email ?? '').toLowerCase().trim();
    if (e.contains('cjplazido') || e.contains('patriciosan')) return true;
    final role = (user?.userMetadata?['role'] ?? user?.userMetadata?['rol'] ?? '').toString().toLowerCase();
    if (role.contains('admin') || role.contains('desarrollador') || role.contains('developer')) return true;
    return false;
  }

  // V8 ROLES - Pagar comisiones por permiso, no solo por correo.
  // Patricio y cjplazido siempre pueden pagar (seguridad, aunque falte la fila en Supabase).
  // Los demas solo si en Roles tienen activado 'Pagar Comisiones' (pagar_comisiones).
  // Por defecto: Admin SI, Cajero NO, Barbero NO, Barbero/Cajero NO. Patricio lo activa si quiere.
  String get _userRole {
    final user = Supabase.instance.client.auth.currentUser;
    final raw = (user?.userMetadata?['role'] ?? user?.userMetadata?['rol'] ?? '').toString().toLowerCase().trim();
    if (raw.contains('barber') && raw.contains('cashier')) return 'barber_cashier';
    if (raw.contains('barber') || raw.contains('barbero')) return 'barber';
    if (raw.contains('cashier') || raw.contains('cajero')) return 'cashier';
    if (raw.contains('admin') || raw.contains('desarrollador') || raw.contains('developer')) return 'admin';
    if (_isAdmin) return 'admin';
    return raw.isEmpty ? 'barber' : raw;
  }

  bool get _canPayCommissions {
    if (_isAdmin) return true;
    return RolePermissions.can(_userRole, BbsPerm.payCommissions);
  }

  Future<void> _loadPaidStatus() async {
    try {
      final ini = DateFormat('yyyy-MM-dd').format(_startDate);
      final fin = DateFormat('yyyy-MM-dd').format(_endDate);
      final res = await Supabase.instance.client.from('commissions_paid').select('barber_id, folio').eq('periodo_inicio', ini).eq('periodo_fin', fin);
      final map = <String, String>{};
      for (final r in (res as List)) { map[(r['barber_id'] ?? '').toString()] = (r['folio'] ?? '').toString(); }
      if (mounted) setState(() => _paidFolios = map);
    } catch (e) {
      print('commissions_paid no existe o error: $e');
    }
  }

  List<Map<String, dynamic>> get _filteredCommissions => _selectedBarberId == 'all' ? _commissions : _commissions.where((b) => (b['barber_id']?.toString() ?? '') == _selectedBarberId).toList();
  double get _filteredSales => _filteredCommissions.fold(0.0, (s, b) => s + (b['total_sales'] as double));
  double get _filteredCommissionsTotal => _filteredCommissions.fold(0.0, (s, b) => s + (b['total_commission'] as double));

  @override
  void initState() {
    super.initState();
    // Cargar permisos de Roles para que el boton Pagar obedezca lo que marque Patricio.
    RolePermissions.loadFromSupabase().then((_) { if (mounted) setState(() {}); });
    _loadCommissions();
  }

  Future<void> _loadCommissions() async {
    setState(() { _isLoading = true; });
    try {
      final startStr = _startDate.toIso8601String();
      final endStr = _endDate.add(const Duration(days: 1)).toIso8601String();
      final response = await Supabase.instance.client
          .from('transaction_items')
          .select("barber_id, barber_name, price_at_moment, quantity, commission_earned, transactions!inner(created_at, status)")
          .eq('item_type', 'service')
          .gte('transactions.created_at', startStr)
          .lt('transactions.created_at', endStr)
          .eq('transactions.status', 'completed');
      final items = List<Map<String, dynamic>>.from(response);
      Map<String, Map<String, dynamic>> barberMap = {};
      for (final item in items) {
        final barberId = item['barber_id'] ?? 'unknown';
        final barberName = item['barber_name'] ?? 'Desconocido';
        final price = (item['price_at_moment'] as num?)?.toDouble() ?? 0.0;
        final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
        // FIX CANTIDAD CORREGIDO: no multiplicar a ciegas.
// En BD hay mezcla: 7 filas ya están en total (ej 2x=12000) y 1 fila está por unidad (2x=6000).
// Solo se corrige la que está por unidad: si lo guardado es menor al total esperado (precio*qty*50%), se usa el esperado.
    final storedCommission = (item['commission_earned'] as num?)?.toDouble() ?? 0.0;
    final expectedTotal = price * quantity * 0.5;
    final commission = (quantity > 1 && storedCommission < expectedTotal * 0.9) ? expectedTotal : storedCommission;
        final totalItem = price * quantity;
        if (!barberMap.containsKey(barberId)) {
          barberMap[barberId] = {
            'barber_id': barberId,
            'barber_name': barberName,
            'total_sales': 0.0,
            'total_commission': 0.0,
            'services_count': 0,
          };
        }
        barberMap[barberId]!['total_sales'] = (barberMap[barberId]!['total_sales'] as double) + totalItem;
        barberMap[barberId]!['total_commission'] = (barberMap[barberId]!['total_commission'] as double) + commission;
        barberMap[barberId]!['services_count'] = (barberMap[barberId]!['services_count'] as int) + quantity;
      }
      final commissions = barberMap.values.toList();
      commissions.sort((a, b) => (b['total_commission'] as double).compareTo(a['total_commission'] as double));
      final totalCommissions = commissions.fold(0.0, (sum, c) => sum + (c['total_commission'] as double));
      final totalSales = commissions.fold(0.0, (sum, c) => sum + (c['total_sales'] as double));
      setState(() {
        _commissions = commissions;
        _totalCommissions = totalCommissions;
        _totalSales = totalSales;
        _isLoading = false;
      });
      await _loadPaidStatus();
    } catch (e) {
      print('Error comisiones: $e');
      setState(() { _isLoading = false; });
    }
  }

  Future<bool> _marcarPagado(Map<String, dynamic> barber, String folio, String metodo) async {
    final name = barber['barber_name'] as String;
    final barberId = (barber['barber_id'] ?? '').toString();
    final commission = barber['total_commission'] as double;
    final period = "${DateFormat('dd/MM/yyyy').format(_startDate)} - ${DateFormat('dd/MM/yyyy').format(_endDate)}";
    final ini = DateFormat('yyyy-MM-dd').format(_startDate);
    final fin = DateFormat('yyyy-MM-dd').format(_endDate);
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';
    try {
      await Supabase.instance.client.from('commissions_paid').insert({
        'barber_id': barberId,
        'barber_name': name,
        'periodo_inicio': ini,
        'periodo_fin': fin,
        'monto': commission,
        'folio': folio,
        'metodo': metodo,
        'pagado_por': email,
      });
      await Supabase.instance.client.from('cash_movements').insert({
        'tipo': 'salida',
        'categoria': 'Pago comisión',
        'monto': commission,
        'metodo': metodo,
        'folio': folio,
        'motivo': 'Pago comisión $name - periodo $period',
        'afecta_caja': metodo == 'cash',
        'created_at': DateTime.now().toIso8601String(),
      });
      await _loadPaidStatus();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pagado $name ${SettingsService.formatCurrency(commission)} - $folio'), backgroundColor: const Color(0xFF10B981)));
      return true;
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('23505') || msg.contains('duplicate') || msg.contains('unique')) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ya estaba pagado para este periodo'), backgroundColor: Colors.orange));
        await _loadPaidStatus();
        return false;
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar pago: $e'), backgroundColor: Colors.red));
      return false;
    }
  }


  // PAGO UNICO - 1 solo boton de pago. Manda el filtro: 1 barbero = 1 ticket, Todos = informe con todos.
  // Antes habia 1 boton Pagar por cada barbero (con 7 barberos = 7 botones). Ahora las tarjetas solo se tocan para ver detalle.
  void _showPagoUnicoDialog() {
    if (_filteredCommissions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No hay comisiones en este filtro'), backgroundColor: Colors.orange));
      return;
    }
    String metodoPago = 'cash';
    final list = List<Map<String, dynamic>>.from(_filteredCommissions);
    final total = _filteredCommissionsTotal;
    final period = "${DateFormat('dd/MM/yyyy').format(_startDate)} - ${DateFormat('dd/MM/yyyy').format(_endDate)}";
    final titulo = _selectedBarberId == 'all' ? 'Pagar a Todos (${list.length} barberos)' : 'Pagar a ${list.first['barber_name']}';
    showDialog(context: context, builder: (ctx) => Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(children: [
            Text((SettingsService.shopName.isNotEmpty ? SettingsService.shopName : 'BBS CLUB').toUpperCase(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
            Text(titulo, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black)),
            const Text('Pago de Comisiones', style: TextStyle(fontSize: 10, color: Colors.black54)),
            const SizedBox(height: 10),
            const Divider(color: Colors.black26, height: 1),
            const SizedBox(height: 10),
            _comprobanteRow('Periodo:', period),
            _comprobanteRow('Barberos:', '${list.length}'),
            const SizedBox(height: 10),
            const Divider(color: Colors.black26, height: 1),
            const SizedBox(height: 10),
            ...list.map((b) {
              final n = (b['barber_name'] ?? 'Desconocido').toString();
              final v = (b['total_sales'] as double?) ?? 0.0;
              final c = (b['total_commission'] as double?) ?? 0.0;
              final cnt = (b['services_count'] as int?) ?? 0;
              final pagado = _paidFolios.containsKey((b['barber_id'] ?? '').toString());
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('$n  •  $cnt serv.', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black)),
                    Text('Ventas ${SettingsService.formatCurrency(v)}', style: const TextStyle(fontSize: 10, color: Colors.black54)),
                  ])),
                  const SizedBox(width: 8),
                  Text(SettingsService.formatCurrency(c), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black)),
                  const SizedBox(width: 6),
                  Icon(pagado ? Icons.check_circle_rounded : Icons.circle_outlined, size: 16, color: pagado ? const Color(0xFF10B981) : Colors.black26),
                ]),
              );
            }),
            const SizedBox(height: 10),
            Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12), decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('TOTAL A PAGAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)), Text(SettingsService.formatCurrency(total), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))])),
            const SizedBox(height: 14),
            StatefulBuilder(builder: (ctx2, setStateDialog) {
              final todosPagados = list.every((b) => _paidFolios.containsKey((b['barber_id'] ?? '').toString()));
              return Column(children: [
                if (todosPagados) ...[
                  Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.12), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF10B981))), child: const Text('✅ YA PAGADO - Todo el filtro', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981)), textAlign: TextAlign.center)),
                  const SizedBox(height: 10),
                ],
                if (!todosPagados && _canPayCommissions) ...[
                  const Text('Método de pago:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54)),
                  const SizedBox(height: 6),
                  SegmentedButton<String>(
                    showSelectedIcon: false,
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? const Color(0xFFD4AF37) : Colors.white),
                      foregroundColor: WidgetStateProperty.resolveWith((states) => Colors.black),
                      side: WidgetStateProperty.all(const BorderSide(color: Colors.black26)),
                    ),
                    segments: const [
                      ButtonSegment(value: 'cash', label: Text('Efectivo', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black))),
                      ButtonSegment(value: 'transfer', label: Text('Transferencia', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black))),
                    ],
                    selected: {metodoPago},
                    onSelectionChanged: (v) { setStateDialog(() => metodoPago = v.first); },
                  ),
                  const SizedBox(height: 4),
                  Text(metodoPago == 'cash' ? 'Efectivo SI resta de caja en cuadratura.' : 'Transferencia NO resta de caja (no sale de caja).', style: const TextStyle(fontSize: 9, color: Colors.black54), textAlign: TextAlign.center),
                  const SizedBox(height: 10),
                  SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () async {
                    // PAGO SOLO: pide confirmacion, paga, y NO imprime solo.
                    final confirmar = await showDialog<bool>(context: ctx, builder: (c3) => AlertDialog(
                      title: const Text('¿Confirmas el pago?', style: TextStyle(fontWeight: FontWeight.bold)),
                      content: Text('Vas a pagar ${SettingsService.formatCurrency(total)} a ${list.length} barbero${list.length == 1 ? '' : 's'} del periodo $period.\n\nEsto marca como PAGADO y, si es efectivo, resta de caja en cuadratura. Esta accion no se puede deshacer desde la app.'),
                      actions: [TextButton(onPressed: () => Navigator.pop(c3, false), child: const Text('Cancelar')), ElevatedButton(onPressed: () => Navigator.pop(c3, true), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37), foregroundColor: Colors.black), child: const Text('Sí, pagar'))],
                    ));
                    if (confirmar != true) return;
                    var okCount = 0;
                    for (final b in list) {
                      final id = (b['barber_id'] ?? '').toString();
                      if (_paidFolios.containsKey(id)) continue;
                      final folio = 'COM-${DateTime.now().millisecondsSinceEpoch}-$id';
                      final ok = await _marcarPagado(b, folio, metodoPago);
                      if (ok) okCount++;
                    }
                    if (okCount > 0) {
                      if (context.mounted) Navigator.pop(ctx);
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pagado $okCount barbero${okCount == 1 ? '' : 's'} - ${SettingsService.formatCurrency(total)}'), backgroundColor: const Color(0xFF10B981)));
                    }
                  }, icon: const Icon(Icons.check_circle_rounded, size: 16), label: Text('PAGAR ${SettingsService.formatCurrency(total)} - Confirmar', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37), foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 12)))),
                  const SizedBox(height: 8),
                ],
                if (!todosPagados && !_canPayCommissions) ...[
                  const Text('No tienes permiso Pagar Comisiones en Roles. Solo puedes Solo Imprimir. Pidele a Patricio que lo active si debe pagar.', style: TextStyle(fontSize: 10, color: Colors.black54), textAlign: TextAlign.center),
                  const SizedBox(height: 10),
                ],
              ]);
            }),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar'))),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton.icon(onPressed: () { Navigator.pop(ctx); _printInformeTicket(); }, icon: const Icon(Icons.print_rounded, size: 16), label: const Text('Solo Imprimir (sin pagar)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)))),
            ]),
          ]),
        ),
      ),
    ));
  }

  void _showComprobanteDialog(Map<String, dynamic> barber) {
    String metodoPago = 'cash';
    final name = barber['barber_name'] as String;
    final sales = barber['total_sales'] as double;
    final commission = barber['total_commission'] as double;
    final count = barber['services_count'] as int;
    final rate = sales > 0 ? (commission / sales * 100) : 0.0;
    final period = "${DateFormat('dd/MM/yyyy').format(_startDate)} - ${DateFormat('dd/MM/yyyy').format(_endDate)}";
    final folio = 'COM-${DateTime.now().millisecondsSinceEpoch}';
    showDialog(context: context, builder: (ctx) => Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        width: 340,
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(children: [
            Text((SettingsService.shopName.isNotEmpty ? SettingsService.shopName : 'BBS CLUB').toUpperCase(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
            const Text('COMPROBANTE DE PAGO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.black54)),
            const Text('Comisión de Barbero', style: TextStyle(fontSize: 10, color: Colors.black54)),
            const SizedBox(height: 10),
            const Divider(color: Colors.black26, height: 1),
            const SizedBox(height: 10),
            _comprobanteRow('Folio:', folio),
            _comprobanteRow('Fecha:', DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())),
            _comprobanteRow('Periodo:', period),
            const SizedBox(height: 10),
            const Divider(color: Colors.black26, height: 1),
            const SizedBox(height: 10),
            _comprobanteRow('Barbero:', name),
            _comprobanteRow('Servicios:', '$count servicios'),
            _comprobanteRow('Ventas:', SettingsService.formatCurrency(sales)),
            _comprobanteRow('% Comisión:', '${rate.toStringAsFixed(1)}%'),
            const SizedBox(height: 10),
            Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12), decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('TOTAL A PAGAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)), Text(SettingsService.formatCurrency(commission), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))])),
            const SizedBox(height: 18),
            Row(children: const [Expanded(child: Column(children: [Divider(color: Colors.black54), SizedBox(height: 4), Text('Firma Barbero', style: TextStyle(fontSize: 10, color: Colors.black54))])), SizedBox(width: 16), Expanded(child: Column(children: [Divider(color: Colors.black54), SizedBox(height: 4), Text('Firma Admin', style: TextStyle(fontSize: 10, color: Colors.black54))]))]),
            const SizedBox(height: 6),
            Text('Recibí conforme ${SettingsService.formatCurrency(commission)} por comisiones del periodo.', style: const TextStyle(fontSize: 9, color: Colors.black54), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            if (_paidFolios.containsKey((barber['barber_id'] ?? '').toString())) ...[
              Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.12), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF10B981))), child: Text('✅ YA PAGADO - Folio ${_paidFolios[(barber['barber_id'] ?? '').toString()]}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981)), textAlign: TextAlign.center)),
              const SizedBox(height: 10),
            ],
            // PAGO UNICO: el pago ya no es por barbero. Este dialogo es solo Ver / Imprimir.
            // Para pagar usa el boton unico de arriba, que paga segun el filtro.
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar'))),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton.icon(onPressed: () { Navigator.pop(ctx); _printComprobante(barber, folio, period); }, icon: const Icon(Icons.print_rounded, size: 16), label: const Text('Solo Imprimir (sin pagar)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)))),
            ]),
          ]),
        ),
      ),
    ));
  }

  Widget _comprobanteRow(String label, String value) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)), Flexible(child: Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black), textAlign: TextAlign.right))]));
  }

  Future<void> _printComprobante(Map<String, dynamic> barber, String folio, String period) async {
    final name = barber['barber_name'] as String;
    final sales = barber['total_sales'] as double;
    final commission = barber['total_commission'] as double;
    final count = barber['services_count'] as int;
    final rate = sales > 0 ? (commission / sales * 100) : 0.0;
    final pdf = pw.Document();
    pdf.addPage(pw.Page(
      pageFormat: const PdfPageFormat(80 * PdfPageFormat.mm, double.infinity, marginLeft: 2 * PdfPageFormat.mm, marginRight: 2 * PdfPageFormat.mm, marginTop: 3 * PdfPageFormat.mm, marginBottom: 3 * PdfPageFormat.mm),
      build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
        pw.Text((SettingsService.shopName.isNotEmpty ? SettingsService.shopName : 'BBS CLUB').toUpperCase(), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
        pw.Text('COMPROBANTE DE PAGO', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        pw.Text('Comisión de Barbero', style: const pw.TextStyle(fontSize: 9)),
        pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Folio:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)), pw.Text(folio, style: const pw.TextStyle(fontSize: 9))]),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Fecha:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)), pw.Text(DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()), style: const pw.TextStyle(fontSize: 10))]),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Periodo:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)), pw.Text(period, style: const pw.TextStyle(fontSize: 9))]),
        pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Barbero:', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)), pw.Text(name, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold))]),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Servicios:', style: const pw.TextStyle(fontSize: 10)), pw.Text('$count servicios', style: const pw.TextStyle(fontSize: 10))]),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Ventas:', style: const pw.TextStyle(fontSize: 10)), pw.Text(SettingsService.formatCurrency(sales), style: const pw.TextStyle(fontSize: 10))]),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('% Comisión:', style: const pw.TextStyle(fontSize: 10)), pw.Text('${rate.toStringAsFixed(1)}%', style: const pw.TextStyle(fontSize: 10))]),
        pw.SizedBox(height: 3 * PdfPageFormat.mm),
        pw.Container(padding: pw.EdgeInsets.symmetric(vertical: 3 * PdfPageFormat.mm, horizontal: 3 * PdfPageFormat.mm), decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)), child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('TOTAL A PAGAR', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)), pw.Text(SettingsService.formatCurrency(commission), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold))])),
        pw.SizedBox(height: 6 * PdfPageFormat.mm),
        pw.Row(children: [pw.Expanded(child: pw.Column(children: [pw.Divider(), pw.Text('Firma Barbero', style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.center)])), pw.SizedBox(width: 4 * PdfPageFormat.mm), pw.Expanded(child: pw.Column(children: [pw.Divider(), pw.Text('Firma Admin', style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.center)]))]),
        pw.SizedBox(height: 3 * PdfPageFormat.mm),
        pw.Text('Recibí conforme ${SettingsService.formatCurrency(commission)} por comisiones del periodo.', style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center),
        pw.SizedBox(height: 2 * PdfPageFormat.mm),
        pw.Text('¡Gracias!', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
      ]),
    ));
    await Printing.layoutPdf(onLayout: (f) async => pdf.save(), name: 'Comprobante-Comision-$name.pdf');
  }


  // TICKET TÉRMICA - Informe completo, mismo formato que el ticket del POS:
  // mismo papel (58/80mm según Impresora), misma letra chica, mismo encabezado (nombre/RUT/dirección/teléfono)
  // y mismo pie de ticket de Ajustes. No usa el PDF A4 del informe, usa el ancho térmico.
  Future<void> _printInformeTicket() async {
    // FIX BUILD: PrinterService real (EASTON) no tiene paperSize - solo printTicket.
    // El ticket real es FIJO 80mm Courier Bold, igual que ticket_easton.dart.
    // Por eso el informe termico tambien es fijo 80mm, no 58/80 variable.
    const double widthMm = 80.0;
    const double titleSize = 16.0;
    const double rowSize = 10.0;
    const double totalSize = 13.0;
    final monoBold = pw.Font.courierBold();
    final period = '${DateFormat('dd/MM/yyyy').format(_startDate)} - ${DateFormat('dd/MM/yyyy').format(_endDate)}';
    final list = _filteredCommissions;
    final totalVentas = _filteredSales;
    final totalCom = _filteredCommissionsTotal;
    final neta = totalVentas - totalCom;

    final pdf = pw.Document();
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat(widthMm * PdfPageFormat.mm, double.infinity,
          marginLeft: 2 * PdfPageFormat.mm, marginRight: 2 * PdfPageFormat.mm,
          marginTop: 3 * PdfPageFormat.mm, marginBottom: 3 * PdfPageFormat.mm),
      build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
        pw.Text((SettingsService.shopName.isNotEmpty ? SettingsService.shopName : 'BBS CLUB').toUpperCase(),
            style: pw.TextStyle(font: monoBold, fontSize: titleSize, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
        if (SettingsService.shopRif.isNotEmpty) pw.Text('RUT: ${SettingsService.shopRif}', style: pw.TextStyle(font: monoBold, fontSize: rowSize)),
        if (SettingsService.shopAddress.isNotEmpty) pw.Text(SettingsService.shopAddress, style: pw.TextStyle(font: monoBold, fontSize: rowSize), textAlign: pw.TextAlign.center),
        if (SettingsService.shopPhone.isNotEmpty) pw.Text('Tel: ${SettingsService.shopPhone}', style: pw.TextStyle(font: monoBold, fontSize: rowSize)),
        pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
        pw.Text('INFORME COMISIONES', style: pw.TextStyle(font: monoBold, fontSize: rowSize + 1, fontWeight: pw.FontWeight.bold)),
        pw.Text('Periodo: $period', style: pw.TextStyle(font: monoBold, fontSize: rowSize)),
        pw.Text('Impreso: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}', style: pw.TextStyle(font: monoBold, fontSize: rowSize)),
        pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
        // Detalle por barbero
        ...list.map((b) {
          final n = (b['barber_name'] ?? 'Desconocido').toString();
          final cnt = (b['services_count'] as int?) ?? 0;
          final ventas = (b['total_sales'] as double?) ?? 0.0;
          final comi = (b['total_commission'] as double?) ?? 0.0;
          final rate = ventas > 0 ? (comi / ventas * 100) : 0.0;
          final shortName = n.length > 22 ? n.substring(0, 22) : n;
          return pw.Column(children: [
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text(shortName, style: pw.TextStyle(font: monoBold, fontSize: rowSize, fontWeight: pw.FontWeight.bold)),
              pw.Text('$cnt serv.', style: pw.TextStyle(font: monoBold, fontSize: rowSize)),
            ]),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('Ventas: ${SettingsService.formatCurrency(ventas)}', style: pw.TextStyle(font: monoBold, fontSize: rowSize)),
              pw.Text('${rate.toStringAsFixed(1)}%', style: pw.TextStyle(font: monoBold, fontSize: rowSize)),
            ]),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('Comision:', style: pw.TextStyle(font: monoBold, fontSize: rowSize, fontWeight: pw.FontWeight.bold)),
              pw.Text(SettingsService.formatCurrency(comi), style: pw.TextStyle(font: monoBold, fontSize: rowSize, fontWeight: pw.FontWeight.bold)),
            ]),
            pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),
          ]);
        }),
        pw.SizedBox(height: 2 * PdfPageFormat.mm),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('TOTAL VENTAS', style: pw.TextStyle(font: monoBold, fontSize: rowSize, fontWeight: pw.FontWeight.bold)),
          pw.Text(SettingsService.formatCurrency(totalVentas), style: pw.TextStyle(font: monoBold, fontSize: rowSize, fontWeight: pw.FontWeight.bold)),
        ]),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('TOTAL COMISIONES', style: pw.TextStyle(font: monoBold, fontSize: rowSize, fontWeight: pw.FontWeight.bold)),
          pw.Text(SettingsService.formatCurrency(totalCom), style: pw.TextStyle(font: monoBold, fontSize: rowSize, fontWeight: pw.FontWeight.bold)),
        ]),
        pw.Container(padding: pw.EdgeInsets.symmetric(vertical: 3 * PdfPageFormat.mm, horizontal: 3 * PdfPageFormat.mm),
            decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)),
            child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('GANANCIA NETA', style: pw.TextStyle(font: monoBold, fontSize: totalSize, fontWeight: pw.FontWeight.bold)),
              pw.Text(SettingsService.formatCurrency(neta), style: pw.TextStyle(font: monoBold, fontSize: totalSize, fontWeight: pw.FontWeight.bold)),
            ])),
        pw.SizedBox(height: 4 * PdfPageFormat.mm),
        pw.Row(children: [
          pw.Expanded(child: pw.Column(children: [pw.Divider(), pw.Text('Firma Barbero', style: pw.TextStyle(font: monoBold, fontSize: rowSize), textAlign: pw.TextAlign.center)])),
          pw.SizedBox(width: 4 * PdfPageFormat.mm),
          pw.Expanded(child: pw.Column(children: [pw.Divider(), pw.Text('Firma Admin', style: pw.TextStyle(font: monoBold, fontSize: rowSize), textAlign: pw.TextAlign.center)])),
        ]),
        pw.SizedBox(height: 3 * PdfPageFormat.mm),
        pw.Text(SettingsService.ticketFooter.isNotEmpty ? SettingsService.ticketFooter : '¡Gracias por su visita!',
            style: pw.TextStyle(font: monoBold, fontSize: rowSize), textAlign: pw.TextAlign.center),
      ]),
    ));
    await Printing.layoutPdf(onLayout: (f) async => pdf.save(), name: 'Informe-Comisiones-Ticket.pdf');
  }

  void _setQuickDate(String type) {
    final now = DateTime.now();
    setState(() {
      _activeQuickFilter = type;
      if (type == 'today') {
        _startDate = DateTime(now.year, now.month, now.day);
        _endDate = now;
      } else if (type == 'week') {
        // FIX: Filtra los últimos 7 días
        _startDate = now.subtract(const Duration(days: 7));
        _startDate = DateTime(_startDate.year, _startDate.month, _startDate.day);
        _endDate = now;
      } else if (type == 'month') {
        // FIX: Filtra los últimos 30 días
        _startDate = now.subtract(const Duration(days: 30));
        _startDate = DateTime(_startDate.year, _startDate.month, _startDate.day);
        _endDate = now;
      }
    });
    _loadCommissions();
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context, 
      firstDate: DateTime(2020), 
      lastDate: DateTime.now().add(const Duration(days: 1)), 
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate), 
      locale: const Locale('es'),
      builder: (c, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFD4AF37),
            onPrimary: Colors.white,
            surface: Color(0xFF141414),
            onSurface: Colors.white,
          ),
          dialogBackgroundColor: const Color(0xFF0A0A0A),
        ), 
        child: child!
      )
    );
    if (picked != null) {
      setState(() { 
        _startDate = picked.start; 
        _endDate = picked.end; 
        _activeQuickFilter = 'custom'; 
      });
      await _loadCommissions();
    }
  }

  Widget _buildQuickDateChip(String label, String type) {
    final isSelected = _activeQuickFilter == type;
    return InkWell(
      onTap: () => _setQuickDate(type),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD4AF37) : const Color(0xFF0A0A0A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? const Color(0xFFD4AF37) : Colors.white10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white54,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141414), 
        borderRadius: BorderRadius.circular(16), 
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 18)), 
          const Spacer(), 
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle))
        ]),
        const SizedBox(height: 14),
        Text(title, style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
      ]),
    );
  }

  Widget _buildBarberCard(Map<String, dynamic> barber, int position) {
    final barberName = barber['barber_name'] as String;
    final totalSales = barber['total_sales'] as double;
    final totalCommission = barber['total_commission'] as double;
    final servicesCount = barber['services_count'] as int;
    final commissionRate = totalSales > 0 ? (totalCommission / totalSales * 100) : 0.0;
    
    final isPaid = _paidFolios.containsKey((barber['barber_id'] ?? '').toString());
    final medals = ['🥇', '🥈', '🥉'];
    final medal = position <= 3 ? medals[position - 1] : '#$position';

    return InkWell(
      onTap: () => _showComprobanteDialog(barber),
      borderRadius: BorderRadius.circular(16),
      child: Container(
      margin: const EdgeInsets.only(bottom: 12, left: 12, right: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141414), 
        borderRadius: BorderRadius.circular(16), 
        border: Border.all(color: Colors.white.withOpacity(0.06)), 
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))]
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 36, height: 36, 
            decoration: BoxDecoration(color: const Color(0xFF0A0A0A), shape: BoxShape.circle, border: Border.all(color: Colors.white10)),
            child: Center(child: Text(medal, style: const TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(barberName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)), 
            Text('$servicesCount servicios realizados', style: const TextStyle(color: Colors.white54, fontSize: 11))
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), 
            decoration: BoxDecoration(color: const Color(0xFFD4AF37).withOpacity(0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3))), 
            child: Text('${commissionRate.toStringAsFixed(1)}%', style: const TextStyle(color: Color(0xFFFBBF24), fontWeight: FontWeight.bold, fontSize: 11))
          ),
        ]),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Ventas Totales', style: TextStyle(fontSize: 10, color: Colors.white38, fontWeight: FontWeight.w600)), 
            const SizedBox(height: 2), 
            Text(SettingsService.formatCurrency(totalSales), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white))
          ]),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Text('Comisión a Pagar', style: TextStyle(fontSize: 10, color: Colors.white38, fontWeight: FontWeight.w600)), 
            const SizedBox(height: 2), 
            Text(SettingsService.formatCurrency(totalCommission), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF10B981)))
          ]),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          if (isPaid) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.12), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF10B981))),
              child: Row(children: [
                const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF10B981)),
                const SizedBox(width: 4),
                Text('PAGADO${_paidFolios[(barber['barber_id'] ?? '').toString()] != null ? ' • ${_paidFolios[(barber['barber_id'] ?? '').toString()]}' : ''}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF10B981)))
              ])
            ),
          ],
          const Spacer(),
          const Text('Toca para ver detalle ›', style: TextStyle(fontSize: 11, color: Colors.white38, fontWeight: FontWeight.w600)),
        ]),
      ]),
      ),
    );
  }

  Widget _buildPremiumDropdown({required String label, required IconData icon, required String value, required List<DropdownMenuItem<String>> items, required ValueChanged<String?> onChanged}) {
    return DropdownButtonFormField<String>(
      value: value,
      dropdownColor: const Color(0xFF141414),
      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white54, size: 20),
      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54, fontSize: 11),
        floatingLabelStyle: const TextStyle(color: Color(0xFFFBBF24), fontSize: 12),
        prefixIcon: Icon(icon, color: const Color(0xFFFBBF24), size: 18),
        filled: true,
        fillColor: const Color(0xFF0A0A0A),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.08))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      items: items,
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: const Text('Comisiones Premium', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: const Color(0xFF141414),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [IconButton(icon: const Icon(Icons.receipt_long_rounded, color: Color(0xFFD4AF37)), tooltip: 'Ticket Térmica - según filtro', onPressed: _printInformeTicket), IconButton(icon: const Icon(Icons.sync_rounded, color: Colors.white70), tooltip: 'Sincronizar', onPressed: _loadCommissions)],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141414), 
                      borderRadius: BorderRadius.circular(16), 
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))]
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: const Color(0xFFD4AF37).withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.tune_rounded, size: 16, color: Color(0xFFFBBF24))),
                        const SizedBox(width: 10),
                        const Text('Filtros de Búsqueda', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      ]),
                      const SizedBox(height: 16),
                      
                      // FILTRO UNIFICADO - mismo estilo que Reportes Avanzados (Período de Análisis)
                      Row(
                        children: const [
                          Icon(Icons.calendar_month_rounded, color: Color(0xFFFBBF24), size: 18),
                          SizedBox(width: 8),
                          Text('Período de Análisis', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<String>(
                          showSelectedIcon: false,
                          style: ButtonStyle(
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            backgroundColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? const Color(0xFFD4AF37) : Colors.transparent),
                            foregroundColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? Colors.white : Colors.white54),
                            side: WidgetStateProperty.all(BorderSide(color: Colors.white.withOpacity(0.1))),
                          ),
                          segments: const [
                            ButtonSegment(value: 'today', label: Text('Hoy', style: TextStyle(fontSize: 11))),
                            ButtonSegment(value: 'week', label: Text('Semana', style: TextStyle(fontSize: 11))),
                            ButtonSegment(value: 'month', label: Text('Mes', style: TextStyle(fontSize: 11))),
                          ],
                          selected: {['today', 'week', 'month'].contains(_activeQuickFilter) ? _activeQuickFilter : 'today'},
                          onSelectionChanged: (Set<String> v) { _setQuickDate(v.first); },
                        ),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: _selectDateRange,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0A0A0A),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _activeQuickFilter == 'custom' ? const Color(0xFFD4AF37) : Colors.white.withOpacity(0.08)),
                          ),
                          child: Row(children: [
                            Icon(Icons.date_range_rounded, color: _activeQuickFilter == 'custom' ? const Color(0xFFD4AF37) : Colors.white38, size: 18),
                            const SizedBox(width: 10),
                            Expanded(child: FittedBox(alignment: Alignment.centerLeft, fit: BoxFit.scaleDown, child: Text('${DateFormat('dd/MM/yyyy').format(_startDate)}  →  ${DateFormat('dd/MM/yyyy').format(_endDate)}', style: TextStyle(color: _activeQuickFilter == 'custom' ? Colors.white : Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)))),
                            const SizedBox(width: 8),
                            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFD4AF37).withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: Text(_activeQuickFilter == 'custom' ? 'CAMBIAR' : 'EDITAR', style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 10, fontWeight: FontWeight.bold))),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 16),

                      _buildPremiumDropdown(
                        label: 'Filtrar por Barbero', 
                        icon: Icons.person_search_rounded, 
                        value: _selectedBarberId, 
                        items: [
                          const DropdownMenuItem(value: 'all', child: Text('👥 Todos los barberos')),
                          ..._commissions.map((b) => DropdownMenuItem(value: b['barber_id'].toString(), child: Text('💈 ${b['barber_name']}  •  ${SettingsService.formatCurrency(b['total_commission'] as double)}'))),
                        ], 
                        onChanged: (v) => setState(() => _selectedBarberId = v ?? 'all')
                      ),
                      
                      if (_selectedBarberId != 'all') 
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: SizedBox(width: double.infinity, child: TextButton.icon(
                            onPressed: () => setState(() => _selectedBarberId = 'all'), 
                            icon: const Icon(Icons.clear_all_rounded, size: 16, color: Colors.redAccent), 
                            label: const Text('Limpiar filtro de barbero', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                            style: TextButton.styleFrom(backgroundColor: Colors.redAccent.withOpacity(0.1), padding: const EdgeInsets.symmetric(vertical: 10)),
                          )),
                        ),
                    ]),
                  ),
                ),
                
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _filteredCommissions.isEmpty ? null : _showPagoUnicoDialog,
                          icon: Icon(_canPayCommissions ? Icons.payments_rounded : Icons.print_rounded, size: 18),
                          label: Text(
                            _filteredCommissions.isEmpty
                                ? 'Sin comisiones en este filtro'
                                : !_canPayCommissions
                                    ? 'Solo Imprimir • ${SettingsService.formatCurrency(_filteredCommissionsTotal)} • Sin permiso Pagar Comisiones'
                                    : _selectedBarberId == 'all'
                                    ? 'Pagar a Todos • ${SettingsService.formatCurrency(_filteredCommissionsTotal)} • ${_filteredCommissions.length} barberos'
                                    : 'Pagar a ${_filteredCommissions.first['barber_name']} • ${SettingsService.formatCurrency(_filteredCommissionsTotal)}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _canPayCommissions ? const Color(0xFFD4AF37) : const Color(0xFF10B981),
                            foregroundColor: Colors.black,
                            disabledBackgroundColor: Colors.white12,
                            disabledForegroundColor: Colors.white38,
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(_canPayCommissions ? 'Este botón SOLO paga. Para imprimir sin pagar usa el icono de ticket de arriba o Solo Imprimir.' : 'Sin permiso Pagar Comisiones en Roles: este botón solo abre Solo Imprimir. Pidele a Patricio que lo active si debe pagar.', style: const TextStyle(fontSize: 11, color: Colors.white38)),
                    ]),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(children: [
                      Expanded(child: _buildSummaryCard('Total Ventas', SettingsService.formatCurrency(_filteredSales), Icons.trending_up_rounded, const Color(0xFF38BDF8))),
                      const SizedBox(width: 12),
                      Expanded(child: _buildSummaryCard('Comisiones', SettingsService.formatCurrency(_filteredCommissionsTotal), Icons.payments_rounded, const Color(0xFF10B981))),
                    ]),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
                
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(children: [
                      const Icon(Icons.people_alt_rounded, color: Colors.white54, size: 18),
                      const SizedBox(width: 8),
                      const Text('Detalle por Barbero', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                    ]),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),

                _commissions.isEmpty
                    ? const SliverFillRemaining(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('💰', style: TextStyle(fontSize: 56)), SizedBox(height: 12), Text('No hay comisiones en este periodo', style: TextStyle(color: Colors.white54, fontSize: 14))])))
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (c, i) => _buildBarberCard(_filteredCommissions[i], i + 1),
                          childCount: _filteredCommissions.length,
                        ),
                      ),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
              ],
            ),
    );
  }
}