import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:http/http.dart' as http;
import '../models/local_transaction.dart';
import '../services/settings_service.dart';

class PrinterService {
  Future<bool> printTicket(LocalTransaction transaction) async {
    try {
      print('🖨️ Generando ticket...');
      final pdf = pw.Document();
      
      // ✅ USAR logo específico para ticket, o el logo principal si no hay
      final logoUrl = SettingsService.ticketLogoUrl.isNotEmpty 
          ? SettingsService.ticketLogoUrl 
          : SettingsService.shopLogoUrl;

      pw.MemoryImage? logoImage;
      if (logoUrl.isNotEmpty) {
        try {
          final response = await http.get(Uri.parse(logoUrl));
          if (response.statusCode == 200) {
            logoImage = pw.MemoryImage(response.bodyBytes);
          }
        } catch (e) {
          print('⚠️ Error al descargar logo: $e');
        }
      }

      final pageFormat = PdfPageFormat(66 * PdfPageFormat.mm, 200 * PdfPageFormat.mm);
      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.only(left: 2, right: 2, top: 2, bottom: 2),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (logoImage != null)
                  pw.Center(child: pw.Container(width: 70, height: 70, child: pw.Image(logoImage, fit: pw.BoxFit.contain))),
                pw.SizedBox(height: 3),
                pw.Center(child: pw.Text(SettingsService.ticketHeader, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold))),
                pw.SizedBox(height: 2),
                if (SettingsService.shopRif.isNotEmpty) pw.Center(child: pw.Text('RUT: ${SettingsService.shopRif}', style: pw.TextStyle(fontSize: 9))),
                if (SettingsService.shopAddress.isNotEmpty) pw.Center(child: pw.Text(SettingsService.shopAddress, style: pw.TextStyle(fontSize: 9))),
                if (SettingsService.shopPhone.isNotEmpty) pw.Center(child: pw.Text('Tel: ${SettingsService.shopPhone}', style: pw.TextStyle(fontSize: 9))),
                pw.SizedBox(height: 2),
                pw.Divider(),
                pw.SizedBox(height: 2),
                pw.Center(child: pw.Text('ID: ${transaction.remoteId ?? 'N/A'}', style: pw.TextStyle(fontSize: 9))),
                pw.Center(child: pw.Text('Fecha: ${_formatDate(transaction.createdAt)}', style: pw.TextStyle(fontSize: 9))),
                pw.Center(child: pw.Text('Cajero: ${transaction.cashierName}', style: pw.TextStyle(fontSize: 9))),
                pw.SizedBox(height: 2),
                pw.Divider(),
                pw.SizedBox(height: 2),
                pw.Text('ITEMS:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 2),
                ...transaction.items.map((item) {
                  final name = item.type == 'service' ? item.serviceName : (item.productName ?? 'Producto');
                  final icon = item.type == 'service' ? '*' : '-';
                  final priceText = '${SettingsService.formatCurrency(item.priceAtMoment)} x${item.quantity} = ${SettingsService.formatCurrency(item.priceAtMoment * item.quantity)}';
                  
                  return pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('$icon $name', style: pw.TextStyle(fontSize: 7)),
                      pw.Container(
                        alignment: pw.Alignment.centerRight,
                        child: pw.Text(priceText, style: pw.TextStyle(fontSize: 10)),
                      ),
                      if (item.type == 'service' && item.barberName.isNotEmpty)
                        pw.Text('Barbero: ${item.barberName}', style: pw.TextStyle(fontSize: 10)),
                      pw.SizedBox(height: 2),
                    ],
                  );
                }),
                pw.Divider(),
                pw.SizedBox(height: 2),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text('Subtotal:', style: pw.TextStyle(fontSize: 10)),
                  pw.Text(SettingsService.formatCurrency(transaction.subtotal), style: pw.TextStyle(fontSize: 10)),
                ]),
                pw.SizedBox(height: 2),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text('TOTAL:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.Text(SettingsService.formatCurrency(transaction.total), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ]),
                pw.SizedBox(height: 2),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text('Pago:', style: pw.TextStyle(fontSize: 7)),
                  pw.Text(_formatPaymentMethod(transaction.paymentMethod), style: pw.TextStyle(fontSize: 7)),
                ]),
                if (transaction.paymentMethod == 'cash') ...[
                  pw.SizedBox(height: 2),
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                    pw.Text('Recibido:', style: pw.TextStyle(fontSize: 7)),
                    pw.Text(SettingsService.formatCurrency(transaction.cashReceived), style: pw.TextStyle(fontSize: 7)),
                  ]),
                  if (transaction.changeAmount > 0) ...[
                    pw.SizedBox(height: 2),
                    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                      pw.Text('Vuelto:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                      pw.Text(SettingsService.formatCurrency(transaction.changeAmount), style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    ]),
                  ],
                ],
                pw.SizedBox(height: 3),
                pw.Divider(),
                pw.SizedBox(height: 2),
                pw.Center(child: pw.Text(SettingsService.ticketFooter, style: pw.TextStyle(fontSize: 7, fontStyle: pw.FontStyle.italic))),
              ],
            );
          },
        ),
      );
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Ticket_${transaction.remoteId ?? 'venta'}.pdf',
      );
      print('✅ Ticket generado correctamente');
      return true;
    } catch (e) {
      print('❌ Error al generar ticket: $e');
      return false;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatPaymentMethod(String method) {
    switch (method) {
      case 'cash': return 'Efectivo';
      case 'card': return 'Tarjeta';
      case 'transfer': return 'Transferencia';
      default: return method;
    }
  }
}