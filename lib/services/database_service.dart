import 'dart:io';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/local_barber.dart';
import '../models/local_client.dart';
import '../models/local_service.dart';
import '../models/local_product.dart';
import '../models/local_appointment.dart';
import '../models/local_transaction.dart';

class DatabaseService {
  static Isar? _isar;
  
  static Isar get isar {
    if (_isar == null) {
      throw Exception('Isar no ha sido inicializado. Llama a DatabaseService.init() primero.');
    }
    return _isar!;
  }

  static Future<void> init() async {
    // Obtener directorio de la aplicación
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = dir.path;
    
    // Crear directorio si no existe
    final dbDir = Directory(dbPath);
    if (!await dbDir.exists()) {
      await dbDir.create(recursive: true);
    }
    
    print('📁 Ruta de base de datos: $dbPath');
    
    _isar = await Isar.open(
      [
        LocalBarberSchema,
        LocalClientSchema,
        LocalServiceSchema,
        LocalProductSchema,
        LocalAppointmentSchema,
        LocalTransactionSchema,
      ],
      directory: dbPath,
    );
    
    print('✅ Isar inicializado correctamente');
  }
}