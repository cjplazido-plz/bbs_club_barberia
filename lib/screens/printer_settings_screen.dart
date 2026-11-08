import 'package:flutter/material.dart';
import '../services/printer_service.dart';
import '../services/printer_interface.dart';

class PrinterSettingsScreen extends StatefulWidget {
  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  final PrinterService _printer = PrinterService();
  MyPrinterType _selectedType = MyPrinterType.network;
  int _paperSize = 80;
  final _ipController = TextEditingController(text: '192.168.1.50');
  final _portController = TextEditingController(text: '9100');
  final _nameController = TextEditingController(text: 'XPrinter 80mm');
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final dev = _printer.connectedDevice;
    if (dev != null) {
      setState(() {
        _nameController.text = dev.name;
        _ipController.text = dev.ip ?? '192.168.1.50';
        _portController.text = dev.port ?? '9100';
        _selectedType = dev.type;
      });
    }
    setState(() {
      _paperSize = _printer.paperSize;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await _printer.setPaperSize(_paperSize);
    final device = PrinterDeviceInfo(
      name: _nameController.text.trim().isEmpty ? 'XPrinter ${_paperSize}mm' : _nameController.text.trim(),
      type: _selectedType,
      ip: _ipController.text.trim(),
      port: _portController.text.trim(),
      address: _ipController.text.trim(),
    );
    final ok = await _printer.connectPrinter(device);
    setState(() => _saving = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? '✅ Guardado: ${device.name} ${_paperSize}mm ${device.ip}:${device.port}' : '⚠️ Guardado pero sin conexión'),
      backgroundColor: ok ? const Color(0xFF10B981) : Colors.orange,
    ));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final connected = _printer.isConnected;
    final dev = _printer.connectedDevice;
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(backgroundColor: const Color(0xFF1E293B), title: Text('🖨️ Impresora ${_paperSize}mm - FIX Corte', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)), leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white), onPressed: () => Navigator.pop(context))),
      body: SingleChildScrollView(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (connected && dev != null)
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4))), child: Row(children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Conectado: ${dev.name}', style: const TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold)),
              Text('${dev.type.name.toUpperCase()} - ${dev.ip ?? ''}:${dev.port ?? '9100'} - Papel ${_paperSize}mm', style: const TextStyle(color: Colors.white70, fontSize: 10)),
            ])),
            IconButton(icon: const Icon(Icons.delete_rounded, color: Colors.white38, size: 18), onPressed: () async { await _printer.disconnectPrinter(); setState(() {}); }),
          ])),

        const SizedBox(height: 14),
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Tamaño de Papel (según tu rollo)', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(children: [
            _paperChip(58, '58mm (corto)'),
            const SizedBox(width: 8),
            _paperChip(80, '80mm (ancho)'),
          ]),
          const SizedBox(height: 4),
          Text('Tu foto muestra corte a la derecha - si tu rollo es angosto usa 58mm. Si es ancho 80mm pero se corta, deja 80mm y este fix usa fuente pequeña.', style: TextStyle(color: _paperSize == 58 ? Colors.orange : Colors.white38, fontSize: 9)),
          const SizedBox(height: 14),
          const Text('Tipo Conexión', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(children: [_typeChip(MyPrinterType.network, '📶 Network WiFi'), const SizedBox(width: 8), _typeChip(MyPrinterType.usb, '🔌 USB')]),
          const SizedBox(height: 14),
          TextField(controller: _nameController, style: const TextStyle(color: Colors.white, fontSize: 12), decoration: InputDecoration(labelText: 'Nombre', labelStyle: const TextStyle(color: Colors.white38, fontSize: 10), filled: true, fillColor: const Color(0xFF0F172A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10))),
          const SizedBox(height: 10),
          if (_selectedType == MyPrinterType.network)
            Row(children: [
              Expanded(flex: 3, child: TextField(controller: _ipController, style: const TextStyle(color: Colors.white, fontSize: 12), decoration: InputDecoration(labelText: 'IP Ej: 192.168.1.50', labelStyle: const TextStyle(color: Colors.white38, fontSize: 10), filled: true, fillColor: const Color(0xFF0F172A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10)))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: _portController, style: const TextStyle(color: Colors.white, fontSize: 12), decoration: InputDecoration(labelText: 'Puerto', labelStyle: const TextStyle(color: Colors.white38, fontSize: 10), filled: true, fillColor: const Color(0xFF0F172A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10)))),
            ]),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _saving ? null : _save, icon: _saving ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_rounded, size: 16), label: Text(_saving ? 'Guardando...' : 'Guardar Config ${_paperSize}mm', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 12)))),
        ])),
        const SizedBox(height: 20),
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3))), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('✅ Fix para tu foto:', style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold)),
          SizedBox(height: 6),
          Text('• Antes usaba size2 en TOTAL -> ocupaba doble ancho y cortaba $12.000 a $12.0\n• Ahora usa fontB pequeña + 8/4 columnas + nombres recortados a 24 chars en 58mm\n• Logo reducido a 180px en 58mm para no desplazar\n• Si tu rollo físico es 58mm, selecciona 58mm arriba', style: TextStyle(color: Colors.white70, fontSize: 10)),
        ])),
      ])),
    );
  }

  Widget _paperChip(int mm, String label) {
    final sel = _paperSize == mm;
    return InkWell(onTap: () => setState(() => _paperSize = mm), child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: sel ? const Color(0xFF10B981) : const Color(0xFF0F172A), borderRadius: BorderRadius.circular(20), border: Border.all(color: sel ? const Color(0xFF10B981) : Colors.white10)), child: Text(label, style: TextStyle(color: sel ? Colors.white : Colors.white54, fontSize: 11, fontWeight: FontWeight.bold))));
  }

  Widget _typeChip(MyPrinterType type, String label) {
    final sel = _selectedType == type;
    return InkWell(onTap: () => setState(() => _selectedType = type), child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: sel ? const Color(0xFF6366F1) : const Color(0xFF0F172A), borderRadius: BorderRadius.circular(20), border: Border.all(color: sel ? const Color(0xFF6366F1) : Colors.white10)), child: Text(label, style: TextStyle(color: sel ? Colors.white : Colors.white54, fontSize: 10, fontWeight: FontWeight.bold))));
  }
}
