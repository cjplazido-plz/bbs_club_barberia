// ticket_easton.dart
// Formato Easton Outlet Mall - termica 80mm
// Monoespaciado Courier + lineas de guiones como la impresora termica.
// Un solo builder para POS (Carrito) y para Historial (Reimpresion).
// Uso:
//   final bytes = await EastonTicket.build(data: EastonTicketData(...));
//   await Printing.sharePdf(bytes: bytes, filename: 'Ticket_1067');
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:http/http.dart' as http;

class EastonTicketItem {
  final String name;
  final int qty;
  final double price;
  const EastonTicketItem({required this.name, required this.qty, required this.price});
  double get total => price * qty;
}

class EastonTicketData {
  final String shopName; // BBS CLUB BARBERIA
  final String shopRif; // 77.000000-0
  final String shopAddress; // Manuel Montt 460 - local 6 - Coronel
  final String shopPhone; // +56 9 6106 3670
  final String folio;
  final DateTime date;
  final String clientName;
  final String cashierName;
  final String cashRegister;
  final String barberName;
  final List<EastonTicketItem> items;
  final double subtotal;
  final double discount;
  final double total;
  final String paymentLabel; // Efectivo / Transferencia / Tarjeta / Mixto
  final double? cashReceived;
  final double? change;
  final List<Map<String, dynamic>>? mixedPayments; // [{method:'cash', amount: 6000}]
  final String footer; // ¡Gracias por su visita!
  final bool isReprint;
  final String? logoUrl;

  const EastonTicketData({
    required this.shopName,
    required this.shopRif,
    required this.shopAddress,
    required this.shopPhone,
    required this.folio,
    required this.date,
    required this.clientName,
    required this.cashierName,
    required this.cashRegister,
    required this.barberName,
    required this.items,
    required this.subtotal,
    this.discount = 0,
    required this.total,
    required this.paymentLabel,
    this.cashReceived,
    this.change,
    this.mixedPayments,
    this.footer = '¡Gracias por su visita!',
    this.isReprint = false,
    this.logoUrl,
  });
}

class EastonTicket {
  // 32 guiones = ancho exacto 80mm en Courier 9pt. Igual que Easton.
  static const String dash = '--------------------------------';

  static String fmt(double v) {
    // $ 12.000 - formato chileno con punto de miles
    final f = NumberFormat('#,##0', 'es_CL');
    return '\$ ${f.format(v.round())}';
  }

  static String labelForMethod(String m) {
    switch (m) {
      case 'cash': return 'Efectivo';
      case 'card': return 'Tarjeta';
      case 'transfer': return 'Transferencia';
      case 'mixed':
      case 'mixto': return 'Mixto';
      default: return m;
    }
  }

