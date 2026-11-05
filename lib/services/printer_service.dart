import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../models/local_transaction.dart';
import '../services/settings_service.dart';

class PrinterService {
  static pw.MemoryImage? _cachedLogo;
  static String _cachedLogoUrl = '';

  Future<pw.MemoryImage?> _getTicketLogo() async {
    String logoUrl = SettingsService.ticketLogoUrl.isNotEmpty ? SettingsService.ticketLogoUrl : SettingsService.shopLogoUrl;
    if (logoUrl.isEmpty) return null;
    if (_cachedLogo != null && _cachedLogoUrl == logoUrl) return _cachedLogo;
    try {
      final response = await http.get(Uri.parse(logoUrl));
      if (response.statusCode == 200) {
        _cachedLogo = pw.MemoryImage(response.bodyBytes);
        _cachedLogoUrl = logoUrl;
        return _cachedLogo;
      }
    } catch (_) {}
    return null;
  }

  PdfPageFormat get _paper80mm => const PdfPageFormat(
        80 * PdfPageFormat.mm,
        double.infinity,
        marginLeft: 4 * PdfPageFormat.mm,
        marginRight: 4 * PdfPageFormat.mm,
        marginTop: 4 * PdfPageFormat.mm,
        marginBottom: 4 * PdfPageFormat.mm,
      );

