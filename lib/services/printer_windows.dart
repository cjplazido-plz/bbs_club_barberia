// lib/services/printer_windows.dart - FINAL: BOLD + ALINEADO DERECHA + LINEAS
// Cambios: Folio/Fecha/Cliente/Cajero/Caja/Barbero ahora van en 2 columnas
// (etiqueta izq, valor der) con generator.row, como Easton.
// Y se agregaron lineas de separacion despues de TICKET y despues de datos.
import 'package:flutter/services.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils.dart' as esc;
import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../models/local_transaction.dart';
import 'ticket_config_service.dart';

class PrinterWindows {
  static String _fmt(double v) {
    final f = NumberFormat('#,##0', 'es_CL');
    return '\$ ${f.format(v.round())}';
  }
  static String _labelPago(String? m) {
    switch (m) {
      case 'cash': return 'Efectivo';
      case 'card': return 'Tarjeta';
      case 'transfer': return 'Transferencia';
      case 'mixed':
      case 'mixto': return 'Mixto';
      default: return m ?? 'Efectivo';
    }
  }
  static const _bold = esc.PosTextStyle(bold: true, align: esc.PosAlign.left);
  static const _boldCenter = esc.PosTextStyle(bold: true, align: esc.PosAlign.center);
  static const _boldRight = esc.PosTextStyle(bold: true, align: esc.PosAlign.right);