  static Future<Uint8List> build({required EastonTicketData data}) async {
    final mono = pw.Font.courier();
    final monoBold = pw.Font.courierBold();
    // Courier oblique no existe en pdf pkg, se simula con italic=false + estilo
    // Para el footer usamos courier normal.

    pw.ImageProvider? logoImage;
    final logoUrl = (data.logoUrl ?? '').trim();
    if (logoUrl.isNotEmpty) {
      try {
        final res = await http.get(Uri.parse(logoUrl));
        if (res.statusCode == 200) logoImage = pw.MemoryImage(res.bodyBytes);
      } catch (_) {}
    }

    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(80 * PdfPageFormat.mm, double.infinity, marginAll: 3 * PdfPageFormat.mm),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // ---- LOGO (opcional, chico como Easton sin logo) ----
            if (logoImage != null) ...[
              pw.Center(child: pw.Image(logoImage, height: 38, fit: pw.BoxFit.contain)),
              pw.SizedBox(height: 4),
            ],
            // ---- ENCABEZADO - centrado, Courier bold como Easton ----
            pw.Text(
              'BBSCLUB\'',
              style: pw.TextStyle(font: monoBold, fontSize: 14, letterSpacing: 1.0),
              textAlign: pw.TextAlign.center,
            ),
            pw.Text(
              data.shopName.toUpperCase(),
              style: pw.TextStyle(font: monoBold, fontSize: 11),
              textAlign: pw.TextAlign.center,
            ),
            pw.Text(
              '${data.shopName} SPA',
              style: pw.TextStyle(font: mono, fontSize: 9),
              textAlign: pw.TextAlign.center,
            ),
            pw.Text('RUT: ${data.shopRif}', style: pw.TextStyle(font: mono, fontSize: 9), textAlign: pw.TextAlign.center),
            pw.Text(data.shopAddress, style: pw.TextStyle(font: mono, fontSize: 8.5), textAlign: pw.TextAlign.center),
            pw.Text('Tel: ${data.shopPhone}', style: pw.TextStyle(font: mono, fontSize: 8.5), textAlign: pw.TextAlign.center),
            pw.SizedBox(height: 4),
            pw.Text(dash, style: pw.TextStyle(font: mono, fontSize: 9), textAlign: pw.TextAlign.center),

            // ---- TITULO ----
            pw.SizedBox(height: 4),
            pw.Text('TICKET DE VENTA', style: pw.TextStyle(font: monoBold, fontSize: 11), textAlign: pw.TextAlign.center),
            if (data.isReprint) ...[
              pw.SizedBox(height: 2),
              pw.Text('*** REIMPRESION ***', style: pw.TextStyle(font: monoBold, fontSize: 10), textAlign: pw.TextAlign.center),
              pw.Text('Copia - No valido como boleta', style: pw.TextStyle(font: mono, fontSize: 7.5), textAlign: pw.TextAlign.center),
            ],
            pw.SizedBox(height: 4),

            // ---- DATOS - una sola linea por campo, como Easton: "Folio: V-1116" ----
            pw.Text('Folio: ${data.folio}', style: pw.TextStyle(font: mono, fontSize: 9)),
            pw.Text('Fecha: ${DateFormat('dd/MM/yyyy HH:mm:ss').format(data.date)}', style: pw.TextStyle(font: mono, fontSize: 9)),
            pw.Text('Cliente: ${data.clientName}', style: pw.TextStyle(font: mono, fontSize: 9)),
            pw.Text('Cajero: ${data.cashierName}', style: pw.TextStyle(font: mono, fontSize: 9)),
            pw.Text('Caja: ${data.cashRegister}', style: pw.TextStyle(font: mono, fontSize: 9)),
            pw.Text('Barbero: ${data.barberName}', style: pw.TextStyle(font: mono, fontSize: 9)),
            pw.SizedBox(height: 4),
            pw.Text(dash, style: pw.TextStyle(font: mono, fontSize: 9), textAlign: pw.TextAlign.center),
            pw.SizedBox(height: 4),

            // ---- ITEMS - encabezado ----
            pw.Row(children: [
              pw.Expanded(child: pw.Text('Cant  Descripcion', style: pw.TextStyle(font: monoBold, fontSize: 9))),
              pw.Text('Total', style: pw.TextStyle(font: monoBold, fontSize: 9)),
            ]),
            pw.SizedBox(height: 2),
            ...data.items.map((it) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Row(children: [
                    pw.Expanded(child: pw.Text(it.name, style: pw.TextStyle(font: mono, fontSize: 9))),
                    pw.Text(fmt(it.total), style: pw.TextStyle(font: mono, fontSize: 9)),
                  ]),
                  pw.Text('  ${it.qty} x ${fmt(it.price)}', style: pw.TextStyle(font: mono, fontSize: 8, color: PdfColors.grey700)),
                  pw.SizedBox(height: 1),
                ],
              );
            }),
            pw.SizedBox(height: 4),
            pw.Text(dash, style: pw.TextStyle(font: mono, fontSize: 9), textAlign: pw.TextAlign.center),
            pw.SizedBox(height: 4),

            // ---- TOTALES ----
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('Subtotal', style: pw.TextStyle(font: mono, fontSize: 9)),
              pw.Text(fmt(data.subtotal), style: pw.TextStyle(font: mono, fontSize: 9)),
            ]),
            if (data.discount > 0) ...[
              pw.SizedBox(height: 2),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('Descuento', style: pw.TextStyle(font: mono, fontSize: 9)),
                pw.Text('- ${fmt(data.discount)}', style: pw.TextStyle(font: mono, fontSize: 9)),
              ]),
            ],
            pw.SizedBox(height: 4),
            pw.Text(dash, style: pw.TextStyle(font: mono, fontSize: 9), textAlign: pw.TextAlign.center),
            pw.SizedBox(height: 4),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('TOTAL', style: pw.TextStyle(font: monoBold, fontSize: 12)),
              pw.Text(fmt(data.total), style: pw.TextStyle(font: monoBold, fontSize: 12)),
            ]),
            pw.SizedBox(height: 4),
            pw.Text(dash, style: pw.TextStyle(font: mono, fontSize: 9), textAlign: pw.TextAlign.center),
            pw.SizedBox(height: 4),

            // ---- PAGO - estilo Easton: Pago / Paga / Vuelto ----
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('Forma de pago:', style: pw.TextStyle(font: mono, fontSize: 9)),
              pw.Text(data.paymentLabel, style: pw.TextStyle(font: mono, fontSize: 9)),
            ]),
            // Si es mixto, listar cada pago como en Easton (una linea por pago)
            if (data.mixedPayments != null && data.mixedPayments!.isNotEmpty)
              ...data.mixedPayments!.map((p) => pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 1),
                    child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                      pw.Text('  ${labelForMethod((p['method'] ?? '').toString())}:', style: pw.TextStyle(font: mono, fontSize: 8.5)),
                      pw.Text(fmt((p['amount'] as num).toDouble()), style: pw.TextStyle(font: mono, fontSize: 8.5)),
                    ]),
                  )),
            if (data.cashReceived != null && data.cashReceived! > 0)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 1),
                child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text('Recibido:', style: pw.TextStyle(font: mono, fontSize: 9)),
                  pw.Text(fmt(data.cashReceived!), style: pw.TextStyle(font: mono, fontSize: 9)),
                ]),
              ),
            if (data.change != null && data.change! > 0)
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('Vuelto:', style: pw.TextStyle(font: mono, fontSize: 9)),
                pw.Text(fmt(data.change!), style: pw.TextStyle(font: mono, fontSize: 9)),
              ]),
            pw.SizedBox(height: 6),
            pw.Text(dash, style: pw.TextStyle(font: mono, fontSize: 9), textAlign: pw.TextAlign.center),
            pw.SizedBox(height: 6),

            // ---- PIE - igual que Easton ----
            pw.Text(data.footer, style: pw.TextStyle(font: mono, fontSize: 8.5), textAlign: pw.TextAlign.center),
            pw.SizedBox(height: 4),
            pw.Text(DateFormat('dd-MM-yyyy, h:mm:ss a').format(data.date), style: pw.TextStyle(font: mono, fontSize: 7.5, color: PdfColors.grey700), textAlign: pw.TextAlign.center),
            pw.SizedBox(height: 10),
            // Espacio para corte de papel
            pw.Text('', style: pw.TextStyle(font: mono, fontSize: 4)),
          ],
        ),
      ),
    );
    return pdf.save();
  }

  // Helper para Historial: construye desde Map de Supabase (transactions + transaction_items)
  static EastonTicketData fromHistory({
    required Map<String, dynamic> transaction,
    required List<Map<String, dynamic>> items,
    required String shopName,
    required String shopRif,
    required String shopAddress,
    required String shopPhone,
    required String footer,
    String? logoUrl,
    bool isReprint = true,
  }) {
    String barber = (transaction['barber_name'] ?? '').toString();
    if (barber.isEmpty && items.isNotEmpty) {
      final names = items.map((i) => i['barber_name']?.toString()).where((b) => b != null && b!.isNotEmpty && b != 'null').toSet().toList();
      if (names.isNotEmpty) barber = names.join(', ');
    }
    return EastonTicketData(
      shopName: shopName,
      shopRif: shopRif,
      shopAddress: shopAddress,
      shopPhone: shopPhone,
      folio: transaction['folio']?.toString() ?? '#${transaction['id'].toString().substring(transaction['id'].toString().length - 6).toUpperCase()}',
      date: DateTime.parse(transaction['created_at'].toString()),
      clientName: (transaction['client_name']?.toString().isNotEmpty == true) ? transaction['client_name'].toString() : 'Consumidor Final',
      cashierName: transaction['cashier_name']?.toString() ?? 'N/A',
      cashRegister: transaction['cash_register_id']?.toString() ?? 'N/A',
      barberName: barber.isEmpty ? 'Sin asignar' : barber,
      items: items.map((it) => EastonTicketItem(
        name: (it['service_name'] ?? it['product_name'] ?? 'Item').toString(),
        qty: (it['quantity'] as num).toInt(),
        price: (it['price_at_moment'] as num).toDouble(),
      )).toList(),
      subtotal: ((transaction['subtotal'] as num?) ?? (transaction['total'] as num)).toDouble(),
      discount: 0,
      total: (transaction['total'] as num).toDouble(),
      paymentLabel: labelForMethod((transaction['payment_method'] ?? 'cash').toString()),
      cashReceived: (transaction['cash_received'] as num?)?.toDouble(),
      change: (transaction['change_amount'] as num?)?.toDouble(),
      footer: footer,
      isReprint: isReprint,
      logoUrl: logoUrl,
    );
  }
}