  Future<void> printTicket(LocalTransaction transaction) async {
    final logo = await _getTicketLogo();
    final pdf = pw.Document();

    // Fix null safety
    final String cashierNameSafe = (transaction.cashierName ?? '').toString().trim();
    final String barberNameSafe = transaction.items.isNotEmpty ? (transaction.items.first.barberName ?? '').toString() : '';

    pdf.addPage(
      pw.Page(
        pageFormat: _paper80mm,
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (logo != null)
                pw.Container(width: 50 * PdfPageFormat.mm, height: 28 * PdfPageFormat.mm, child: pw.Image(logo, fit: pw.BoxFit.contain)),
              if (logo != null) pw.SizedBox(height: 4 * PdfPageFormat.mm),
              pw.Text(SettingsService.shopName.isNotEmpty ? SettingsService.shopName.toUpperCase() : 'BBS CLUB', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
              pw.SizedBox(height: 1 * PdfPageFormat.mm),
              if (SettingsService.ticketHeader.isNotEmpty) pw.Text(SettingsService.ticketHeader, style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.center),
              if (SettingsService.shopAddress.isNotEmpty) pw.Text(SettingsService.shopAddress, style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center),
              if (SettingsService.shopPhone.isNotEmpty) pw.Text('Tel: ${SettingsService.shopPhone}', style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center),
              pw.SizedBox(height: 3 * PdfPageFormat.mm),
              pw.Divider(thickness: 0.8, borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 2 * PdfPageFormat.mm),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('Fecha:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.Text(DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()), style: const pw.TextStyle(fontSize: 9)),
              ]),
              pw.SizedBox(height: 1 * PdfPageFormat.mm),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('Cajero:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.Text(cashierNameSafe.isNotEmpty ? cashierNameSafe : 'Sistema', style: const pw.TextStyle(fontSize: 9)),
              ]),
              if (barberNameSafe.isNotEmpty)
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text('Barbero:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  pw.Text(barberNameSafe, style: const pw.TextStyle(fontSize: 9)),
                ]),
              pw.SizedBox(height: 2 * PdfPageFormat.mm),
              pw.Divider(thickness: 0.8, borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 2 * PdfPageFormat.mm),
              ...transaction.items.map((item) {
                final name = (item.serviceName.isNotEmpty ? item.serviceName : (item.productName ?? 'Item')).toString();
                final totalItem = item.priceAtMoment * item.quantity;
                return pw.Padding(
                  padding: pw.EdgeInsets.only(bottom: 2.5 * PdfPageFormat.mm),
                  child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text(name, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold), maxLines: 2),
                    pw.SizedBox(height: 0.5 * PdfPageFormat.mm),
                    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                      pw.Text('${item.quantity} x ${SettingsService.formatCurrency(item.priceAtMoment)}', style: const pw.TextStyle(fontSize: 9)),
                      pw.Text(SettingsService.formatCurrency(totalItem), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    ]),
                  ]),
                );
              }),
              pw.Divider(thickness: 0.8),
              pw.SizedBox(height: 2 * PdfPageFormat.mm),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('Subtotal:', style: const pw.TextStyle(fontSize: 10)),
                pw.Text(SettingsService.formatCurrency(transaction.subtotal), style: const pw.TextStyle(fontSize: 10)),
              ]),
              pw.SizedBox(height: 2 * PdfPageFormat.mm),
              pw.Container(
                padding: pw.EdgeInsets.symmetric(vertical: 2 * PdfPageFormat.mm),
                decoration: pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 0.8), bottom: pw.BorderSide(width: 0.8))),
                child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text('TOTAL:', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.Text(SettingsService.formatCurrency(transaction.total), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                ]),
              ),
              pw.SizedBox(height: 3 * PdfPageFormat.mm),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('Pago:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                pw.Text(_formatPayment(transaction.paymentMethod), style: const pw.TextStyle(fontSize: 10)),
              ]),
              if (transaction.paymentMethod == 'cash') ...[
                pw.SizedBox(height: 1 * PdfPageFormat.mm),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text('Recibido:', style: const pw.TextStyle(fontSize: 9)),
                  pw.Text(SettingsService.formatCurrency(transaction.cashReceived), style: const pw.TextStyle(fontSize: 9)),
                ]),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text('Vuelto:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  pw.Text(SettingsService.formatCurrency(transaction.changeAmount), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ]),
              ],
              pw.SizedBox(height: 5 * PdfPageFormat.mm),
              pw.Divider(thickness: 0.8, borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 3 * PdfPageFormat.mm),
              if (SettingsService.ticketFooter.isNotEmpty) pw.Text(SettingsService.ticketFooter, style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic), textAlign: pw.TextAlign.center),
              pw.SizedBox(height: 1 * PdfPageFormat.mm),
              pw.Text('¡Gracias por su visita!', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
              pw.SizedBox(height: 2 * PdfPageFormat.mm),
              pw.Text('BBS Club Barbería - Coronel', style: const pw.TextStyle(fontSize: 7), textAlign: pw.TextAlign.center),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save(), name: 'Ticket_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf');
  }

  Future<void> printTicketFromMap(Map<String, dynamic> transaction, List<Map<String, dynamic>> items) async {
    final logo = await _getTicketLogo();
    final pdf = pw.Document();
    pdf.addPage(pw.Page(
      pageFormat: _paper80mm,
      build: (pw.Context ctx) {
        return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
          if (logo != null) pw.Container(width: 50 * PdfPageFormat.mm, height: 28 * PdfPageFormat.mm, child: pw.Image(logo, fit: pw.BoxFit.contain)),
          if (logo != null) pw.SizedBox(height: 4 * PdfPageFormat.mm),
          pw.Text(SettingsService.shopName.isNotEmpty ? SettingsService.shopName.toUpperCase() : 'BBS CLUB', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
          if (SettingsService.ticketHeader.isNotEmpty) pw.Text(SettingsService.ticketHeader, style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.center),
          if (SettingsService.shopAddress.isNotEmpty) pw.Text(SettingsService.shopAddress, style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center),
          if (SettingsService.shopPhone.isNotEmpty) pw.Text('Tel: ${SettingsService.shopPhone}', style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center),
          pw.SizedBox(height: 3 * PdfPageFormat.mm),
          pw.Divider(thickness: 0.8, borderStyle: pw.BorderStyle.dashed),
          pw.SizedBox(height: 2 * PdfPageFormat.mm),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('Fecha:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
            pw.Text(DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(transaction['created_at'] as String)), style: const pw.TextStyle(fontSize: 9)),
          ]),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('Cajero:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
            pw.Text((transaction['cashier_name'] ?? 'N/A').toString(), style: const pw.TextStyle(fontSize: 9)),
          ]),
          if (transaction['barber_name'] != null && (transaction['barber_name'] as String).isNotEmpty)
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('Barbero:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              pw.Text((transaction['barber_name'] as String), style: const pw.TextStyle(fontSize: 9)),
            ]),
          pw.SizedBox(height: 2 * PdfPageFormat.mm),
          pw.Divider(thickness: 0.8, borderStyle: pw.BorderStyle.dashed),
          pw.SizedBox(height: 2 * PdfPageFormat.mm),
          ...items.map((item) {
            final name = (item['service_name'] ?? item['product_name'] ?? 'Item').toString();
            final qty = item['quantity'] as int;
            final price = (item['price_at_moment'] as num).toDouble();
            return pw.Padding(padding: pw.EdgeInsets.only(bottom: 2.5 * PdfPageFormat.mm), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(name, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold), maxLines: 2),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('$qty x ${SettingsService.formatCurrency(price)}', style: const pw.TextStyle(fontSize: 9)),
                pw.Text(SettingsService.formatCurrency(price * qty), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              ]),
            ]));
          }),
          pw.Divider(thickness: 0.8),
          pw.SizedBox(height: 2 * PdfPageFormat.mm),
          pw.Container(padding: pw.EdgeInsets.symmetric(vertical: 2 * PdfPageFormat.mm), decoration: pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 0.8), bottom: pw.BorderSide(width: 0.8))), child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('TOTAL:', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.Text(SettingsService.formatCurrency((transaction['total'] as num).toDouble()), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          ])),
          pw.SizedBox(height: 3 * PdfPageFormat.mm),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('Pago:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            pw.Text(_formatPayment(transaction['payment_method']?.toString() ?? 'cash'), style: const pw.TextStyle(fontSize: 10)),
          ]),
          if ((transaction['cash_received'] as num?) != null && (transaction['cash_received'] as num).toDouble() > 0) ...[
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Recibido:', style: const pw.TextStyle(fontSize: 9)), pw.Text(SettingsService.formatCurrency((transaction['cash_received'] as num).toDouble()), style: const pw.TextStyle(fontSize: 9))]),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Vuelto:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)), pw.Text(SettingsService.formatCurrency((transaction['change_amount'] as num?)?.toDouble() ?? 0), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))]),
          ],
          pw.SizedBox(height: 5 * PdfPageFormat.mm),
          pw.Divider(thickness: 0.8, borderStyle: pw.BorderStyle.dashed),
          pw.SizedBox(height: 3 * PdfPageFormat.mm),
          if (SettingsService.ticketFooter.isNotEmpty) pw.Text(SettingsService.ticketFooter, style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic), textAlign: pw.TextAlign.center),
          pw.Text('¡Gracias por su visita!', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
          pw.Text('(Reimpresión)', style: const pw.TextStyle(fontSize: 7), textAlign: pw.TextAlign.center),
        ]);
      },
    ));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'Ticket_Reimpresion_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf');
  }

  String _formatPayment(String method) {
    switch (method) { case 'cash': return 'Efectivo'; case 'card': return 'Tarjeta'; case 'transfer': return 'Transferencia'; default: return method; }
  }
}
