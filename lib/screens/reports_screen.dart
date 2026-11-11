import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../services/settings_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../main.dart'; // IMPORTANTE: Para leer currentUserRole
import '../services/role_permissions.dart'; // IMPORTANTE: Para aplicar permisos

class ReportsScreen extends StatefulWidget {
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  double _dayTotal = 0.0;
  int _dayTransactions = 0;
  Map<String, double> _barberTotals = {};
  Map<String, int> _paymentMethods = {};
  Map<String, double> _paymentAmounts = {};
  Map<String, double> _mixedBreakdown = {};
  List<Map<String, dynamic>> _transactions = [];
  double _totalChange = 0;
  double _totalCashReceived = 0;
  double _totalCommissionsDay = 0;
  bool _isLoading = true;
  double _fondoInicial = 0;
  double _gastosDia = 0;
  double _salidaEfectivo = 0;
  double _ajusteDiferencia = 0;
  List<Map<String, dynamic>> _movimientos = [];
  int _anuladasCount = 0;
  double _anuladasTotal = 0;
  double get _entradasEfectivo => _movimientos.where((m) => m['tipo'] == 'entrada' && m['metodo'] == 'cash' && (m['afecta_caja'] == true)).fold(0.0, (s, m) => s + ((m['monto'] as num).toDouble()));
  double get _salidasMovimientosEfectivo => _movimientos.where((m) => m['tipo'] == 'salida' && m['metodo'] == 'cash' && (m['afecta_caja'] == true)).fold(0.0, (s, m) => s + ((m['monto'] as num).toDouble()));
  double _efectivoContado = 0;
  double get _cashAmount => _paymentAmounts['cash'] ?? 0;
  double get _cardAmount => _paymentAmounts['card'] ?? 0;
  double get _transferAmount => _paymentAmounts['transfer'] ?? 0;
  double get _mixedAmount => _paymentAmounts['mixed'] ?? 0;
  double get _mixedCash => _mixedBreakdown['cash'] ?? 0;
  double get _efectivoEsperado => _fondoInicial + _cashAmount + _mixedCash + _entradasEfectivo - _totalChange - _gastosDia - _salidaEfectivo - _salidasMovimientosEfectivo;
  double get _diferencia => _efectivoContado - _efectivoEsperado;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() { _isLoading = true; });
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    try {
      final response = await Supabase.instance.client.from('transactions').select('*, transaction_items(*)').gte('created_at', startOfDay.toIso8601String()).lt('created_at', endOfDay.toIso8601String());
      final transactions = List<Map<String, dynamic>>.from(response);
      double total = 0.0;
      Map<String, double> barberTotals = {};
      Map<String, int> paymentMethods = {};
      Map<String, double> paymentAmounts = {};
      double totalChange = 0;
      double totalCashReceived = 0;
      double totalCommissions = 0;
      int anuladasCount = 0;
      double anuladasTotal = 0;
      for (final t in transactions) {
        final status = (t['status'] ?? t['estado'] ?? 'completed').toString().toLowerCase();
        if (status == 'anulada' || status == 'anulado' || status == 'cancelled' || status == 'cancelada' || status == 'void') {
          anuladasCount++;
          anuladasTotal += (t['total'] as num?)?.toDouble() ?? 0.0;
          continue;
        }
        final tTotal = (t['total'] as num?)?.toDouble() ?? 0.0;
        total += tTotal;
        totalChange += (t['change_amount'] as num?)?.toDouble() ?? 0.0;
        totalCashReceived += (t['cash_received'] as num?)?.toDouble() ?? 0.0;
        final items = List<Map<String, dynamic>>.from(t['transaction_items'] ?? []);
        for (final item in items) {
          if (item['item_type'] == 'service') {
            final barberName = item['barber_name'] ?? '';
            if (barberName.isNotEmpty) {
              barberTotals[barberName] = (barberTotals[barberName] ?? 0) + ((item['price_at_moment'] as num).toDouble() * (item['quantity'] as int));
            }
          }
          totalCommissions += (item['commission_earned'] as num?)?.toDouble() ?? 0.0;
        }
        final method = (t['payment_method'] ?? 'cash').toString();
        paymentMethods[method] = (paymentMethods[method] ?? 0) + 1;
        paymentAmounts[method] = (paymentAmounts[method] ?? 0) + tTotal;
      }
      Map<String, double> mixedBreakdown = {};
      try {
        final mixedIds = transactions.where((t) => (t['payment_method'] ?? '') == 'mixed').map((t) => t['id']).where((id) => id != null).toList();
        if (mixedIds.isNotEmpty) {
          final payRes = await Supabase.instance.client.from('transaction_payments').select('payment_method, amount').inFilter('transaction_id', mixedIds);
          for (final p in List<Map<String, dynamic>>.from(payRes)) {
            final m = (p['payment_method'] ?? '').toString();
            mixedBreakdown[m] = (mixedBreakdown[m] ?? 0) + ((p['amount'] as num?)?.toDouble() ?? 0);
          }
        }
      } catch (_) {}
      try {
        final movRes = await Supabase.instance.client.from('cash_movements').select('*').gte('created_at', startOfDay.toIso8601String()).lt('created_at', endOfDay.toIso8601String()).order('created_at');
        final loaded = List<Map<String, dynamic>>.from(movRes).map((m) => {
          'tipo': (m['tipo'] ?? m['type'] ?? 'salida').toString(),
          'categoria': (m['categoria'] ?? m['category'] ?? 'Otros').toString(),
          'monto': ((m['monto'] ?? m['amount'] ?? 0) as num).toDouble(),
          'metodo': (m['metodo'] ?? m['payment_method'] ?? 'cash').toString(),
          'folio': (m['folio'] ?? m['referencia'] ?? '').toString(),
          'motivo': (m['motivo'] ?? m['motivo'] ?? '').toString(),
          'afecta_caja': (m['afecta_caja'] ?? true) as bool,
          'fecha': m['created_at'],
        }).toList();
        if (loaded.isNotEmpty && _movimientos.isEmpty) _movimientos = loaded;
      } catch (_) {}
      setState(() {
        _anuladasCount = anuladasCount;
        _anuladasTotal = anuladasTotal;
        _dayTotal = total;
        _dayTransactions = transactions.length;
        _barberTotals = barberTotals;
        _paymentMethods = paymentMethods;
        _paymentAmounts = paymentAmounts;
        _mixedBreakdown = mixedBreakdown;
        _transactions = transactions;
        _totalChange = totalChange;
        _totalCashReceived = totalCashReceived;
        _totalCommissionsDay = totalCommissions;
        _isLoading = false;
      });
    } catch (e) {
      print('Error reportes: $e');
      setState(() { _isLoading = false; });
    }
  }

  String _formatPaymentMethod(String method) {
    switch (method) { case 'cash': return 'Efectivo'; case 'card': return 'Tarjeta'; case 'transfer': return 'Transferencia'; case 'mixed': return 'Mixto'; default: return method; }
  }
  String _iconForMethod(String m) => m == 'cash' ? '💵' : m == 'card' ? '💳' : m == 'transfer' ? '🔁' : m == 'mixed' ? '🧾' : '💳';

  String _shortFolio(String folio) { if (folio.isEmpty) return ''; var s = folio.replaceAll('Venta #', '').replaceAll('Venta ', '').replaceAll('-', ''); if (s.startsWith('V')) s = s.substring(1); if (s.length > 6) s = s.substring(s.length - 6); return 'Venta #V-$s'; }
  String _shortId(dynamic id) { final s = (id ?? '').toString(); if (s.isEmpty) return ''; return s.length > 8 ? s.substring(0, 8) : s; }
  
  Future<void> _registrarMovimiento({required String tipo, required String categoria, required double monto, required String metodo, String folio = '', String motivo = '', bool afectaCaja = true}) async {
    final mov = {'tipo': tipo, 'categoria': categoria, 'monto': monto, 'metodo': metodo, 'folio': folio, 'motivo': motivo, 'afecta_caja': afectaCaja, 'fecha': DateTime.now().toIso8601String()};
    setState(() => _movimientos.add(mov));
    try {
      await Supabase.instance.client.from('cash_movements').insert({'tipo': tipo, 'categoria': categoria, 'monto': monto, 'metodo': metodo, 'folio': folio, 'motivo': motivo, 'afecta_caja': afectaCaja, 'created_at': DateTime.now().toIso8601String()});
    } catch (_) { }
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${tipo == 'entrada' ? 'Entrada' : 'Salida'} registrada: $categoria ${SettingsService.formatCurrency(monto)} (${_formatPaymentMethod(metodo)})'), backgroundColor: tipo == 'entrada' ? const Color(0xFF10B981) : Colors.red));
  }

  void _showMovimientoDialog(String tipo) {
    String categoria = tipo == 'entrada' ? 'Abono Reserva' : 'Gasto';
    String metodo = 'cash';
    final montoCtrl = TextEditingController();
    final folioCtrl = TextEditingController();
    final motivoCtrl = TextEditingController();
    final catsEntrada = ['Abono Reserva', 'Venta Contado', 'Ajuste +', 'Otros Ingresos'];
    final catsSalida = ['Gasto', 'Retiro Dueño', 'Anulación Venta', 'Devolución Reserva', 'Cambio de Pago', 'Ajuste -', 'Otros Egresos'];
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx2, setSt) {
      final cats = tipo == 'entrada' ? catsEntrada : catsSalida;
      return AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(tipo == 'entrada' ? '➕ Entrada de Caja' : '➖ Salida de Caja', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(value: categoria, dropdownColor: const Color(0xFF1E293B), style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Categoría', labelStyle: TextStyle(color: Colors.white54)), items: cats.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(), onChanged: (v) => setSt(() => categoria = v ?? categoria)),
          const SizedBox(height: 10),
          TextField(controller: montoCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Monto', labelStyle: TextStyle(color: Colors.white54), prefixText: '\$ ', prefixStyle: TextStyle(color: Colors.white54))),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(value: metodo, dropdownColor: const Color(0xFF1E293B), style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Método', labelStyle: TextStyle(color: Colors.white54)), items: const [DropdownMenuItem(value: 'cash', child: Text('Efectivo')), DropdownMenuItem(value: 'transfer', child: Text('Transferencia')), DropdownMenuItem(value: 'card', child: Text('Tarjeta'))], onChanged: (v) => setSt(() => metodo = v ?? 'cash')),
          const SizedBox(height: 10),
          TextField(controller: folioCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Folio / Referencia (ej: Reserva #12, Venta #101)', labelStyle: TextStyle(color: Colors.white54))),
          const SizedBox(height: 10),
          TextField(controller: motivoCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Motivo / Detalle', labelStyle: TextStyle(color: Colors.white54))),
          const SizedBox(height: 8),
          Text(tipo == 'entrada' ? 'Entradas en efectivo SUMAN a caja esperada.' : 'Salidas en efectivo RESTAN de caja esperada. Si es Gasto/Retiro, también puedes usar los campos de Cuadratura, no dupliques.', style: const TextStyle(color: Colors.white54, fontSize: 10)),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))), ElevatedButton(onPressed: () { final m = double.tryParse(montoCtrl.text) ?? 0; if (m <= 0) return; Navigator.pop(ctx); _registrarMovimiento(tipo: tipo, categoria: categoria, monto: m, metodo: metodo, folio: folioCtrl.text.trim(), motivo: motivoCtrl.text.trim(), afectaCaja: true); }, style: ElevatedButton.styleFrom(backgroundColor: tipo == 'entrada' ? const Color(0xFF10B981) : Colors.red), child: Text(tipo == 'entrada' ? 'Registrar Entrada' : 'Registrar Salida'))],
      );
    }));
  }

  void _showAnularVenta() {
    if (_transactions.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No hay ventas hoy para anular'), backgroundColor: Colors.orange)); return; }
    Map<String, dynamic>? selected = _transactions.first;
    final motivoCtrl = TextEditingController(text: 'Anulación solicitada por cliente');
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx2, setSt) => AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: const Text('🚫 Anular Venta', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<Map<String, dynamic>>(value: selected, dropdownColor: const Color(0xFF1E293B), style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Venta a anular', labelStyle: TextStyle(color: Colors.white54)), items: _transactions.map((t) => DropdownMenuItem(value: t, child: Text('Venta #${_shortId(t['id']) ?? ''}  -  ${SettingsService.formatCurrency((t['total'] as num?)?.toDouble() ?? 0)}  -  ${_formatPaymentMethod((t['payment_method'] ?? 'cash').toString())}'))).toList(), onChanged: (v) => setSt(() => selected = v)),
        const SizedBox(height: 10),
        TextField(controller: motivoCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Motivo anulación', labelStyle: TextStyle(color: Colors.white54))),
        const SizedBox(height: 8),
        Text('Al anular, la venta NO contará en Total del Día ni en caja (se excluye). Queda registrada como movimiento INFORMATIVO, no se vuelve a restar.', style: const TextStyle(color: Colors.white54, fontSize: 10)),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))), ElevatedButton(onPressed: () async { if (selected == null) return; final t = selected!; final total = (t['total'] as num?)?.toDouble() ?? 0; final metodo = (t['payment_method'] ?? 'cash').toString(); Navigator.pop(ctx); try { await Supabase.instance.client.from('transactions').update({'status': 'anulada'}).eq('id', t['id']); } catch (_) {} await _registrarMovimiento(tipo: 'salida', categoria: 'Anulación Venta', monto: total, metodo: metodo, folio: 'Venta #${t['id']}', motivo: motivoCtrl.text.trim(), afectaCaja: false); _loadReports(); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Anular Venta'))],
    )));
  }

  void _showCambiarPago() {
    if (_transactions.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No hay ventas hoy para cambiar pago'), backgroundColor: Colors.orange)); return; }
    Map<String, dynamic>? selected = _transactions.first;
    String nuevoMetodo = 'transfer';
    final motivoCtrl = TextEditingController(text: 'Cliente pidió cambiar forma de pago');
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx2, setSt) => AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: const Text('🔁 Cambiar Forma de Pago', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<Map<String, dynamic>>(value: selected, dropdownColor: const Color(0xFF1E293B), style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Venta', labelStyle: TextStyle(color: Colors.white54)), items: _transactions.map((t) => DropdownMenuItem(value: t, child: Text('Venta #${_shortId(t['id']) ?? ''}  -  ${SettingsService.formatCurrency((t['total'] as num?)?.toDouble() ?? 0)}  -  ${_formatPaymentMethod((t['payment_method'] ?? 'cash').toString())}'))).toList(), onChanged: (v) => setSt(() => selected = v)),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(value: nuevoMetodo, dropdownColor: const Color(0xFF1E293B), style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Nuevo método', labelStyle: TextStyle(color: Colors.white54)), items: const [DropdownMenuItem(value: 'cash', child: Text('Efectivo')), DropdownMenuItem(value: 'transfer', child: Text('Transferencia')), DropdownMenuItem(value: 'card', child: Text('Tarjeta')), DropdownMenuItem(value: 'mixed', child: Text('Mixto'))], onChanged: (v) => setSt(() => nuevoMetodo = v ?? 'transfer')),
        const SizedBox(height: 10),
        TextField(controller: motivoCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Motivo', labelStyle: TextStyle(color: Colors.white54))),
        const SizedBox(height: 8),
        Text('Se actualiza la venta y queda registro: Salida del método viejo + Entrada del nuevo (INFORMATIVO, no duplica en caja porque la venta ya cambió).', style: const TextStyle(color: Colors.white54, fontSize: 10)),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))), ElevatedButton(onPressed: () async { if (selected == null) return; final t = selected!; final total = (t['total'] as num?)?.toDouble() ?? 0; final viejo = (t['payment_method'] ?? 'cash').toString(); if (viejo == nuevoMetodo) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Es el mismo método'), backgroundColor: Colors.orange)); return; } Navigator.pop(ctx); try { await Supabase.instance.client.from('transactions').update({'payment_method': nuevoMetodo}).eq('id', t['id']); } catch (_) {} await _registrarMovimiento(tipo: 'salida', categoria: 'Cambio de Pago', monto: total, metodo: viejo, folio: 'Venta #${t['id']} ${_formatPaymentMethod(viejo)} → ${_formatPaymentMethod(nuevoMetodo)}', motivo: motivoCtrl.text.trim(), afectaCaja: false); await _registrarMovimiento(tipo: 'entrada', categoria: 'Cambio de Pago', monto: total, metodo: nuevoMetodo, folio: 'Venta #${t['id']}', motivo: motivoCtrl.text.trim(), afectaCaja: false); _loadReports(); }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)), child: const Text('Cambiar Pago'))],
    )));
  }

  void _showDevolverReserva() {
    final clienteCtrl = TextEditingController();
    final folioCtrl = TextEditingController();
    final montoCtrl = TextEditingController();
    final motivoCtrl = TextEditingController(text: 'Reserva cancelada por cliente');
    String metodo = 'cash';
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx2, setSt) => AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: const Text('↩️ Devolver Reserva Pagada / Abonada', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: clienteCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Cliente / Reserva', labelStyle: TextStyle(color: Colors.white54))),
        const SizedBox(height: 10),
        TextField(controller: folioCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Folio Reserva', labelStyle: TextStyle(color: Colors.white54))),
        const SizedBox(height: 10),
        TextField(controller: montoCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Monto a devolver (abono o total)', labelStyle: TextStyle(color: Colors.white54), prefixText: '\$ ')),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(value: metodo, dropdownColor: const Color(0xFF1E293B), style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Método de devolución', labelStyle: TextStyle(color: Colors.white54)), items: const [DropdownMenuItem(value: 'cash', child: Text('Efectivo - sale de caja')), DropdownMenuItem(value: 'transfer', child: Text('Transferencia')), DropdownMenuItem(value: 'card', child: Text('Tarjeta'))], onChanged: (v) => setSt(() => metodo = v ?? 'cash')),
        const SizedBox(height: 10),
        TextField(controller: motivoCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Motivo', labelStyle: TextStyle(color: Colors.white54))),
        const SizedBox(height: 8),
        Text('Esta devolución SI afecta caja: si es en Efectivo, resta de Efectivo Esperado. La reserva era pagada con anticipación (no es venta de hoy), por eso no se descuenta dos veces.', style: const TextStyle(color: Colors.white54, fontSize: 10)),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))), ElevatedButton(onPressed: () { final m = double.tryParse(montoCtrl.text) ?? 0; if (m <= 0) return; Navigator.pop(ctx); _registrarMovimiento(tipo: 'salida', categoria: 'Devolución Reserva', monto: m, metodo: metodo, folio: folioCtrl.text.trim().isNotEmpty ? folioCtrl.text.trim() : clienteCtrl.text.trim(), motivo: motivoCtrl.text.trim(), afectaCaja: true); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Devolver'))],
    )));
  }

  void _showCuadraturaDialog() {
    final fondoCtrl = TextEditingController(text: _fondoInicial.toStringAsFixed(0));
    final gastosCtrl = TextEditingController(text: _gastosDia.toStringAsFixed(0));
    final salidaCtrl = TextEditingController(text: _salidaEfectivo.toStringAsFixed(0));
    final contadoCtrl = TextEditingController(text: _efectivoContado.toStringAsFixed(0));
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx2, setSt) {
      void recalc() {
        _fondoInicial = double.tryParse(fondoCtrl.text) ?? 0;
        _gastosDia = double.tryParse(gastosCtrl.text) ?? 0;
        _salidaEfectivo = double.tryParse(salidaCtrl.text) ?? 0;
        _efectivoContado = double.tryParse(contadoCtrl.text) ?? 0;
        setSt(() {});
        setState(() {});
      }
      final folio = 'CAJA-${DateFormat('yyyyMMdd').format(DateTime.now())}';
      return Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Container(
          width: 380,
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(children: [
              Text((SettingsService.shopName.isNotEmpty ? SettingsService.shopName : 'BBS CLUB').toUpperCase(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
              const Text('CUADRATURA DE CAJA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.black54)),
              Text('Resumen del dia - ${DateFormat('dd/MM/yyyy').format(DateTime.now())}', style: const TextStyle(fontSize: 10, color: Colors.black54)),
              const SizedBox(height: 10),
              const Divider(color: Colors.black26, height: 1),
              const SizedBox(height: 10),
              _cuadRow('Folio:', folio, bold: true),
              _cuadRow('Fecha:', DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())),
              _cuadRow('Ventas del día:', '$_dayTransactions ventas'),
              _cuadRow('Total del día:', SettingsService.formatCurrency(_dayTotal), bold: true),
              if (_anuladasCount > 0) _cuadRow('Anuladas (no cuentan):', '$_anuladasCount ventas - ${SettingsService.formatCurrency(_anuladasTotal)}'),
              if (_movimientos.isNotEmpty) ...[
                const SizedBox(height: 6),
                const Align(alignment: Alignment.centerLeft, child: Text('MOVIMIENTOS DE CAJA HOY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54))),
                ..._movimientos.map((m) => _buildMovimientoCuadRow(m)),
                _cuadRow('Entradas en efectivo (afectan caja):', SettingsService.formatCurrency(_entradasEfectivo)),
                _cuadRow('Salidas en efectivo (afectan caja):', SettingsService.formatCurrency(_salidasMovimientosEfectivo)),
              ],
              const SizedBox(height: 10),
              const Divider(color: Colors.black26, height: 1),
              const SizedBox(height: 6),
              const Align(alignment: Alignment.centerLeft, child: Text('POR MÉTODO DE PAGO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54))),
              const SizedBox(height: 4),
              ..._paymentAmounts.entries.map((e) => _cuadRow('${_formatPaymentMethod(e.key)} (${_paymentMethods[e.key] ?? 0} ventas):', SettingsService.formatCurrency(e.value))),
              if (_mixedBreakdown.isNotEmpty) ...[
                const SizedBox(height: 4),
                const Align(alignment: Alignment.centerLeft, child: Text('Desglose Mixto:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54))),
                ..._mixedBreakdown.entries.map((e) => _cuadRow('  Mixto - ${_formatPaymentMethod(e.key)}:', SettingsService.formatCurrency(e.value))),
              ],
              const SizedBox(height: 6),
              const Align(alignment: Alignment.centerLeft, child: Text('POR BARBERO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54))),
              const SizedBox(height: 4),
              ..._barberTotals.entries.map((e) => _cuadRow('${e.key}:', SettingsService.formatCurrency(e.value))),
              _cuadRow('Comisiones del día:', SettingsService.formatCurrency(_totalCommissionsDay)),
              _cuadRow('Vuelto entregado:', SettingsService.formatCurrency(_totalChange)),
              const SizedBox(height: 10),
              const Divider(color: Colors.black26, height: 1),
              const SizedBox(height: 6),
              const Align(alignment: Alignment.centerLeft, child: Text('CUADRATURA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54))),
              const SizedBox(height: 8),
              _cuadInput('Fondo inicial (caja):', fondoCtrl, recalc),
              _cuadInput('Gastos / retiros del día:', gastosCtrl, recalc),
              _cuadInput('Efectivo que SALE de caja (retiro / entrega / depósito):', salidaCtrl, recalc),
              _cuadInput('Efectivo contado en caja (físico que cuentas):', contadoCtrl, recalc, autofocus: true),
              const SizedBox(height: 6),
              if (_diferencia.abs() >= 0.5) SizedBox(width: double.infinity, child: ElevatedButton.icon(
                onPressed: () {
                  if (_diferencia > 0) {
                    final d = _diferencia;
                    _ajusteDiferencia += d;
                    _efectivoContado = _efectivoEsperado;
                    contadoCtrl.text = _efectivoContado.toStringAsFixed(0);
                    recalc();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sobrante ${SettingsService.formatCurrency(d)} sacado de caja. Ahora cuadra en 0.'), backgroundColor: const Color(0xFF10B981)));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Falta ${SettingsService.formatCurrency(_diferencia.abs())} - Revisa vuelto / gastos, no hay efectivo que sacar.'), backgroundColor: Colors.red));
                  }
                },
                icon: const Icon(Icons.north_east_rounded, size: 16, color: Colors.white),
                label: Text(_diferencia > 0 ? 'Sacar Sobrante ${SettingsService.formatCurrency(_diferencia)} de caja y dejar en 0' : 'Falta ${SettingsService.formatCurrency(_diferencia.abs())} - Revisar, no hay que sacar', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              )),
              const SizedBox(height: 8),
              Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12), decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8)), child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('EFECTIVO ESPERADO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)), Text(SettingsService.formatCurrency(_efectivoEsperado), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))]),
                const SizedBox(height: 4),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Diferencia (contado - esperado)', style: TextStyle(color: Colors.white70, fontSize: 10)), Text(SettingsService.formatCurrency(_diferencia), style: TextStyle(color: _diferencia.abs() < 0.5 ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13))]),
                const SizedBox(height: 2),
                Text(_diferencia.abs() < 0.5 ? '✓ CUADRA' : (_diferencia > 0 ? 'Sobra ${SettingsService.formatCurrency(_diferencia)}' : 'Falta ${SettingsService.formatCurrency(_diferencia.abs())}'), style: TextStyle(color: _diferencia.abs() < 0.5 ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 11)),
              ])),
              const SizedBox(height: 12),
              if (_ajusteDiferencia.abs() >= 0.5) _cuadRow('Sobrante sacado de caja (ajuste):', SettingsService.formatCurrency(_ajusteDiferencia)),
              Text('Cómo ingresar la diferencia: 1) Cuenta billetes y escribe en Efectivo contado. 2) Si SOBRA, escribe ese monto en Efectivo que SALE o pulsa el botón de arriba. 3) Si FALTA, revisa vuelto/gastos, no saques nada.', style: const TextStyle(fontSize: 9, color: Colors.black54), textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text('Fórmula: Fondo + Efectivo + Mixto-Efectivo - Vuelto - Gastos - Salida = Esperado', style: const TextStyle(fontSize: 8, color: Colors.black45), textAlign: TextAlign.center),
              const SizedBox(height: 14),
              Row(children: [const Expanded(child: Column(children: [Divider(color: Colors.black54), SizedBox(height: 4), Text('Firma Cajero', style: TextStyle(fontSize: 10, color: Colors.black54))])), const SizedBox(width: 16), const Expanded(child: Column(children: [Divider(color: Colors.black54), SizedBox(height: 4), Text('Firma Admin', style: TextStyle(fontSize: 10, color: Colors.black54))]))]),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar'))),
                const SizedBox(width: 10),
                Expanded(child: ElevatedButton.icon(onPressed: () { Navigator.pop(ctx); _printCuadratura(folio); }, icon: const Icon(Icons.print_rounded, size: 16), label: const Text('Imprimir', style: TextStyle(fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)))),
              ]),
            ]),
          ),
        ),
      );
    }));
  }

  Widget _cuadRow(String label, String value, {bool bold = false}) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54), overflow: TextOverflow.ellipsis, maxLines: 2)), const SizedBox(width: 8), Text(value, style: TextStyle(fontSize: 11, fontWeight: bold ? FontWeight.bold : FontWeight.w600, color: Colors.black), textAlign: TextAlign.right)]));
  }

  Widget _buildMovimientoCuadRow(Map<String, dynamic> m) {
    final tipo = (m["tipo"] ?? "").toString();
    final esEntrada = tipo == "entrada";
    final icono = esEntrada ? "➕" : "➖";
    final categoria = (m["categoria"] ?? "").toString();
    final folioRaw = (m["folio"] ?? "").toString();
    final folioCorto = folioRaw.isEmpty ? "" : _shortFolio(folioRaw);
    final metodoTxt = _formatPaymentMethod((m["metodo"] ?? "cash").toString());
    final afecta = m["afecta_caja"] == true;
    final monto = (m["monto"] as num?)?.toDouble() ?? 0;
    final signo = esEntrada ? "+" : "-";
    final titulo = "$icono $categoria $folioCorto".trim();
    final subtitulo = afecta ? metodoTxt : "$metodoTxt - Informativo";
    final montoTxt = "$signo${SettingsService.formatCurrency(monto)}";
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(titulo, style: const TextStyle(fontSize: 11, color: Colors.black54), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(subtitulo, style: const TextStyle(fontSize: 9, color: Colors.black45)),
        ])),
        const SizedBox(width: 8),
        Text(montoTxt, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black)),
      ]),
    );
  }


  Widget _cuadInput(String label, TextEditingController ctrl, VoidCallback onChanged, {bool autofocus = false}) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [Expanded(child: Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54))), const SizedBox(width: 8), SizedBox(width: 120, child: TextField(controller: ctrl, autofocus: autofocus, keyboardType: TextInputType.number, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black), decoration: InputDecoration(filled: true, fillColor: Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)), onChanged: (_) => onChanged()))]));
  }

  Future<void> _printCuadratura(String folio) async {
    final pdf = pw.Document();
    pdf.addPage(pw.Page(
      pageFormat: const PdfPageFormat(80 * PdfPageFormat.mm, double.infinity, marginLeft: 2 * PdfPageFormat.mm, marginRight: 2 * PdfPageFormat.mm, marginTop: 3 * PdfPageFormat.mm, marginBottom: 3 * PdfPageFormat.mm),
      build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
        pw.Text((SettingsService.shopName.isNotEmpty ? SettingsService.shopName : 'BBS CLUB').toUpperCase(), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
        pw.Text('CUADRATURA DE CAJA', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        pw.Text('Resumen del dia - ${DateFormat('dd/MM/yyyy').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 9)),
        pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Folio:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)), pw.Text(folio, style: const pw.TextStyle(fontSize: 9))]),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Fecha:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)), pw.Text(DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()), style: const pw.TextStyle(fontSize: 10))]),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Ventas:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)), pw.Text('$_dayTransactions ventas', style: const pw.TextStyle(fontSize: 10))]),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Total del día:', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)), pw.Text(SettingsService.formatCurrency(_dayTotal), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold))]),
        if (_anuladasCount > 0) pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Anuladas (no cuentan):', style: const pw.TextStyle(fontSize: 10)), pw.Text('$_anuladasCount - ${SettingsService.formatCurrency(_anuladasTotal)}', style: const pw.TextStyle(fontSize: 10))]),
        if (_movimientos.isNotEmpty) ...[
          pw.Text('MOVIMIENTOS DE CAJA', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          ..._movimientos.map((m) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('${m['tipo'] == 'entrada' ? '+' : '-'} ${m['categoria']} ${m['folio']}', style: const pw.TextStyle(fontSize: 9)), pw.Text(SettingsService.formatCurrency((m['monto'] as num).toDouble()), style: const pw.TextStyle(fontSize: 9))])),
        ],
        pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
        pw.Text('POR MÉTODO DE PAGO', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
        ..._paymentAmounts.entries.map((e) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('${_formatPaymentMethod(e.key)} (${_paymentMethods[e.key] ?? 0})', style: const pw.TextStyle(fontSize: 10)), pw.Text(SettingsService.formatCurrency(e.value), style: const pw.TextStyle(fontSize: 10))])),
        if (_mixedBreakdown.isNotEmpty) ...[
          pw.Text('Desglose Mixto:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          ..._mixedBreakdown.entries.map((e) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('  Mixto - ${_formatPaymentMethod(e.key)}', style: const pw.TextStyle(fontSize: 10)), pw.Text(SettingsService.formatCurrency(e.value), style: const pw.TextStyle(fontSize: 10))])),
        ],
        pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
        pw.Text('POR BARBERO', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
        ..._barberTotals.entries.map((e) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text(e.key, style: const pw.TextStyle(fontSize: 10)), pw.Text(SettingsService.formatCurrency(e.value), style: const pw.TextStyle(fontSize: 10))])),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Comisiones del día:', style: const pw.TextStyle(fontSize: 10)), pw.Text(SettingsService.formatCurrency(_totalCommissionsDay), style: const pw.TextStyle(fontSize: 10))]),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Vuelto:', style: const pw.TextStyle(fontSize: 10)), pw.Text(SettingsService.formatCurrency(_totalChange), style: const pw.TextStyle(fontSize: 10))]),
        pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
        pw.Text('CUADRATURA', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Fondo inicial:', style: const pw.TextStyle(fontSize: 10)), pw.Text(SettingsService.formatCurrency(_fondoInicial), style: const pw.TextStyle(fontSize: 10))]),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Gastos / retiros:', style: const pw.TextStyle(fontSize: 10)), pw.Text(SettingsService.formatCurrency(_gastosDia), style: const pw.TextStyle(fontSize: 10))]),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Efectivo que SALE (retiro/entrega):', style: const pw.TextStyle(fontSize: 10)), pw.Text(SettingsService.formatCurrency(_salidaEfectivo), style: const pw.TextStyle(fontSize: 10))]),
        if (_ajusteDiferencia.abs() >= 0.5) pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Sobrante sacado (ajuste):', style: const pw.TextStyle(fontSize: 10)), pw.Text(SettingsService.formatCurrency(_ajusteDiferencia), style: const pw.TextStyle(fontSize: 10))]),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Efectivo contado:', style: const pw.TextStyle(fontSize: 10)), pw.Text(SettingsService.formatCurrency(_efectivoContado), style: const pw.TextStyle(fontSize: 10))]),
        pw.SizedBox(height: 3 * PdfPageFormat.mm),
        pw.Container(padding: pw.EdgeInsets.symmetric(vertical: 3 * PdfPageFormat.mm, horizontal: 3 * PdfPageFormat.mm), decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)), child: pw.Column(children: [
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('EFECTIVO ESPERADO', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)), pw.Text(SettingsService.formatCurrency(_efectivoEsperado), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold))]),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Diferencia:', style: const pw.TextStyle(fontSize: 10)), pw.Text(SettingsService.formatCurrency(_diferencia), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold))]),
          pw.Text(_diferencia.abs() < 0.5 ? 'CUADRA' : (_diferencia > 0 ? 'Sobra' : 'Falta'), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        ])),
        pw.SizedBox(height: 6 * PdfPageFormat.mm),
        pw.Row(children: [pw.Expanded(child: pw.Column(children: [pw.Divider(), pw.Text('Firma Cajero', style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.center)])), pw.SizedBox(width: 4 * PdfPageFormat.mm), pw.Expanded(child: pw.Column(children: [pw.Divider(), pw.Text('Firma Admin', style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.center)]))]),
        pw.SizedBox(height: 3 * PdfPageFormat.mm),
        pw.Text('¡Gracias!', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
      ]),
    ));
    await Printing.layoutPdf(onLayout: (f) async => pdf.save(), name: 'Cuadratura-Caja-${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf');
  }

  @override
  Widget build(BuildContext context) {
    // PROTECCIÓN EXTRA: Si no tiene permisos de ver reportes, no dibuja nada
    if (!RolePermissions.isAdmin(currentUserRole) && !RolePermissions.can(currentUserRole, BbsPerm.viewReports)) {
      return const Scaffold(backgroundColor: Color(0xFF0F172A), body: Center(child: Text('No tienes permisos para ver esta sección', style: TextStyle(color: Colors.white))));
    }

    final transaccionesText = "${_dayTransactions}";
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: const Text('Reportes Premium', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [TextButton.icon(onPressed: _showCuadraturaDialog, icon: const Icon(Icons.print_rounded, size: 18, color: Colors.white), label: const Text('Cuadratura', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)), style: TextButton.styleFrom(backgroundColor: const Color(0xFF10B981), padding: const EdgeInsets.symmetric(horizontal: 10))), const SizedBox(width: 6), IconButton(icon: const Icon(Icons.sync_rounded, color: Colors.white), onPressed: _loadReports)],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: _SummaryCard(title: 'Total del dia', value: SettingsService.formatCurrency(_dayTotal), icon: '💵', color: const Color(0xFF10B981))),
                  const SizedBox(width: 12),
                  Expanded(child: _SummaryCard(title: 'Ventas', value: transaccionesText, icon: '💲', color: const Color(0xFF3B82F6))),
                ]),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Text('🧾 Cuadratura de Caja', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                      const Spacer(),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: Text(DateFormat('dd/MM/yyyy').format(DateTime.now()), style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold))),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Efectivo en caja (esperado)', style: TextStyle(fontSize: 10, color: Colors.white38)), const SizedBox(height: 2), Text(SettingsService.formatCurrency(_efectivoEsperado), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF10B981)))])),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [const Text('Efectivo + Mixto-Efectivo - Vuelto', style: TextStyle(fontSize: 10, color: Colors.white38)), const SizedBox(height: 2), Text('${SettingsService.formatCurrency(_cashAmount)} + ${SettingsService.formatCurrency(_mixedCash)} - ${SettingsService.formatCurrency(_totalChange)}', style: const TextStyle(fontSize: 11, color: Colors.white70))])),
                    ]),
                    const SizedBox(height: 12),
                    SizedBox(width: double.infinity, height: 44, child: ElevatedButton.icon(onPressed: _showCuadraturaDialog, icon: const Icon(Icons.print_rounded, size: 18), label: const Text('Ver e Imprimir Cuadratura del Día', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))))),
                  ]),
                ),
                const SizedBox(height: 24),
                const Text('Ventas por Barbero', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 12),
                if (_barberTotals.isEmpty)
                  Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white10)), child: const Text('No hay datos', style: TextStyle(color: Colors.white54)))
                else
                  ..._barberTotals.entries.map((entry) => Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withOpacity(0.05)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))]),
                        child: Material(
                          type: MaterialType.transparency,
                          child: ListTile(
                            leading: CircleAvatar(backgroundColor: const Color(0xFF6366F1).withOpacity(0.15), child: Text(entry.key.isNotEmpty ? entry.key[0].toUpperCase() : '?', style: const TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold))),
                            title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 14)),
                            trailing: Text(SettingsService.formatCurrency(entry.value), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                          ),
                        ),
                      )),
                const SizedBox(height: 24),
                const Text('Movimientos de Caja  -  Entradas / Salidas', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 8),
                Text('Universo bajo: cada anulación, cambio de pago o devolución de reserva queda con folio y motivo. Solo Devolución / Gasto / Retiro / Abono afectan caja; Anulación y Cambio de Pago son informativos porque la venta ya cambió.', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  ElevatedButton.icon(onPressed: () => _showMovimientoDialog('entrada'), icon: const Icon(Icons.add_rounded, size: 16), label: const Text('➕ Entrada', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981))),
                  ElevatedButton.icon(onPressed: () => _showMovimientoDialog('salida'), icon: const Icon(Icons.remove_rounded, size: 16), label: const Text('➖ Salida', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: Colors.red)),
                  OutlinedButton.icon(onPressed: _showDevolverReserva, icon: const Text('↩️', style: TextStyle(fontSize: 14)), label: const Text('Devolver Reserva', style: TextStyle(color: Colors.white, fontSize: 12)), style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white24))),
                ]),
                const SizedBox(height: 8),
                Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.12), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3))), child: const Row(children: [Text('ℹ️', style: TextStyle(fontSize: 14)), SizedBox(width: 8), Expanded(child: Text('Anular y Cambiar Pago se hacen desde Historial > Detalle de Venta > Editar Pago / Anular (como en tu captura). Esos botones ya dejan el movimiento en Cuadratura, aquí no se duplican.', style: TextStyle(color: Colors.white70, fontSize: 11)))])),
                const SizedBox(height: 10),
                if (_movimientos.isEmpty) Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12)), child: const Text('Sin movimientos hoy. Usa Entrada / Salida o los botones de Anular / Cambiar / Devolver.', style: TextStyle(color: Colors.white54, fontSize: 12)))
                else ..._movimientos.map((m) => Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.05))), child: Row(children: [Text(m['tipo'] == 'entrada' ? '➕' : '➖', style: const TextStyle(fontSize: 16)), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${m['categoria']} ${m['folio'] != '' ? '• ${m['folio']}' : ''}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)), Text('${_formatPaymentMethod(m['metodo'])} - ${m['motivo']}${(m['afecta_caja'] == true) ? '' : ' - Informativo'}', style: const TextStyle(color: Colors.white54, fontSize: 11))])), Text('${m['tipo'] == 'entrada' ? '+' : '-'}${SettingsService.formatCurrency((m['monto'] as num).toDouble())}', style: TextStyle(color: m['tipo'] == 'entrada' ? const Color(0xFF10B981) : Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold))]))) ,
                if (_anuladasCount > 0) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Anuladas hoy: $_anuladasCount - ${SettingsService.formatCurrency(_anuladasTotal)} (no cuentan en Total)', style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold))),
                const SizedBox(height: 24),
                const Text('Metodos de Pago', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 12),
                if (_paymentMethods.isEmpty)
                  Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white10)), child: const Text('No hay datos', style: TextStyle(color: Colors.white54)))
                else
                  ..._paymentMethods.entries.map((entry) {
                        final countText = "${entry.value} ventas";
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withOpacity(0.05))),
                          child: Material(
                            type: MaterialType.transparency,
                            child: ListTile(
                              leading: Text(_iconForMethod(entry.key), style: const TextStyle(fontSize: 22)),
                              title: Text(_formatPaymentMethod(entry.key), style: const TextStyle(color: Colors.white, fontSize: 14)),
                              subtitle: Text(SettingsService.formatCurrency(_paymentAmounts[entry.key] ?? 0), style: const TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold)),
                              trailing: Text(countText, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white70)),
                            ),
                          ),
                        );
                      }),
              ]),
            ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final String icon;
  final Color color;
  const _SummaryCard({required this.title, required this.value, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withOpacity(0.05)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))]),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: Text(icon, style: const TextStyle(fontSize: 18))), const Spacer(), Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle))]),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(color: Colors.white54, fontSize: 11)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        ]),
      ),
    );
  }
}