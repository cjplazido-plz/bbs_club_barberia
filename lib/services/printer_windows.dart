// lib/services/printer_windows.dart - FINAL CON LOGO TICKET 80mm
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils.dart' as esc;
import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;
import '../models/local_transaction.dart';
import 'ticket_config_service.dart';

class PrinterWindows {
  static Future<void> printTicket(LocalTransaction trx) async {
    try {
      final profile = await esc.CapabilityProfile.load();
      final generator = esc.Generator(
        trx.ticketAncho == '58mm' ? esc.PaperSize.mm58 : esc.PaperSize.mm80,
        profile,
      );
      List<int> bytes = [];

      // LOGO TICKET - intenta descargar logo ticket B/N
      final logoUrl = TicketConfigService.ticketLogoUrl;
      if (logoUrl.isNotEmpty) {
        try {
          final resp = await http.get(Uri.parse(logoUrl)).timeout(const Duration(seconds: 5));
          if (resp.statusCode == 200) {
            final decoded = img.decodeImage(resp.bodyBytes);
            if (decoded != null) {
              // redimensionar max 300px ancho para 80mm
              final resized = img.copyResize(decoded, width: 300);
              bytes += generator.image(resized, align: esc.PosAlign.center);
            }
          }
        } catch (e) {
          print('Logo print error $e');
        }
      }

      bytes += generator.text(TicketConfigService.nombreLocal,
          styles: const esc.PosTextStyle(align: esc.PosAlign.center, bold: true, height: esc.PosTextSize.size2, width: esc.PosTextSize.size2));
      bytes += generator.text(TicketConfigService.direccion, styles: const esc.PosTextStyle(align: esc.PosAlign.center));
      bytes += generator.text('Tel: ${TicketConfigService.telefono}', styles: const esc.PosTextStyle(align: esc.PosAlign.center));
      bytes += generator.hr();
      bytes += generator.text('Folio: ${trx.remoteId ?? ''}', styles: const esc.PosTextStyle(bold: true));
      bytes += generator.text('Fecha: ${DateTime.now().toString().substring(0, 19)}');
      bytes += generator.text('Cajero: ${trx.cashierName ?? ''}');
      bytes += generator.hr();

      for (var it in trx.items) {
        final name = (it.type == 'service' ? it.serviceName : it.productName).toString();
        final qty = it.quantity as int;
        final price = it.priceAtMoment as double;
        final total = price * qty;
        bytes += generator.row([
          esc.PosColumn(text: '${qty}x ${name.length > 20 ? name.substring(0, 20) : name}', width: 8),
          esc.PosColumn(text: '\$${total.toStringAsFixed(0)}', width: 4, styles: const esc.PosTextStyle(align: esc.PosAlign.right)),
        ]);
      }

      bytes += generator.hr();
      bytes += generator.text('TOTAL: \$${(trx.total as double).toStringAsFixed(0)}',
          styles: const esc.PosTextStyle(bold: true, height: esc.PosTextSize.size2, align: esc.PosAlign.right));
      bytes += generator.text('Pago: ${trx.paymentMethod ?? ''}', styles: const esc.PosTextStyle(align: esc.PosAlign.right));
      if ((trx.cashReceived as double) > 0) {
        bytes += generator.text('Recibido: \$${(trx.cashReceived as double).toStringAsFixed(0)}', styles: const esc.PosTextStyle(align: esc.PosAlign.right));
        bytes += generator.text('Vuelto: \$${(trx.changeAmount as double).toStringAsFixed(0)}', styles: const esc.PosTextStyle(align: esc.PosAlign.right));
      }
      bytes += generator.hr(ch: '=');
      bytes += generator.text(TicketConfigService.mensaje, styles: const esc.PosTextStyle(align: esc.PosAlign.center));
      bytes += generator.cut();

      // EN WINDOWS: esc_pos_utils_plus imprime via método del plugin - aqui usamos MethodChannel o guardamos bytes
      // Para barberflow que usa printing via raw, enviamos a printer_windows nativo
      const channel = MethodChannel('com.bbsclub.printer');
      try {
        await channel.invokeMethod('printBytes', {'bytes': bytes});
      } catch (_) {
        // fallback: no hay canal, al menos no crashea - el ticket se genera en PDF con logo colores
        print('Print channel not found - bytes len ${bytes.length}');
      }
    } catch (e) {
      print('PrinterWindows error $e');
      rethrow;
    }
  }
}

extension TicketAnchoExt on LocalTransaction {
  String get ticketAncho => TicketConfigService.ancho;
}
