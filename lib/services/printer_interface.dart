// lib/services/printer_interface.dart
// Interfaz común para WEB y WINDOWS
import '../models/local_transaction.dart';

enum MyPrinterType { usb, network, bluetooth }

class PrinterDeviceInfo {
  final String name;
  final String? address;
  final String? vendorId;
  final String? productId;
  final MyPrinterType type;
  final String? ip;
  final String? port;
  PrinterDeviceInfo({
    required this.name,
    this.address,
    this.vendorId,
    this.productId,
    required this.type,
    this.ip,
    this.port,
  });
}

abstract class IPrinterService {
  Future<void> printTicket(LocalTransaction transaction);
  Future<void> printTicketFromMap(Map<String, dynamic> transaction, List<Map<String, dynamic>> items);
  Future<List<PrinterDeviceInfo>> scanPrinters({MyPrinterType type = MyPrinterType.usb});
  Future<bool> connectPrinter(PrinterDeviceInfo device);
  Future<bool> disconnectPrinter();
  bool get isConnected;
  PrinterDeviceInfo? get connectedDevice;
}