  static Future<void> printTicket(LocalTransaction trx, {bool isReprint = false, String? clientName, String? barberName}) async {
    try {
      final profile = await esc.CapabilityProfile.load();
      final generator = esc.Generator(trx.ticketAncho == '58mm' ? esc.PaperSize.mm58 : esc.PaperSize.mm80, profile);
      List<int> bytes = [];
      final logoUrl = TicketConfigService.ticketLogoUrl;
      if (logoUrl.isNotEmpty) {
        try {
          final resp = await http.get(Uri.parse(logoUrl)).timeout(const Duration(seconds: 5));
          if (resp.statusCode == 200) {
            final decoded = img.decodeImage(resp.bodyBytes);
            if (decoded != null) {
              final resized = img.copyResize(decoded, width: 300);
              bytes += generator.image(resized, align: esc.PosAlign.center);
            }
          }
        } catch (e) { print('Logo print error $e'); }
      }
      bytes += generator.text(TicketConfigService.nombreLocal,
          styles: const esc.PosTextStyle(align: esc.PosAlign.center, bold: true, height: esc.PosTextSize.size2, width: esc.PosTextSize.size2));
      bytes += generator.text('BBS CLUB BARBERIA SPA', styles: _boldCenter);
      bytes += generator.text('RUT: ${TicketConfigService.rut}', styles: _boldCenter);
      bytes += generator.text(TicketConfigService.direccion, styles: _boldCenter);
      bytes += generator.text('Tel: ${TicketConfigService.telefono}', styles: _boldCenter);
      bytes += generator.text('--------------------------------', styles: _boldCenter);
      bytes += generator.text('TICKET DE VENTA', styles: const esc.PosTextStyle(align: esc.PosAlign.center, bold: true, height: esc.PosTextSize.size2, width: esc.PosTextSize.size1));
      if (isReprint) {
        bytes += generator.text('*** REIMPRESION ***', styles: _boldCenter);
        bytes += generator.text('Copia - No valido como boleta', styles: _boldCenter);
      }
      // LINEA DE SEPARACION despues de TICKET / REIMPRESION
      bytes += generator.text('--------------------------------', styles: _boldCenter);

      // DATOS ALINEADOS A LA DERECHA - 2 columnas
      final barber = (barberName ?? '').isNotEmpty ? barberName! : (trx.items.isNotEmpty ? (trx.items.first.barberName ?? '') : '');
      final client = (clientName ?? '').isNotEmpty ? clientName! : 'Consumidor Final';
      List<List<String>> datos = [
        ['Folio', trx.folio?.isNotEmpty == true ? trx.folio! : (trx.remoteId ?? '')],
        ['Fecha', DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now())],
        ['Cliente', client],
        ['Cajero', trx.cashierName ?? ''],
        ['Caja', trx.cashRegisterId ?? ''],
        ['Barbero', barber],
      ];
      for (var d in datos) {
        bytes += generator.row([
          esc.PosColumn(text: d[0], width: 4, styles: const esc.PosTextStyle(bold: true)),
          esc.PosColumn(text: d[1], width: 8, styles: const esc.PosTextStyle(bold: true, align: esc.PosAlign.right)),
        ]);
      }
      // LINEA DE SEPARACION despues de datos
      bytes += generator.text('--------------------------------', styles: _boldCenter);
      bytes += generator.text('Cant  Descripcion          Total', styles: _bold);
      for (var it in trx.items) {
      bytes += generator.text('--------------------------------', styles: _boldCenter);
        
        final name = (it.type == 'service' ? it.serviceName : it.productName).toString();
        final qty = it.quantity as int;
        final price = it.priceAtMoment as double;
        final total = price * qty;
        bytes += generator.row([
          esc.PosColumn(text: name.length > 24 ? name.substring(0, 24) : name, width: 8, styles: const esc.PosTextStyle(bold: true)),
          esc.PosColumn(text: _fmt(total), width: 4, styles: const esc.PosTextStyle(bold: true, align: esc.PosAlign.right)),
        ]);
        bytes += generator.text('  $qty x ${_fmt(price)}', styles: _bold);
      }
      bytes += generator.text('--------------------------------', styles: _boldCenter);
      bytes += generator.row([
        esc.PosColumn(text: 'Subtotal', width: 6, styles: const esc.PosTextStyle(bold: true)),
        esc.PosColumn(text: _fmt(trx.subtotal), width: 6, styles: const esc.PosTextStyle(bold: true, align: esc.PosAlign.right)),
      ]);
      bytes += generator.text('--------------------------------', styles: _boldCenter);
      bytes += generator.text('TOTAL: ${_fmt(trx.total)}',
          styles: const esc.PosTextStyle(bold: true, height: esc.PosTextSize.size2, width: esc.PosTextSize.size1, align: esc.PosAlign.right));
      bytes += generator.text('--------------------------------', styles: _boldCenter);
      bytes += generator.row([
        esc.PosColumn(text: 'Forma de pago:', width: 6, styles: const esc.PosTextStyle(bold: true)),
        esc.PosColumn(text: _labelPago(trx.paymentMethod), width: 6, styles: const esc.PosTextStyle(bold: true, align: esc.PosAlign.right)),
      ]);
      if ((trx.cashReceived as double) > 0) {
        bytes += generator.row([
          esc.PosColumn(text: 'Recibido:', width: 6, styles: const esc.PosTextStyle(bold: true)),
          esc.PosColumn(text: _fmt(trx.cashReceived as double), width: 6, styles: const esc.PosTextStyle(bold: true, align: esc.PosAlign.right)),
        ]);
        bytes += generator.row([
          esc.PosColumn(text: 'Vuelto:', width: 6, styles: const esc.PosTextStyle(bold: true)),
          esc.PosColumn(text: _fmt(trx.changeAmount as double), width: 6, styles: const esc.PosTextStyle(bold: true, align: esc.PosAlign.right)),
        ]);
      }
      bytes += generator.text('================================', styles: _boldCenter);
      bytes += generator.text(TicketConfigService.mensaje, styles: _boldCenter);
      bytes += generator.text(DateFormat('dd-MM-yyyy, h:mm:ss a').format(DateTime.now()), styles: _boldCenter);
      bytes += generator.feed(1);
      bytes += generator.cut();
      const channel = MethodChannel('com.bbsclub.printer');
      try { await channel.invokeMethod('printBytes', {'bytes': bytes}); } catch (_) { print('Print channel not found - bytes len ${bytes.length}'); }
    } catch (e) { print('PrinterWindows error $e'); rethrow; }
  }
  static Future<void> printReprint(LocalTransaction trx, {String? clientName, String? barberName}) async {
    return printTicket(trx, isReprint: true, clientName: clientName, barberName: barberName);
  }
}
extension TicketAnchoExt on LocalTransaction {
  String get ticketAncho => TicketConfigService.ancho;
}
