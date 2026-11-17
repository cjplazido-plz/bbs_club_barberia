// ticket_easton.dart - VERSION BOLD / MAS NEGRO PARA TERMICA 80mm
// Cambio clave: TODO en Courier Bold + negro puro #000000.
// Nada en gris, nada en Courier normal. La termica no imprime grises,
// los deja lavados. Por eso salia ilegilble.
// Tamanos subidos: cuerpo 9 -> 10, TOTAL 12 -> 14, encabezado 14 -> 16.
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
  final String shopName;
  final String shopRif;
  final String shopAddress;
  final String shopPhone;
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
  final String paymentLabel;
  final double? cashReceived;
  final double? change;
  final List<Map<String, dynamic>>? mixedPayments;
  final String footer;
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
  static const String dash = '--------------------------------';

  static String fmt(double v) {
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
    // SOLO Bold + negro puro. Nada de gris.
    final monoBold = pw.Font.courierBold();
    const black = PdfColors.black;

    pw.ImageProvider? logoImage;
    final logoUrl = (data.logoUrl ?? '').trim();
    if (logoUrl.isNotEmpty) {
      try {
        final res = await http.get(Uri.parse(logoUrl));
        if (res.statusCode == 200) logoImage = pw.MemoryImage(res.bodyBytes);
      } catch (_) {}
    }

    // Helper para no repetir: todo bold + negro
    pw.TextStyle st(double size) => pw.TextStyle(font: monoBold, fontSize: size, color: black);

    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(80 * PdfPageFormat.mm, double.infinity, marginAll: 3 * PdfPageFormat.mm),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            if (logoImage != null) ...[
              pw.Center(child: pw.Image(logoImage, height: 38, fit: pw.BoxFit.contain)),
              pw.SizedBox(height: 4),
            ],
            // ENCABEZADO - mas grande y todo Bold
            pw.Text("BBSCLUB'", style: pw.TextStyle(font: monoBold, fontSize: 16, color: black, letterSpacing: 1.0), textAlign: pw.TextAlign.center),
            pw.Text(data.shopName.toUpperCase(), style: st(12), textAlign: pw.TextAlign.center),
            pw.Text('${data.shopName} SPA', style: st(10), textAlign: pw.TextAlign.center),
            pw.Text('RUT: ${data.shopRif}', style: st(10), textAlign: pw.TextAlign.center),
            pw.Text(data.shopAddress, style: st(9.5), textAlign: pw.TextAlign.center),
            pw.Text('Tel: ${data.shopPhone}', style: st(9.5), textAlign: pw.TextAlign.center),
            pw.SizedBox(height: 4),
            pw.Text(dash, style: st(10), textAlign: pw.TextAlign.center),

            pw.SizedBox(height: 4),
            pw.Text('TICKET DE VENTA', style: st(12), textAlign: pw.TextAlign.center),
            if (data.isReprint) ...[
              pw.SizedBox(height: 2),
              pw.Text('*** REIMPRESION ***', style: st(11), textAlign: pw.TextAlign.center),
              pw.Text('Copia - No valido como boleta', style: st(8.5), textAlign: pw.TextAlign.center),
            ],
            pw.SizedBox(height: 4),

            // DATOS - todo Bold 10, negro puro
            pw.Text('Folio: ${data.folio}', style: st(10)),
            pw.Text('Fecha: ${DateFormat('dd/MM/yyyy HH:mm:ss').format(data.date)}', style: st(10)),
            pw.Text('Cliente: ${data.clientName}', style: st(10)),
            pw.Text('Cajero: ${data.cashierName}', style: st(10)),
            pw.Text('Caja: ${data.cashRegister}', style: st(10)),
            pw.Text('Barbero: ${data.barberName}', style: st(10)),
            pw.SizedBox(height: 4),
            pw.Text(dash, style: st(10), textAlign: pw.TextAlign.center),
            pw.SizedBox(height: 4),

            pw.Row(children: [
              pw.Expanded(child: pw.Text('Cant  Descripcion', style: st(10))),
              pw.Text('Total', style: st(10)),
            ]),
            pw.SizedBox(height: 2),
            ...data.items.map((it) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Row(children: [
                    pw.Expanded(child: pw.Text(it.name, style: st(10))),
                    pw.Text(fmt(it.total), style: st(10)),
                  ]),
                  // ANTES era gris -> ahora negro Bold, por eso se veia lavado
                  pw.Text('  ${it.qty} x ${fmt(it.price)}', style: st(9)),
                  pw.SizedBox(height: 1),
                ],
              );
            }),
            pw.SizedBox(height: 4),
            pw.Text(dash, style: st(10), textAlign: pw.TextAlign.center),
            pw.SizedBox(height: 4),

            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('Subtotal', style: st(10)),
              pw.Text(fmt(data.subtotal), style: st(10)),
            ]),
            if (data.discount > 0) ...[
              pw.SizedBox(height: 2),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('Descuento', style: st(10)),
                pw.Text('- ${fmt(data.discount)}', style: st(10)),
              ]),
            ],
            pw.SizedBox(height: 4),
            pw.Text(dash, style: st(10), textAlign: pw.TextAlign.center),
            pw.SizedBox(height: 4),
            // TOTAL mas grande y mas negro
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('TOTAL', style: st(14)),
              pw.Text(fmt(data.total), style: st(14)),
            ]),
            pw.SizedBox(height: 4),
            pw.Text(dash, style: st(10), textAlign: pw.TextAlign.center),
            pw.SizedBox(height: 4),

            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('Forma de pago:', style: st(10)),
              pw.Text(data.paymentLabel, style: st(10)),
            ]),
            if (data.mixedPayments != null && data.mixedPayments!.isNotEmpty)
              ...data.mixedPayments!.map((p) => pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 1),
                    child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                      pw.Text('  ${labelForMethod((p['method'] ?? '').toString())}:', style: st(9.5)),
                      pw.Text(fmt((p['amount'] as num).toDouble()), style: st(9.5)),
                    ]),
                  )),
            if (data.cashReceived != null && data.cashReceived! > 0)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 1),
                child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text('Recibido:', style: st(10)),
                  pw.Text(fmt(data.cashReceived!), style: st(10)),
                ]),
              ),
            if (data.change != null && data.change! > 0)
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('Vuelto:', style: st(10)),
                pw.Text(fmt(data.change!), style: st(10)),
              ]),
            pw.SizedBox(height: 6),
            pw.Text(dash, style: st(10), textAlign: pw.TextAlign.center),
            pw.SizedBox(height: 6),

            pw.Text(data.footer, style: st(9.5), textAlign: pw.TextAlign.center),
            pw.SizedBox(height: 4),
            // ANTES gris -> ahora negro Bold
            pw.Text(DateFormat('dd-MM-yyyy, h:mm:ss a').format(data.date), style: st(8.5), textAlign: pw.TextAlign.center),
            pw.SizedBox(height: 10),
            pw.Text('', style: st(4)),
          ],
        ),
      ),
    );
    return pdf.save();
  }

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
