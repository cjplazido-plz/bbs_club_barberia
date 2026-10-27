import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../services/settings_service.dart';

class CommissionsScreen extends StatefulWidget {
  @override
  State<CommissionsScreen> createState() => _CommissionsScreenState();
}

class _CommissionsScreenState extends State<CommissionsScreen> {
  bool _isLoading = true;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  List<Map<String, dynamic>> _commissions = [];
  double _totalCommissions = 0;
  double _totalSales = 0;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadCommissions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredCommissions {
    if (_searchQuery.trim().isEmpty) return _commissions;
    final q = _searchQuery.trim().toLowerCase();
    return _commissions.where((c) => (c['barber_name'] ?? '').toString().toLowerCase().contains(q)).toList();
  }

  Future<void> _loadCommissions() async {
    setState(() { _isLoading = true; });
    try {
      final startStr = _startDate.toIso8601String();
      final endStr = _endDate.add(const Duration(days: 1)).toIso8601String();
      final response = await Supabase.instance.client
          .from('transaction_items')
          .select('''
barber_id,
barber_name,
price_at_moment,
quantity,
commission_earned,
transactions!inner(created_at, status)
''')
          .eq('item_type', 'service')
          .gte('transactions.created_at', startStr)
          .lt('transactions.created_at', endStr)
          .eq('transactions.status', 'completed');
      final items = List<Map<String, dynamic>>.from(response);
      Map<String, Map<String, dynamic>> barberMap = {};
      for (final item in items) {
        final barberId = item['barber_id'] ?? 'unknown';
        final barberName = item['barber_name'] ?? 'Desconocido';
        final price = (item['price_at_moment'] as num?)?.toDouble() ?? 0.0;
        final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
        final commission = (item['commission_earned'] as num?)?.toDouble() ?? 0.0;
        final totalItem = price * quantity;
        if (!barberMap.containsKey(barberId)) {
          barberMap[barberId] = {
            'barber_id': barberId,
            'barber_name': barberName,
            'total_sales': 0.0,
            'total_commission': 0.0,
            'services_count': 0,
          };
        }
        barberMap[barberId]!['total_sales'] = (barberMap[barberId]!['total_sales'] as double) + totalItem;
        barberMap[barberId]!['total_commission'] = (barberMap[barberId]!['total_commission'] as double) + commission;
        barberMap[barberId]!['services_count'] = (barberMap[barberId]!['services_count'] as int) + quantity;
      }
      final commissions = barberMap.values.toList();
      commissions.sort((a, b) => (b['total_commission'] as double).compareTo(a['total_commission'] as double));
      setState(() {
        _commissions = commissions;
        _totalCommissions = commissions.fold(0.0, (sum, c) => sum + (c['total_commission'] as double));
        _totalSales = commissions.fold(0.0, (sum, c) => sum + (c['total_sales'] as double));
        _isLoading = false;
      });
    } catch (e) {
      print('Error al cargar comisiones: $e');
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _selectDateRange() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: isDark
              ? const ColorScheme.dark(primary: Color(0xFF6366F1), onPrimary: Colors.white, surface: Color(0xFF1E293B), onSurface: Colors.white, outline: Color(0xFF334155), onSurfaceVariant: Colors.white)
              : const ColorScheme.light(primary: Color(0xFF6366F1), onPrimary: Colors.white, surface: Colors.white, onSurface: Colors.black87),
          dialogBackgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        ),
        child: Localizations.override(context: context, child: child!),
      ),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadCommissions();
    }
  }

  void _setQuickFilter(String period) {
    final now = DateTime.now();
    DateTime start;
    switch (period) {
      case 'today': start = DateTime(now.year, now.month, now.day); break;
      case 'week': start = now.subtract(Duration(days: now.weekday - 1)); start = DateTime(start.year, start.month, start.day); break;
      case 'month': start = DateTime(now.year, now.month, 1); break;
      case 'last_month': start = DateTime(now.year, now.month - 1, 1); _endDate = DateTime(now.year, now.month, 0); break;
      default: start = now.subtract(const Duration(days: 30));
    }
    setState(() {
      _startDate = start;
      if (period != 'last_month') _endDate = now;
    });
    _loadCommissions();
  }

  bool _isPeriodSelected(String period) {
    final now = DateTime.now();
    switch (period) {
      case 'today': return _startDate.year == now.year && _startDate.month == now.month && _startDate.day == now.day;
      case 'week': final w = now.subtract(Duration(days: now.weekday - 1)); return _startDate.year == w.year && _startDate.month == w.month && _startDate.day == w.day;
      case 'month': return _startDate.year == now.year && _startDate.month == now.month && _startDate.day == 1;
      case 'last_month': return _startDate.year == now.year && _startDate.month == now.month - 1 && _startDate.day == 1;
      case 'last_30': final t = now.subtract(const Duration(days: 30)); return _startDate.year == t.year && _startDate.month == t.month && _startDate.day == t.day;
      default: return false;
    }
  }

  Widget _buildFilterChip(String label, String period) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _isPeriodSelected(period);
    return FilterChip(
      label: Text(label, style: TextStyle(fontSize: 12, color: isDark ? Colors.white : Colors.black87)),
      selected: isSelected,
      onSelected: (selected) => _setQuickFilter(period),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      selectedColor: isDark ? const Color(0xFF312E81) : Colors.indigo[100],
      checkmarkColor: isDark ? Colors.white : Colors.indigo[700],
      side: BorderSide(color: isDark ? Colors.grey[600]! : Colors.grey[300]!),
      labelStyle: TextStyle(
        color: isSelected ? (isDark ? Colors.white : Colors.indigo[700]) : (isDark ? Colors.grey[300] : Colors.black87),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildSummaryCards() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Expanded(
          child: Card(
            elevation: 2,
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Total Ventas', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey, fontSize: 12)),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(SettingsService.formatCurrency(_totalSales), maxLines: 1, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF818CF8) : Colors.blue)),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Card(
            elevation: 2,
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Total Comisiones', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey, fontSize: 12)),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(SettingsService.formatCurrency(_totalCommissions), maxLines: 1, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.green[300] : Colors.green)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ✅ FILA COMPACTA por barbero (igual estilo que Servicios/Productos)
  Widget _buildBarberRow(Map<String, dynamic> barber, int position) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barberName = barber['barber_name'] as String;
    final totalSales = barber['total_sales'] as double;
    final totalCommission = barber['total_commission'] as double;
    final servicesCount = barber['services_count'] as int;
    final commissionRate = totalSales > 0 ? (totalCommission / totalSales * 100) : 0.0;
    final medalColors = [const Color(0xFFFFD700), const Color(0xFFC0C0C0), const Color(0xFFCD7F32)];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: isDark ? const Color(0xFF312E81) : Colors.indigo[100],
          child: position <= 3
              ? Icon(Icons.emoji_events, size: 20, color: medalColors[position - 1])
              : Text('$position', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF818CF8) : Colors.indigo[700])),
        ),
        title: Text(barberName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : Colors.black87)),
        subtitle: Text(
          '$servicesCount servicios · ${commissionRate.toStringAsFixed(1)}% · Ventas ${SettingsService.formatCurrency(totalSales)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
        ),
        trailing: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(SettingsService.formatCurrency(totalCommission), maxLines: 1, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.green[300] : Colors.green[700])),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _filteredCommissions;
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.money, size: 22),
            SizedBox(width: 8),
            Expanded(child: Text('Comisiones por Barbero', overflow: TextOverflow.ellipsis)),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), tooltip: 'Actualizar', onPressed: _loadCommissions),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: isDark ? const Color(0xFF1E293B) : Colors.indigo[50],
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.date_range, size: 20, color: isDark ? const Color(0xFF818CF8) : Colors.indigo[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${DateFormat('dd/MM/yyyy').format(_startDate)} - ${DateFormat('dd/MM/yyyy').format(_endDate)}',
                          maxLines: 1,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black87),
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _selectDateRange,
                      icon: const Icon(Icons.calendar_month, size: 16),
                      label: const Text('Rango'),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildFilterChip('Hoy', 'today'),
                    _buildFilterChip('Esta semana', 'week'),
                    _buildFilterChip('Este mes', 'month'),
                    _buildFilterChip('Mes anterior', 'last_month'),
                    _buildFilterChip('Últimos 30 días', 'last_30'),
                  ],
                ),
              ],
            ),
          ),
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
                            Icon(Icons.money_off, size: 64, color: isDark ? Colors.grey[600] : Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(_searchQuery.isNotEmpty ? 'Sin resultados para "$_searchQuery"' : 'No hay comisiones en este período', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[400], fontSize: 16)),
                          ],
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _buildSummaryCards(),
                          const SizedBox(height: 16),
                          Text('Detalle por Barbero', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                          const SizedBox(height: 8),
                          ...filtered.asMap().entries.map((entry) => _buildBarberRow(entry.value, entry.key + 1)),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}