// lib/services/printer_windows.dart - VERSION BOLD / MAS NEGRO PARA TERMICA 80mm
// ANTES: solo encabezado y TOTAL en bold, el resto normal -> salia lavado.
// AHORA: TODO en bold:true. En termica el bold es lo que le da negro.
// Ademas: Subtotal, Pago, Recibido, Vuelto y pie tambien en bold.
// Lineas: hr() con '-' y '=' para que salgan mas marcadas.
// Si tu impresora tiene ajuste de densidad / oscuridad, dejalo en Alto / 3.
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

  // Estilo base BOLD para TODO - esto es lo que le da negro a la termica
  static const _bold = esc.PosTextStyle(bold: true, align: esc.PosAlign.left);
  static const _boldCenter = esc.PosTextStyle(bold: true, align: esc.PosAlign.center);
  static const _boldRight = esc.PosTextStyle(bold: true, align: esc.PosAlign.right);

  static Future<void> printTicket(LocalTransaction trx, {bool isReprint = false, String? clientName, String? barberName}) async {
    try {
      final profile = await esc.CapabilityProfile.load();
      final generator = esc.Generator(
        trx.ticketAncho == '58mm' ? esc.PaperSize.mm58 : esc.PaperSize.mm80,
        profile,
      );
      List<int> bytes = [];

      // LOGO - igual que antes
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
        } catch (e) {
          print('Logo print error $e');
        }
      }

      // ENCABEZADO - todo Bold, doble tamano para nombre
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

      // DATOS - todos Bold
      final barber = (barberName ?? '').isNotEmpty ? barberName! : (trx.items.isNotEmpty ? (trx.items.first.barberName ?? '') : '');
      final client = (clientName ?? '').isNotEmpty ? clientName! : 'Consumidor Final';
      bytes += generator.text('Folio: ${trx.folio?.isNotEmpty == true ? trx.folio : trx.remoteId ?? ''}', styles: _bold);
      bytes += generator.text('Fecha: ${DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now())}', styles: _bold);
      bytes += generator.text('Cliente: $client', styles: _bold);
      bytes += generator.text('Cajero: ${trx.cashierName ?? ''}', styles: _bold);
      bytes += generator.text('Caja: ${trx.cashRegisterId ?? ''}', styles: _bold);
      bytes += generator.text('Barbero: $barber', styles: _bold);
      bytes += generator.text('--------------------------------', styles: _boldCenter);
      bytes += generator.text('Cant  Descripcion          Total', styles: _bold);

      for (var it in trx.items) {
        final name = (it.type == 'service' ? it.serviceName : it.productName).toString();
        final qty = it.quantity as int;
        final price = it.priceAtMoment as double;
        final total = price * qty;
        // Nombre en Bold
        bytes += generator.row([
          esc.PosColumn(text: name.length > 24 ? name.substring(0, 24) : name, width: 8, styles: const esc.PosTextStyle(bold: true)),
          esc.PosColumn(text: _fmt(total), width: 4, styles: const esc.PosTextStyle(bold: true, align: esc.PosAlign.right)),
        ]);
        bytes += generator.text('  $qty x ${_fmt(price)}', styles: _bold);
      }

      bytes += generator.text('--------------------------------', styles: _boldCenter);
      // SUBTOTAL en Bold (antes era normal)
      bytes += generator.row([
        esc.PosColumn(text: 'Subtotal', width: 6, styles: const esc.PosTextStyle(bold: true)),
        esc.PosColumn(text: _fmt(trx.subtotal), width: 6, styles: const esc.PosTextStyle(bold: true, align: esc.PosAlign.right)),
      ]);
      bytes += generator.text('--------------------------------', styles: _boldCenter);
      // TOTAL mas grande + Bold
      bytes += generator.text('TOTAL: ${_fmt(trx.total)}',
          styles: const esc.PosTextStyle(bold: true, height: esc.PosTextSize.size2, width: esc.PosTextSize.size1, align: esc.PosAlign.right));
      bytes += generator.text('--------------------------------', styles: _boldCenter);

      // PAGO - todo Bold
      bytes += generator.text('Forma de pago: ${_labelPago(trx.paymentMethod)}', styles: _bold);
      if ((trx.cashReceived as double) > 0) {
        bytes += generator.text('Recibido: ${_fmt(trx.cashReceived as double)}', styles: _bold);
        bytes += generator.text('Vuelto: ${_fmt(trx.changeAmount as double)}', styles: _bold);
      }
      bytes += generator.text('================================', styles: _boldCenter);
      bytes += generator.text(TicketConfigService.mensaje, styles: _boldCenter);
      bytes += generator.text(DateFormat('dd-MM-yyyy, h:mm:ss a').format(DateTime.now()), styles: _boldCenter);
      bytes += generator.feed(1);
      bytes += generator.cut();

      const channel = MethodChannel('com.bbsclub.printer');
      try {
        await channel.invokeMethod('printBytes', {'bytes': bytes});
      } catch (_) {
        print('Print channel not found - bytes len ${bytes.length}');
      }
    } catch (e) {
      print('PrinterWindows error $e');
      rethrow;
    }
  }

  // Para Historial / Reimpresion: mismo formato pero con marca REIMPRESION
  static Future<void> printReprint(LocalTransaction trx, {String? clientName, String? barberName}) async {
    return printTicket(trx, isReprint: true, clientName: clientName, barberName: barberName);
  }
}

extension TicketAnchoExt on LocalTransaction {
  String get ticketAncho => TicketConfigService.ancho;
}
