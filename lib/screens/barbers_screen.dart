import 'package:flutter/material.dart';
import '../models/local_barber.dart';
import '../repositories/barber_repository.dart';

class BarbersScreen extends StatefulWidget {
  @override
  State<BarbersScreen> createState() => _BarbersScreenState();
}

class _BarbersScreenState extends State<BarbersScreen> {
  final _barberRepo = BarberRepository();
  List<LocalBarber> _barbers = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadBarbers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<LocalBarber> get _filteredBarbers {
    if (_searchQuery.trim().isEmpty) return _barbers;
    final q = _searchQuery.trim().toLowerCase();
    return _barbers.where((b) => b.name.toLowerCase().contains(q)).toList();
  }

  Future<void> _loadBarbers() async {
    setState(() { _isLoading = true; });
    final barbers = await _barberRepo.getAllBarbers();
    setState(() {
      _barbers = barbers;
      _isLoading = false;
    });
  }

  void _showBarberDialog({LocalBarber? barber}) {
    final nameController = TextEditingController(text: barber?.name ?? '');
    bool isActive = barber?.isActive ?? true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(barber == null ? 'Nuevo Barbero' : 'Editar Barbero'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nombre *')),
                const SizedBox(height: 8),
                SwitchListTile(
                  value: isActive,
                  activeColor: const Color(0xFF6366F1),
                  title: const Text('Barbero activo'),
                  subtitle: const Text('Si se desactiva, no aparecerá en el POS'),
                  onChanged: (v) => setDialogState(() => isActive = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El nombre es obligatorio'), backgroundColor: Colors.red));
                  return;
                }
                final newBarber = LocalBarber()
                  ..remoteId = barber?.remoteId ?? 'bar-${DateTime.now().millisecondsSinceEpoch}'
                  ..name = nameController.text.trim()
                  ..isActive = isActive;
                if (barber == null) {
                  await _barberRepo.createBarber(newBarber);
                } else {
                  await _barberRepo.updateBarber(newBarber);
                }
                Navigator.pop(context);
                await _loadBarbers();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(barber == null ? 'Barbero creado' : 'Barbero actualizado'), backgroundColor: Colors.green));
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteBarber(LocalBarber barber) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text('¿Eliminar a ${barber.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirm == true) {
      await _barberRepo.deleteBarber(barber.remoteId!);
      await _loadBarbers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Barbero eliminado'), backgroundColor: Colors.orange));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _filteredBarbers;
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.badge_outlined, size: 22),
            SizedBox(width: 8),
            Expanded(child: Text('Gestión de Barberos', overflow: TextOverflow.ellipsis)),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                hintText: 'Buscar barbero por nombre...',
                hintStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[500], fontSize: 13),
                prefixIcon: Icon(Icons.search, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(icon: Icon(Icons.clear, color: isDark ? Colors.grey[400] : Colors.grey[600]), onPressed: () { _searchController.clear(); setState(() => _searchQuery = ''); })
                    : null,
                filled: true,
                fillColor: isDark ? const Color(0xFF334155) : Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF6366F1))),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.badge_outlined, size: 64, color: isDark ? Colors.grey[600] : Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(_searchQuery.isNotEmpty ? 'Sin resultados para "$_searchQuery"' : 'No hay barberos registrados', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[400], fontSize: 16)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final barber = filtered[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              leading: CircleAvatar(
                                backgroundColor: barber.isActive
                                    ? (isDark ? const Color(0xFF312E81) : Colors.indigo[100])
                                    : (isDark ? const Color(0xFF374151) : Colors.grey[300]),
                                child: Text(
                                  barber.name.isNotEmpty ? barber.name[0].toUpperCase() : '?',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF818CF8) : Colors.indigo[700]),
                                ),
                              ),
                              title: Text(
                                barber.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : Colors.black87),
                              ),
                              subtitle: Text(
                                barber.isActive ? 'Barbero activo' : 'INACTIVO',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: barber.isActive ? FontWeight.normal : FontWeight.w700,
                                  color: barber.isActive ? (isDark ? Colors.grey[400] : Colors.grey[600]) : (isDark ? Colors.red[300] : Colors.red[700]),
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(icon: const Icon(Icons.edit, color: Colors.amber, size: 20), onPressed: () => _showBarberDialog(barber: barber)),
                                  IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20), onPressed: () => _deleteBarber(barber)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showBarberDialog(),
        backgroundColor: const Color(0xFF6366F1),
        child: const Icon(Icons.add),
      ),
    );
  }
}