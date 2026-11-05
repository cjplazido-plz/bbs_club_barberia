import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../models/local_transaction.dart';
import '../services/settings_service.dart';

/// Servicio de impresión 80mm Premium + ESC/POS directo
/// - WEB (Vercel): imprime PDF 80mm que llena los 72.1mm imprimibles sin necesidad de 125%
/// - WINDOWS/ANDROID con impresora conectada: puede imprimir ESC/POS directo sin diálogo (sin necesidad de estar con la impresora para probar, genera bytes y los loguea)

class PrinterService {
  static pw.MemoryImage? _cachedLogo;
  static String _cachedLogoUrl = '';

  Future<pw.MemoryImage?> _getTicketLogo() async {
    String logoUrl = SettingsService.ticketLogoUrl.isNotEmpty ? SettingsService.ticketLogoUrl : SettingsService.shopLogoUrl;
    if (logoUrl.isEmpty) return null;
    if (_cachedLogo != null && _cachedLogoUrl == logoUrl) return _cachedLogo;
    try {
      final r = await http.get(Uri.parse(logoUrl));
      if (r.statusCode == 200) {
        _cachedLogo = pw.MemoryImage(r.bodyBytes);
        _cachedLogoUrl = logoUrl;
        return _cachedLogo;
      }
    } catch (_) {}
    return null;
  }

  // ✅ FORMATO QUE LLENA 80MM - 0 MARGEN LATERAL PARA QUE NO SE ENCOJA
  PdfPageFormat get _paper80Full => PdfPageFormat(
        80 * PdfPageFormat.mm,
        double.infinity,
        marginLeft: 2 * PdfPageFormat.mm,
        marginRight: 2 * PdfPageFormat.mm,
        marginTop: 3 * PdfPageFormat.mm,
        marginBottom: 3 * PdfPageFormat.mm,
      );

