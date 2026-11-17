// printer_service.dart - ACTUALIZADO A FORMATO EASTON
// Antes: tenia su propio PDF con Helvetica + Divider (formato viejo).
// Ahora: SOLO delega a ticket_easton.dart. Asi POS, Historial y cualquier
// pantalla que llame a PrinterService.printTicket imprimen IGUAL.
// No hay dos formatos dando vuelta.

import 'package:printing/printing.dart';
import '../models/local_transaction.dart';
import 'settings_service.dart';
import 'ticket_easton.dart';

class PrinterService {
  // Compatibilidad: POS lo llama como printTicket(transaction)
  // Historial puede llamarlo con isReprint: true
  Future<void> printTicket(
    LocalTransaction transaction, {
    String? clientName,
    String? barberName,
    List<Map<String, dynamic>>? mixedPayments,
    double discount = 0,
    bool isReprint = false,
    DateTime? date,
  }) async {
    final String barber = (barberName ?? '').trim().isNotEmpty
        ? barberName!
        : (transaction.items.isNotEmpty ? transaction.items.first.barberName : '');
    final String client = (clientName ?? '').trim().isNotEmpty ? clientName! : 'Consumidor Final';

    final data = EastonTicketData(
      shopName: SettingsService.shopName.isNotEmpty ? SettingsService.shopName : 'BBS CLUB BARBERIA',
      shopRif: SettingsService.shopRif,
      shopAddress: SettingsService.shopAddress,
      shopPhone: SettingsService.shopPhone,
      folio: (transaction.folio ?? '').isNotEmpty ? transaction.folio! : transaction.remoteId,
      date: date ?? DateTime.now(),
      clientName: client,
      cashierName: transaction.cashierName.isNotEmpty ? transaction.cashierName : 'N/A',
      cashRegister: transaction.cashRegisterId.isNotEmpty ? transaction.cashRegisterId : 'N/A',
      barberName: barber.isEmpty ? 'Sin asignar' : barber,
      items: transaction.items.map((it) => EastonTicketItem(
        name: it.serviceName.isNotEmpty ? it.serviceName : (it.productName ?? 'Item'),
        qty: it.quantity,
        price: it.priceAtMoment,
      )).toList(),
      subtotal: transaction.subtotal,
      discount: discount,
      total: transaction.total,
      paymentLabel: EastonTicket.labelForMethod(transaction.paymentMethod),
      cashReceived: transaction.cashReceived,
      change: transaction.changeAmount,
      mixedPayments: mixedPayments,
      footer: SettingsService.ticketFooter.isNotEmpty ? SettingsService.ticketFooter : '¡Gracias por su visita!',
      isReprint: isReprint,
      logoUrl: SettingsService.ticketLogoUrl.isNotEmpty ? SettingsService.ticketLogoUrl : SettingsService.shopLogoUrl,
    );

    final bytes = await EastonTicket.build(data: data);
    final prefix = isReprint ? 'Reimpresion_Ticket' : 'Ticket';
    await Printing.sharePdf(bytes: bytes, filename: '${prefix}_${data.folio}');
  }
}
