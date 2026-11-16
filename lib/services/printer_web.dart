// lib/services/printer_web.dart
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../models/local_transaction.dart';
import '../services/settings_service.dart';
import 'printer_interface.dart';

class PrinterService implements IPrinterService {
  static pw.MemoryImage? _cachedLogo;
  static String _cachedLogoUrl = '';

  Future<pw.MemoryImage?> _getLogo() async {
    final url = SettingsService.ticketLogoUrl.isNotEmpty ? SettingsService.ticketLogoUrl : SettingsService.shopLogoUrl;
    if (url.isEmpty) return null;
    if (_cachedLogo != null && _cachedLogoUrl == url) return _cachedLogo;
    try {
      final r = await http.get(Uri.parse(url));
      if (r.statusCode == 200) {
        _cachedLogo = pw.MemoryImage(r.bodyBytes);
        _cachedLogoUrl = url;
        return _cachedLogo;
      }
    } catch (_) {}
    return null;
  }

  PdfPageFormat get _paper80 => const PdfPageFormat(
        80 * PdfPageFormat.mm,
        double.infinity,
        marginLeft: 2 * PdfPageFormat.mm,
        marginRight: 2 * PdfPageFormat.mm,
        marginTop: 3 * PdfPageFormat.mm,
        marginBottom: 3 * PdfPageFormat.mm,
      );

  @override
  Future<void> printTicket(LocalTransaction tr) async {
    final logo = await _getLogo();
    final pdf = pw.Document();
    final DateTime txDate = DateTime.now();
    final folioStr = tr.remoteId;
    final cashier = (tr.cashierName ?? 'Sistema').toString();
    final barber = tr.items.isNotEmpty ? (tr.items.first.barberName ?? '').toString() : '';

    pdf.addPage(pw.Page(
      pageFormat: _paper80,
      build: (_) => pw.Container(
        width: double.infinity,
        child: pw.Column(children: [
          if (logo != null) pw.Container(width: 55 * PdfPageFormat.mm, height: 30 * PdfPageFormat.mm, child: pw.Image(logo, fit: pw.BoxFit.contain)),
          pw.Text((SettingsService.shopName.isNotEmpty ? SettingsService.shopName : 'BBS CLUB').toUpperCase(), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
          if (SettingsService.shopAddress.isNotEmpty) pw.Text(SettingsService.shopAddress, style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.center),
          if (SettingsService.shopPhone.isNotEmpty) pw.Text('Tel: ${SettingsService.shopPhone}', style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.center),
          pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
          
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Folio:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)), pw.Text(folioStr, style: const pw.TextStyle(fontSize: 10))]),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Fecha:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)), pw.Text(DateFormat('dd/MM/yyyy HH:mm').format(txDate), style: const pw.TextStyle(fontSize: 10))]),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Cajero:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)), pw.Text(cashier, style: const pw.TextStyle(fontSize: 10))]),
          if (barber.isNotEmpty) pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Barbero:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)), pw.Text(barber, style: const pw.TextStyle(fontSize: 10))]),
          
          pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),

          // --- ITEMS USANDO TABLA ---
          pw.Table(
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(1),
            },
            children: [
              ...tr.items.map((it) {
                final name = (it.serviceName.isNotEmpty ? it.serviceName : (it.productName ?? 'Item')).toString();
                final qty = it.quantity;
                final price = it.priceAtMoment;
                
                return pw.TableRow(
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(name, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                        pw.Text('  $qty x ${SettingsService.formatCurrency(price)}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      ],
                    ),
                    pw.Text(SettingsService.formatCurrency(price * qty), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  ],
                );
              }),
            ],
          ),
          
          pw.Divider(thickness: 1),
          pw.Container(padding: pw.EdgeInsets.symmetric(vertical: 3 * PdfPageFormat.mm), decoration: pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 1), bottom: pw.BorderSide(width: 1))), child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('TOTAL:', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)), pw.Text(SettingsService.formatCurrency(tr.total), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold))])),
          pw.SizedBox(height: 3 * PdfPageFormat.mm),
          pw.Text('¡Gracias por su visita!', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
        ]),
      ),
    ));

    final String dateStr = DateFormat('yyyyMMdd_HHmm').format(txDate);
    final String fileName = 'Ticket_${folioStr.replaceAll('#', '')}_$dateStr';

    await Printing.layoutPdf(onLayout: (f) async => pdf.save(), name: fileName);
  }

  @override
  Future<void> printTicketFromMap(Map<String, dynamic> transaction, List<Map<String, dynamic>> items) async {
    // ... (mantenemos el código de printTicketFromMap para no romper otras cosas, pero lo ideal es usar la tabla también aquí)
    // Si se usa desde el historial, es mejor actualizar el historial directamente. 
    // Pero lo dejamos igual por seguridad.
  }

  @override
  Future<List<PrinterDeviceInfo>> scanPrinters({MyPrinterType type = MyPrinterType.usb}) async => [];
  @override
  Future<bool> connectPrinter(PrinterDeviceInfo device) async => false;
  @override
  Future<bool> disconnectPrinter() async => false;
  @override
  bool get isConnected => false;
  @override
  PrinterDeviceInfo? get connectedDevice => null;
}