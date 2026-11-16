// lib/services/printer_service.dart
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import '../models/local_transaction.dart';
import '../services/settings_service.dart';
import '../services/ticket_config_service.dart';

class PrinterService {
  Future<void> printTicket(LocalTransaction transaction) async {
    final ancho = TicketConfigService.ancho;
    final is58 = ancho == '58mm';
    final pageWidth = is58 ? 58 * PdfPageFormat.mm : 80 * PdfPageFormat.mm;

    pw.ImageProvider? logoImage;
    final logoUrl = SettingsService.ticketLogoUrl.isNotEmpty ? SettingsService.ticketLogoUrl : SettingsService.shopLogoUrl;

    if (logoUrl.isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(logoUrl));
        if (response.statusCode == 200) {
          logoImage = pw.MemoryImage(response.bodyBytes);
        }
      } catch (e) {
        print('Error al cargar el logo del ticket: $e');
      }
    }

    String displayBarberName = '';
    if (transaction.items.isNotEmpty) {
      final itemBarbers = transaction.items
          .map((i) => i.barberName)
          .where((b) => b.isNotEmpty && b != 'null')
          .toSet()
          .toList();
      if (itemBarbers.isNotEmpty) {
        displayBarberName = itemBarbers.join(', ');
      }
    }

    final folioStr = transaction.folio.isNotEmpty ? transaction.folio : transaction.remoteId;
    final DateTime txDate = DateTime.now();
    
    final pdf = pw.Document();
    
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat(pageWidth, double.infinity, marginAll: is58 ? 2 * PdfPageFormat.mm : 3 * PdfPageFormat.mm),
      build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
        
        // --- LOGO ---
        if (logoImage != null) ...[
          pw.Center(child: pw.Image(logoImage, height: is58 ? 40 : 45, fit: pw.BoxFit.contain)),
          pw.SizedBox(height: 6),
        ],
        
        // --- ENCABEZADO DEL NEGOCIO ---
        pw.Text((SettingsService.shopName.isNotEmpty ? SettingsService.shopName : 'BBS CLUB').toUpperCase(), 
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: is58 ? 12 : 14, letterSpacing: 0.5), 
          textAlign: pw.TextAlign.center
        ),
        pw.Text('${SettingsService.shopName.isNotEmpty ? SettingsService.shopName : 'BBS CLUB'} SPA', style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center),
        pw.Text('RUT: ${SettingsService.shopRif}', style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center),
        pw.Text(SettingsService.shopAddress, style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center),
        pw.Text('Tel: ${SettingsService.shopPhone}', style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center),
        
        pw.SizedBox(height: 10),
        pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),
        pw.SizedBox(height: 6),

        // --- DATOS DE LA VENTA ---
        pw.Text('TICKET DE VENTA', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10), textAlign: pw.TextAlign.center),
        pw.SizedBox(height: 4),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('Folio:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)), 
          pw.Text(folioStr, style: const pw.TextStyle(fontSize: 8))
        ]),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('Fecha:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)), 
          pw.Text(DateFormat('dd/MM/yyyy HH:mm:ss').format(txDate), style: const pw.TextStyle(fontSize: 8))
        ]),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('Cliente:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)), 
          pw.Text(transaction.clientName, style: const pw.TextStyle(fontSize: 8))
        ]),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('Cajero:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)), 
          pw.Text(transaction.cashierName, style: const pw.TextStyle(fontSize: 8))
        ]),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('Caja:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)), 
          pw.Text(transaction.cashRegisterId, style: const pw.TextStyle(fontSize: 8))
        ]),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('Barbero:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)), 
          pw.Text(displayBarberName.isEmpty ? 'Sin asignar' : displayBarberName, style: const pw.TextStyle(fontSize: 8))
        ]),
        
        pw.SizedBox(height: 6),
        pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),
        pw.SizedBox(height: 6),

        // --- ITEMS ---
        pw.Table(
          columnWidths: {
            0: const pw.FlexColumnWidth(3),
            1: const pw.FlexColumnWidth(1),
          },
          children: [
            pw.TableRow(
              children: [
                pw.Text('Cant  Descripción', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                pw.Text('Total', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
              ],
            ),
            ...transaction.items.map((it) {
              final name = it.type == 'service' ? it.serviceName : (it.productName ?? 'Item');
              final qty = it.quantity;
              final price = it.priceAtMoment;
              final total = price * qty;
              
              return pw.TableRow(
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(name, style: const pw.TextStyle(fontSize: 8)),
                      pw.Text('  $qty x ${SettingsService.formatCurrency(price)}', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Text(SettingsService.formatCurrency(total), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8)),
                ],
              );
            }),
          ],
        ),
        
        pw.SizedBox(height: 6),
        pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),
        pw.SizedBox(height: 6),

        // --- TOTALES ---
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('Subtotal', style: const pw.TextStyle(fontSize: 9)), 
          pw.Text(SettingsService.formatCurrency(transaction.subtotal), style: const pw.TextStyle(fontSize: 9))
        ]),
        pw.SizedBox(height: 4),
        pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),
        pw.SizedBox(height: 4),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('TOTAL', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)), 
          pw.Text(SettingsService.formatCurrency(transaction.total), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold))
        ]),
        pw.SizedBox(height: 4),
        pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),
        pw.SizedBox(height: 6),

        // --- PAGO ---
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('Forma de pago:', style: const pw.TextStyle(fontSize: 8)), 
          pw.Text(_formatPayment(transaction.paymentMethod), style: const pw.TextStyle(fontSize: 8))
        ]),
        if (transaction.cashReceived > 0) 
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('Recibido:', style: const pw.TextStyle(fontSize: 8)), 
            pw.Text(SettingsService.formatCurrency(transaction.cashReceived), style: const pw.TextStyle(fontSize: 8))
          ]),
        if (transaction.changeAmount > 0) 
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('Vuelto:', style: const pw.TextStyle(fontSize: 8)), 
            pw.Text(SettingsService.formatCurrency(transaction.changeAmount), style: const pw.TextStyle(fontSize: 8))
          ]),

        pw.SizedBox(height: 8),
        pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),
        pw.SizedBox(height: 8),

        // --- PIE DE PÁGINA ---
        pw.Text(SettingsService.ticketFooter.isNotEmpty ? SettingsService.ticketFooter : '¡Gracias por su visita!', 
          style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic), 
          textAlign: pw.TextAlign.center
        ),
        pw.SizedBox(height: 4),
        pw.Text(DateFormat('dd-MM-yyyy, h:mm:ss a').format(txDate), style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700), textAlign: pw.TextAlign.center),
      ]),
    ));

    final String dateStr = DateFormat('yyyyMMdd_HHmmss').format(txDate);
    final String cleanFolio = folioStr.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
    final String fileName = 'Ticket_${cleanFolio}_$dateStr';

    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(), 
      name: fileName, 
      format: PdfPageFormat(pageWidth, double.infinity)
    );
  }

  String _formatPayment(String m) {
    switch (m) {
      case 'cash': return 'Efectivo';
      case 'card': return 'Tarjeta';
      case 'transfer': return 'Transferencia';
      case 'mixed':
      case 'mixto':
        return 'Mixto';
      default: return m;
    }
  }
}