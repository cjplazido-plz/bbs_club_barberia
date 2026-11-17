// lib/services/printer_web.dart - VERSION BOLD / MAS NEGRO
// ANTES: dibujaba su propio PDF con Helvetica normal + Divider y grises -> salia lavado.
// AHORA: solo delega a ticket_easton.dart (todo Courier Bold + negro puro).
// Asi Web, POS y Historial imprimen IDENTICO.
import 'package:printing/printing.dart';
import '../models/local_transaction.dart';
import '../services/settings_service.dart';
import 'printer_interface.dart';
import 'ticket_easton.dart';

class PrinterService implements IPrinterService {
  @override
  Future<void> printTicket(LocalTransaction tr) async {
    final barber = tr.items.isNotEmpty ? (tr.items.first.barberName ?? '').toString() : '';
    final data = EastonTicketData(
      shopName: SettingsService.shopName.isNotEmpty ? SettingsService.shopName : 'BBS CLUB BARBERIA',
      shopRif: SettingsService.shopRif,
      shopAddress: SettingsService.shopAddress,
      shopPhone: SettingsService.shopPhone,
      folio: (tr.folio ?? '').isNotEmpty ? tr.folio! : tr.remoteId,
      date: DateTime.now(),
      clientName: 'Consumidor Final',
      cashierName: (tr.cashierName ?? 'Sistema').toString(),
      cashRegister: tr.cashRegisterId.isNotEmpty ? tr.cashRegisterId : 'N/A',
      barberName: barber.isEmpty ? 'Sin asignar' : barber,
      items: tr.items.map((it) => EastonTicketItem(
        name: it.serviceName.isNotEmpty ? it.serviceName : (it.productName ?? 'Item'),
        qty: it.quantity,
        price: it.priceAtMoment,
      )).toList(),
      subtotal: tr.subtotal,
      discount: 0,
      total: tr.total,
      paymentLabel: EastonTicket.labelForMethod(tr.paymentMethod),
      cashReceived: tr.cashReceived,
      change: tr.changeAmount,
      footer: SettingsService.ticketFooter.isNotEmpty ? SettingsService.ticketFooter : '¡Gracias por su visita!',
      isReprint: false,
      logoUrl: SettingsService.ticketLogoUrl.isNotEmpty ? SettingsService.ticketLogoUrl : SettingsService.shopLogoUrl,
    );
    final bytes = await EastonTicket.build(data: data);
    await Printing.layoutPdf(onLayout: (_) async => bytes, name: 'Ticket_${data.folio}');
  }

  @override
  Future<void> printTicketFromMap(Map<String, dynamic> transaction, List<Map<String, dynamic>> items) async {
    final data = EastonTicket.fromHistory(
      transaction: transaction,
      items: items,
      shopName: SettingsService.shopName.isNotEmpty ? SettingsService.shopName : 'BBS CLUB BARBERIA',
      shopRif: SettingsService.shopRif,
      shopAddress: SettingsService.shopAddress,
      shopPhone: SettingsService.shopPhone,
      footer: SettingsService.ticketFooter.isNotEmpty ? SettingsService.ticketFooter : '¡Gracias por su visita!',
      logoUrl: SettingsService.ticketLogoUrl.isNotEmpty ? SettingsService.ticketLogoUrl : SettingsService.shopLogoUrl,
      isReprint: true,
    );
    final bytes = await EastonTicket.build(data: data);
    await Printing.layoutPdf(onLayout: (_) async => bytes, name: 'Reimpresion_Ticket_${data.folio}');
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