  // ============ WEB PDF 80MM ============
  Future<void> printTicket(LocalTransaction transaction) async {
    if (!kIsWeb) {
      // Si es app nativa Windows/Android, intenta ESC/POS directo
      final esc = await _buildEscPosBytesFromLocal(transaction);
      // Aquí iría el envío real a impresora USB/Network
      // Por ahora logueamos para probar sin impresora
      print('🧾 ESC/POS bytes generados: ${esc.length} bytes (listo para enviar a XPrinter)');
      // Igual mostramos PDF como fallback
    }
    final logo = await _getTicketLogo();
    final pdf = pw.Document();
    final cashierSafe = (transaction.cashierName ?? '').toString().trim();
    final barberSafe = transaction.items.isNotEmpty ? (transaction.items.first.barberName ?? '').toString() : '';

    pdf.addPage(pw.Page(
      pageFormat: _paper80Full,
      build: (ctx) => pw.Container(
        width: double.infinity,
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
          if (logo != null) pw.Container(width: 55 * PdfPageFormat.mm, height: 30 * PdfPageFormat.mm, child: pw.Image(logo, fit: pw.BoxFit.contain)),
          if (logo != null) pw.SizedBox(height: 3 * PdfPageFormat.mm),
          pw.Container(width: double.infinity, child: pw.Text(SettingsService.shopName.isNotEmpty ? SettingsService.shopName.toUpperCase() : 'BBS CLUB', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
          pw.SizedBox(height: 1 * PdfPageFormat.mm),
          if (SettingsService.ticketHeader.isNotEmpty) pw.Text(SettingsService.ticketHeader, style: const pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.center),
          if (SettingsService.shopAddress.isNotEmpty) pw.Text(SettingsService.shopAddress, style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.center),
          if (SettingsService.shopPhone.isNotEmpty) pw.Text('Tel: ${SettingsService.shopPhone}', style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.center),
          pw.SizedBox(height: 3 * PdfPageFormat.mm),
          pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
          pw.SizedBox(height: 2 * PdfPageFormat.mm),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Fecha:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)), pw.Text(DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()), style: const pw.TextStyle(fontSize: 10))]),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Cajero:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)), pw.Text(cashierSafe.isNotEmpty ? cashierSafe : 'Sistema', style: const pw.TextStyle(fontSize: 10))]),
          if (barberSafe.isNotEmpty) pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Barbero:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)), pw.Text(barberSafe, style: const pw.TextStyle(fontSize: 10))]),
          pw.SizedBox(height: 2 * PdfPageFormat.mm),
          pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
          pw.SizedBox(height: 2 * PdfPageFormat.mm),
          ...transaction.items.map((item) {
            final name = (item.serviceName.isNotEmpty ? item.serviceName : (item.productName ?? 'Item')).toString();
            final totalItem = item.priceAtMoment * item.quantity;
            return pw.Padding(padding: pw.EdgeInsets.only(bottom: 3 * PdfPageFormat.mm), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Container(width: double.infinity, child: pw.Text(name, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold))),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('${item.quantity} x ${SettingsService.formatCurrency(item.priceAtMoment)}', style: const pw.TextStyle(fontSize: 10)),
                pw.Text(SettingsService.formatCurrency(totalItem), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              ]),
            ]));
          }),
          pw.Divider(thickness: 1),
          pw.SizedBox(height: 2 * PdfPageFormat.mm),
          pw.Container(padding: pw.EdgeInsets.symmetric(vertical: 3 * PdfPageFormat.mm), decoration: pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 1), bottom: pw.BorderSide(width: 1))), child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('TOTAL:', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.Text(SettingsService.formatCurrency(transaction.total), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          ])),
          pw.SizedBox(height: 3 * PdfPageFormat.mm),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Pago:', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)), pw.Text(_fmtPay(transaction.paymentMethod), style: const pw.TextStyle(fontSize: 11))]),
          if (transaction.paymentMethod == 'cash') ...[
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Recibido:', style: const pw.TextStyle(fontSize: 10)), pw.Text(SettingsService.formatCurrency(transaction.cashReceived), style: const pw.TextStyle(fontSize: 10))]),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Vuelto:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)), pw.Text(SettingsService.formatCurrency(transaction.changeAmount), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold))]),
          ],
          pw.SizedBox(height: 6 * PdfPageFormat.mm),
          pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
          pw.SizedBox(height: 3 * PdfPageFormat.mm),
          if (SettingsService.ticketFooter.isNotEmpty) pw.Text(SettingsService.ticketFooter, style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic), textAlign: pw.TextAlign.center),
          pw.Text('¡Gracias por su visita!', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
        ]),
      ),
    ));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'Ticket_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf');
  }

  Future<void> printTicketFromMap(Map<String, dynamic> transaction, List<Map<String, dynamic>> items) async {
    final logo = await _getTicketLogo();
    final pdf = pw.Document();
    pdf.addPage(pw.Page(
      pageFormat: _paper80Full,
      build: (ctx) => pw.Container(
        width: double.infinity,
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
          if (logo != null) pw.Container(width: 55 * PdfPageFormat.mm, height: 30 * PdfPageFormat.mm, child: pw.Image(logo, fit: pw.BoxFit.contain)),
          if (logo != null) pw.SizedBox(height: 3 * PdfPageFormat.mm),
          pw.Text(SettingsService.shopName.isNotEmpty ? SettingsService.shopName.toUpperCase() : 'BBS CLUB', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
          if (SettingsService.shopAddress.isNotEmpty) pw.Text(SettingsService.shopAddress, style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.center),
          if (SettingsService.shopPhone.isNotEmpty) pw.Text('Tel: ${SettingsService.shopPhone}', style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.center),
          pw.SizedBox(height: 3 * PdfPageFormat.mm),
          pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
          pw.SizedBox(height: 2 * PdfPageFormat.mm),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Fecha:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)), pw.Text(DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(transaction['created_at'] as String)), style: const pw.TextStyle(fontSize: 10))]),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Cajero:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)), pw.Text((transaction['cashier_name'] ?? 'N/A').toString(), style: const pw.TextStyle(fontSize: 10))]),
          if (transaction['barber_name'] != null && (transaction['barber_name'] as String).isNotEmpty) pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Barbero:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)), pw.Text(transaction['barber_name'] as String, style: const pw.TextStyle(fontSize: 10))]),
          pw.SizedBox(height: 2 * PdfPageFormat.mm),
          pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
          pw.SizedBox(height: 2 * PdfPageFormat.mm),
          ...items.map((it) {
            final name = (it['service_name'] ?? it['product_name'] ?? 'Item').toString();
            final qty = it['quantity'] as int;
            final price = (it['price_at_moment'] as num).toDouble();
            return pw.Padding(padding: pw.EdgeInsets.only(bottom: 3 * PdfPageFormat.mm), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(name, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('$qty x ${SettingsService.formatCurrency(price)}', style: const pw.TextStyle(fontSize: 10)), pw.Text(SettingsService.formatCurrency(price * qty), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold))]),
            ]));
          }),
          pw.Divider(thickness: 1),
          pw.Container(padding: pw.EdgeInsets.symmetric(vertical: 3 * PdfPageFormat.mm), decoration: pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 1), bottom: pw.BorderSide(width: 1))), child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('TOTAL:', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.Text(SettingsService.formatCurrency((transaction['total'] as num).toDouble()), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          ])),
          pw.SizedBox(height: 3 * PdfPageFormat.mm),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Pago:', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)), pw.Text(_fmtPay(transaction['payment_method']?.toString() ?? 'cash'), style: const pw.TextStyle(fontSize: 11))]),
          pw.SizedBox(height: 6 * PdfPageFormat.mm),
          pw.Text('¡Gracias por su visita! (Reimpresión)', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
        ]),
      ),
    ));
    await Printing.layoutPdf(onLayout: (f) async => pdf.save(), name: 'Ticket_Reimp_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf');
  }

  // ============ ESC/POS DIRECTO (sin diálogo) - funciona aunque no tengas impresora para probar ============
  Future<Uint8List> _buildEscPosBytesFromLocal(LocalTransaction tr) async {
    // ESC/POS manual sin librerías externas (compatible con XPrinter 80mm)
    List<int> bytes = [];
    bytes += [0x1B, 0x40]; // INIT
    bytes += [0x1B, 0x61, 0x01]; // CENTER
    bytes += _textEsc('BBS CLUB\n', bold: true, doubleHeight: true);
    bytes += _textEsc('${SettingsService.shopName}\n');
    if (SettingsService.shopAddress.isNotEmpty) bytes += _textEsc('${SettingsService.shopAddress}\n');
    if (SettingsService.shopPhone.isNotEmpty) bytes += _textEsc('Tel: ${SettingsService.shopPhone}\n');
    bytes += _textEsc('--------------------------------\n');
    bytes += [0x1B, 0x61, 0x00]; // LEFT
    bytes += _textEsc('Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}\n');
    bytes += _textEsc('Cajero: ${(tr.cashierName ?? 'Sistema').toString()}\n');
    if (tr.items.isNotEmpty && (tr.items.first.barberName ?? '').toString().isNotEmpty) bytes += _textEsc('Barbero: ${tr.items.first.barberName}\n');
    bytes += _textEsc('--------------------------------\n');
    for (var it in tr.items) {
      final name = (it.serviceName.isNotEmpty ? it.serviceName : (it.productName ?? 'Item')).toString();
      bytes += _textEsc('$name\n', bold: true);
      bytes += _textEsc('  ${it.quantity} x ${SettingsService.formatCurrency(it.priceAtMoment)} = ${SettingsService.formatCurrency(it.priceAtMoment * it.quantity)}\n');
    }
    bytes += _textEsc('--------------------------------\n');
    bytes += _textEsc('TOTAL: ${SettingsService.formatCurrency(tr.total)}\n', bold: true, doubleHeight: true);
    bytes += _textEsc('Pago: ${_fmtPay(tr.paymentMethod)}\n');
    if (tr.paymentMethod == 'cash') {
      bytes += _textEsc('Recibido: ${SettingsService.formatCurrency(tr.cashReceived)}\n');
      bytes += _textEsc('Vuelto: ${SettingsService.formatCurrency(tr.changeAmount)}\n', bold: true);
    }
    bytes += _textEsc('--------------------------------\n');
    bytes += [0x1B, 0x61, 0x01];
    if (SettingsService.ticketFooter.isNotEmpty) bytes += _textEsc('${SettingsService.ticketFooter}\n');
    bytes += _textEsc('¡Gracias por su visita!\n', bold: true);
    bytes += [0x0A, 0x0A, 0x0A];
    bytes += [0x1D, 0x56, 0x41, 0x00]; // CUT
    return Uint8List.fromList(bytes);
  }

  List<int> _textEsc(String text, {bool bold = false, bool doubleHeight = false}) {
    List<int> b = [];
    if (bold) b += [0x1B, 0x45, 0x01]; else b += [0x1B, 0x45, 0x00];
    if (doubleHeight) b += [0x1D, 0x21, 0x11]; else b += [0x1D, 0x21, 0x00];
    b += text.codeUnits;
    b += [0x1B, 0x45, 0x00, 0x1D, 0x21, 0x00];
    return b;
  }

  String _fmtPay(String m) {
    switch (m) { case 'cash': return 'Efectivo'; case 'card': return 'Tarjeta'; case 'transfer': return 'Transferencia'; default: return m; }
  }
}
