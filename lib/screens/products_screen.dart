import 'package:flutter/material.dart';
import '../models/local_product.dart';
import '../repositories/product_repository.dart';
import '../services/settings_service.dart';

class ProductsScreen extends StatefulWidget {
  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _productRepo = ProductRepository();
  List<LocalProduct> _products = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ✅ FILTRO: busca por nombre o descripción
  List<LocalProduct> get _filteredProducts {
    if (_searchQuery.trim().isEmpty) return _products;
    final q = _searchQuery.trim().toLowerCase();
    return _products.where((p) {
      final name = p.name.toLowerCase();
      final desc = (p.description ?? '').toLowerCase();
      return name.contains(q) || desc.contains(q);
    }).toList();
  }

  Future<void> _loadProducts() async {
    setState(() { _isLoading = true; });
    final products = await _productRepo.getAllProducts();
    setState(() {
      _products = products;
      _isLoading = false;
    });
  }

  void _showProductDialog({LocalProduct? product}) {
    final nameController = TextEditingController(text: product?.name ?? '');
    final descriptionController = TextEditingController(text: product?.description ?? '');
    final priceController = TextEditingController(text: product?.price.toString());
    final stockController = TextEditingController(text: product?.stock.toString());
    final minStockController = TextEditingController(text: product?.minStock.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(product == null ? 'Nuevo Producto' : 'Editar Producto'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nombre *')),
              const SizedBox(height: 8),
              TextField(controller: descriptionController, decoration: const InputDecoration(labelText: 'Descripción'), maxLines: 2),
              const SizedBox(height: 8),
              TextField(controller: priceController, decoration: const InputDecoration(labelText: 'Precio *'), keyboardType: TextInputType.number),
              const SizedBox(height: 8),
              TextField(controller: stockController, decoration: const InputDecoration(labelText: 'Stock'), keyboardType: TextInputType.number),
              const SizedBox(height: 8),
              TextField(controller: minStockController, decoration: const InputDecoration(labelText: 'Stock mínimo'), keyboardType: TextInputType.number),
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
              final newProduct = LocalProduct()
                ..remoteId = product?.remoteId ?? 'prod-${DateTime.now().millisecondsSinceEpoch}'
                ..name = nameController.text.trim()
                ..description = descriptionController.text.trim()
                ..price = double.tryParse(priceController.text) ?? 0.0
                ..stock = int.tryParse(stockController.text) ?? 0
                ..minStock = int.tryParse(minStockController.text) ?? 0
                ..isActive = true;
              if (product == null) {
                await _productRepo.createProduct(newProduct);
              } else {
                await _productRepo.updateProduct(newProduct);
              }
              Navigator.pop(context);
              await _loadProducts();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(product == null ? 'Producto creado' : 'Producto actualizado'), backgroundColor: Colors.green));
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteProduct(LocalProduct product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text('¿Eliminar ${product.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirm == true) {
      await _productRepo.deleteProduct(product.remoteId!);
      await _loadProducts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Producto eliminado'), backgroundColor: Colors.orange));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _filteredProducts;
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.shopping_bag, size: 22),
            SizedBox(width: 8),
            Expanded(child: Text('Gestión de Productos', overflow: TextOverflow.ellipsis)),
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
                hintText: 'Buscar producto por nombre o descripción...',
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
                            Icon(Icons.shopping_bag, size: 64, color: isDark ? Colors.grey[600] : Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(_searchQuery.isNotEmpty ? 'Sin resultados para "$_searchQuery"' : 'No hay productos registrados', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[400], fontSize: 16)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final product = filtered[index];
                          final isLowStock = product.stock <= product.minStock;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              leading: CircleAvatar(
                                backgroundColor: isLowStock ? (isDark ? const Color(0xFF7F1D1D) : Colors.red[100]) : (isDark ? const Color(0xFF312E81) : Colors.indigo[100]),
                                child: Icon(
                                  isLowStock ? Icons.warning_amber : Icons.shopping_bag,
                                  size: 20,
                                  color: isLowStock ? (isDark ? Colors.red[200] : Colors.red[700]) : (isDark ? const Color(0xFF818CF8) : Colors.indigo[700]),
                                ),
                              ),
                              title: Text(
                                product.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : Colors.black87),
                              ),
                              subtitle: Text(
                                '${SettingsService.formatCurrency(product.price)} · Stock: ${product.stock} (mín: ${product.minStock})',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isLowStock ? FontWeight.w700 : FontWeight.normal,
                                  color: isLowStock ? (isDark ? Colors.red[300] : Colors.red[700]) : (isDark ? Colors.grey[400] : Colors.grey[600]),
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(icon: const Icon(Icons.edit, color: Colors.amber, size: 20), onPressed: () => _showProductDialog(product: product)),
                                  IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20), onPressed: () => _deleteProduct(product)),
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
        onPressed: () => _showProductDialog(),
        backgroundColor: const Color(0xFF6366F1),
        child: const Icon(Icons.add),
      ),
    );
  }
}