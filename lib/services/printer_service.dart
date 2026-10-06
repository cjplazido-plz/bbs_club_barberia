import 'dart:typed_data';
import 'dart:ui' as ui;
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
      
      final logoUrl = SettingsService.ticketLogoUrl.isNotEmpty
          ? SettingsService.ticketLogoUrl
          : SettingsService.shopLogoUrl;

      pw.MemoryImage? logoImage;
      if (logoUrl.isNotEmpty) {
        try {
          final response = await http.get(Uri.parse(logoUrl));
          if (response.statusCode == 200) {
            // Procesar imagen: convertir a 1-bit (blanco y negro puro)
            final processedBytes = await _convertTo1Bit(response.bodyBytes);
            if (processedBytes != null) {
              logoImage = pw.MemoryImage(processedBytes);
            }
          }
        } catch (e) {
          print('️ Error al procesar logo: $e');
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
                  pw.Center(
                    child: pw.Container(
                      width: 70,
                      height: 70,
                      color: PdfColors.white,
                      child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                    ),
                  ),
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

  // ✅ FUNCIÓN: Convertir imagen a 1-bit (blanco y negro puro)
  Future<Uint8List?> _convertTo1Bit(Uint8List imageBytes) async {
    try {
      // Decodificar la imagen
      final codec = await ui.instantiateImageCodec(imageBytes);
      final firstFrame = await codec.getNextFrame(); // ✅ RENOMBRADO
      final image = firstFrame.image;
      
      // Redimensionar si es necesario (max 384px de ancho para impresora 80mm)
      int width = image.width;
      int height = image.height;
      if (width > 384) {
        height = (384 * height / width).round();
        width = 384;
      }
      
      // Crear un canvas para redimensionar y procesar
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final paint = ui.Paint();
      
      // Dibujar imagen redimensionada
      canvas.drawImageRect(
        image,
        ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
        paint,
      );
      
      final picture = recorder.endRecording();
      final processedImage = await picture.toImage(width, height);
      final byteData = await processedImage.toByteData();
      
      if (byteData == null) return null;
      
      // Aplicar threshold manualmente (pixel por pixel)
      final bytes = byteData.buffer.asUint8List();
      final resultBytes = Uint8List(bytes.length);
      
      for (int i = 0; i < bytes.length; i += 4) {
        final r = bytes[i];
        final g = bytes[i + 1];
        final b = bytes[i + 2];
        
        // Calcular luminosidad (fórmula estándar)
        final luminance = 0.299 * r + 0.587 * g + 0.114 * b;
        
        // Aplicar threshold: < 128 = negro (0), >= 128 = blanco (255)
        final value = luminance < 128 ? 0 : 255;
        
        resultBytes[i] = value;     // R
        resultBytes[i + 1] = value; // G
        resultBytes[i + 2] = value; // B
        resultBytes[i + 3] = 255;   // Alpha (opaque)
      }
      
      // Crear la imagen final en blanco y negro
      final finalRecorder = ui.PictureRecorder();
      final finalCanvas = ui.Canvas(finalRecorder);
      
      // Crear datos de píxeles
      final imageData = ui.ImageDescriptor.raw(
        await ui.ImmutableBuffer.fromUint8List(resultBytes),
        width: width,
        height: height,
        pixelFormat: ui.PixelFormat.rgba8888,
      );
      
      final bitmap = await imageData.instantiateCodec();
      final secondFrame = await bitmap.getNextFrame(); // ✅ RENOMBRADO
      final finalImage = secondFrame.image;
      
      finalCanvas.drawImage(finalImage, ui.Offset.zero, paint);
      final finalPicture = finalRecorder.endRecording();
      final finalUiImage = await finalPicture.toImage(width, height);
      
      // Codificar como PNG (simplificado para web)
      final pngBytes = await _encodeToPng(finalUiImage);
      return pngBytes;
      
    } catch (e) {
      print('❌ Error al convertir a 1-bit: $e');
      return imageBytes; // Retornar original si falla
    }
  }

  // Helper para codificar a PNG
  Future<Uint8List> _encodeToPng(ui.Image image) async {
    final byteData = await image.toByteData();
    return byteData!.buffer.asUint8List();
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