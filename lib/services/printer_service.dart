// lib/services/printer_service.dart - SIN RECTANGULO FAKE - SOLO LOGO REAL PNG
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/local_transaction.dart';
import '../services/settings_service.dart';
import '../services/ticket_config_service.dart';
import 'package:intl/intl.dart';

class PrinterService {
  Future<void> printTicket(LocalTransaction transaction) async {
    final ancho = TicketConfigService.ancho;
    final is58 = ancho == '58mm';
    final pageWidth = is58 ? 58 * PdfPageFormat.mm : 80 * PdfPageFormat.mm;

    // Cargar logo REAL de tu Supabase - image_e4e93d.png
    pw.ImageProvider? logoProvider;
    final logoUrl = TicketConfigService.logoUrl.isNotEmpty
        ? TicketConfigService.logoUrl
        : (SettingsService.ticketLogoUrl.isNotEmpty ? SettingsService.ticketLogoUrl : SettingsService.shopLogoUrl);
    
    if (logoUrl.isNotEmpty && (logoUrl.toLowerCase().endsWith('.png') || logoUrl.toLowerCase().endsWith('.jpg') || logoUrl.toLowerCase().endsWith('.jpeg'))) {
      try {
        logoProvider = await networkImage(logoUrl);
        print('Logo cargado OK: $logoUrl');
      } catch (e) {
        print('Logo fail $e url=$logoUrl');
      }
    }

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(pageWidth, double.infinity, marginAll: is58 ? 1.5 * PdfPageFormat.mm : 2 * PdfPageFormat.mm),
        build: (_) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // LOGO REAL - SIN RECTANGULO FAKE
              if (logoProvider != null)
                pw.Center(
                  child: pw.Container(
                    height: is58 ? 50 : 65,
                    margin: const pw.EdgeInsets.only(bottom: 8),
                    child: pw.Image(logoProvider),
                  ),
                ),
              // Si no hay logo, NO mostrar rectangulo fake - solo nombre
              pw.Center(child: pw.Text(TicketConfigService.nombreNegocio.toUpperCase(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: is58 ? 14 : 16))),
              pw.Center(child: pw.Text('${TicketConfigService.config['sii_razon'] ?? SettingsService.shopName}', style: pw.TextStyle(fontSize: is58 ? 9 : 10))),
              if (TicketConfigService.rut.isNotEmpty || SettingsService.shopRif.isNotEmpty)
                pw.Center(child: pw.Text('RUT ${TicketConfigService.rut.isNotEmpty ? TicketConfigService.rut : SettingsService.shopRif}', style: pw.TextStyle(fontSize: is58 ? 9 : 10))),
              if (TicketConfigService.direccion.isNotEmpty)
                pw.Center(child: pw.Text(TicketConfigService.direccion, style: pw.TextStyle(fontSize: is58 ? 8 : 9), textAlign: pw.TextAlign.center)),
              if (TicketConfigService.telefono.isNotEmpty)
                pw.Center(child: pw.Text('Tel. ${TicketConfigService.telefono}', style: pw.TextStyle(fontSize: is58 ? 8 : 9))),
              pw.SizedBox(height: 8),
              pw.Center(child: pw.Text('BOLETA DTE39', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: is58 ? 11 : 12))),
              pw.SizedBox(height: 4),
              pw.Text(List.filled(is58 ? 32 : 42, '-').join(), style: const pw.TextStyle(fontSize: 8)),
              pw.Text('Folio: ${transaction.remoteId}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: is58 ? 10 : 11)),
              pw.Text('Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}', style: pw.TextStyle(fontSize: is58 ? 9 : 10)),
              pw.Text('Cajero: ${transaction.cashierName.length > 22 ? transaction.cashierName.substring(0, 22) : transaction.cashierName}', style: pw.TextStyle(fontSize: is58 ? 9 : 10)),
              pw.Text('Pago: ${_formatPayment(transaction.paymentMethod)}', style: pw.TextStyle(fontSize: is58 ? 9 : 10)),
              pw.SizedBox(height: 4),
              pw.Text(List.filled(is58 ? 32 : 42, '-').join(), style: const pw.TextStyle(fontSize: 8)),
              pw.SizedBox(height: 6),
              ...transaction.items.map((it) {
                final rawName = (it.type == 'service' ? it.serviceName : it.productName).toString();
                final name = rawName.length > 24 ? rawName.substring(0, 24) : rawName;
                final qty = it.quantity as int;
                final price = it.priceAtMoment as double;
                final sub = price * qty;
                final fmtSub = NumberFormat('#,###', 'es_CL').format(sub.round());
                final fmtUnit = NumberFormat('#,###', 'es_CL').format(price.round());
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 6),
                  child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                      pw.Expanded(child: pw.Text(name.toUpperCase(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: is58 ? 11 : 12))),
                      pw.Text('\$$fmtSub', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: is58 ? 11 : 12)),
                    ]),
                    pw.Text('  $qty x \$$fmtUnit', style: pw.TextStyle(fontSize: is58 ? 9 : 10)),
                  ]),
                );
              }),
              pw.Text(List.filled(is58 ? 32 : 42, '.').join(), style: const pw.TextStyle(fontSize: 7)),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('Subtotal:', style: pw.TextStyle(fontSize: is58 ? 10 : 11)),
                pw.Text('\$${NumberFormat('#,###', 'es_CL').format((transaction.subtotal as double).round())}', style: pw.TextStyle(fontSize: is58 ? 10 : 11)),
              ]),
              pw.Divider(thickness: 0.8),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
                pw.Text('TOTAL \$${NumberFormat('#,###', 'es_CL').format((transaction.total as double).round())}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: is58 ? 14 : 18)),
              ]),
              pw.SizedBox(height: 6),
              pw.Text(List.filled(is58 ? 32 : 42, '-').join(), style: const pw.TextStyle(fontSize: 8)),
              pw.Text('Recibido: \$${NumberFormat('#,###', 'es_CL').format(((transaction.cashReceived as double?) ?? (transaction.total as double)).round())}', style: pw.TextStyle(fontSize: is58 ? 10 : 11)),
              pw.Text('Vuelto: \$${NumberFormat('#,###', 'es_CL').format(((transaction.changeAmount as double?) ?? 0).round())}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: is58 ? 10 : 11)),
              pw.Text(List.filled(is58 ? 32 : 42, '-').join(), style: const pw.TextStyle(fontSize: 8)),
              pw.SizedBox(height: 8),
              pw.Center(child: pw.Text(TicketConfigService.mensaje.isNotEmpty ? TicketConfigService.mensaje : '¡Gracias por su visita!', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: is58 ? 10 : 11), textAlign: pw.TextAlign.center)),
              pw.SizedBox(height: 4),
              pw.Center(child: pw.Text(DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now()), style: const pw.TextStyle(fontSize: 7))),
              pw.SizedBox(height: 25),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: 'BBS CLUB ${transaction.remoteId} 80mm LOGO REAL',
      format: PdfPageFormat(pageWidth, double.infinity, marginAll: 1 * PdfPageFormat.mm),
      usePrinterSettings: false,
    );
  }

  String _formatPayment(String m) {
    switch (m) {
      case 'cash': return 'Efectivo';
      case 'card': return 'Tarjeta';
      case 'transfer': return 'Transferencia';
      case 'mixed': return 'Mixto';
      default: return m;
    }
  }
}
