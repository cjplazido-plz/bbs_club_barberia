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

  @override
  void initState() {
    super.initState();
    _loadProducts();
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
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nombre *'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Descripción'),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: priceController,
                decoration: const InputDecoration(labelText: 'Precio *'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: stockController,
                decoration: const InputDecoration(labelText: 'Stock'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: minStockController,
                decoration: const InputDecoration(labelText: 'Stock mínimo'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('El nombre es obligatorio'), backgroundColor: Colors.red),
                );
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
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(product == null ? '✅ Producto creado' : '✅ Producto actualizado'),
                    backgroundColor: Colors.green,
                  ),
                );
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
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _productRepo.deleteProduct(product.remoteId!);
      await _loadProducts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Producto eliminado'), backgroundColor: Colors.orange),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Text('←', style: TextStyle(fontSize: 24, color: Colors.white)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Gestión de Productos'),
        backgroundColor: Colors.indigo[700],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _products.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('📦', style: TextStyle(fontSize: 64)),
                      const SizedBox(height: 16),
                      Text('No hay productos registrados', style: TextStyle(color: Colors.grey[400], fontSize: 16)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _products.length,
                  itemBuilder: (context, index) {
                    final product = _products[index];
                    final isLowStock = product.stock <= product.minStock;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isLowStock ? Colors.red[100] : Colors.orange[100],
                            shape: BoxShape.circle,
                          ),
                          child: const Text('🛍️', style: TextStyle(fontSize: 24)),
                        ),
                        title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (product.description != null) Text(product.description!, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                            Text('💰 ${SettingsService.formatCurrency(product.price)}', style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.bold)),
                            Text('📦 Stock: ${product.stock} (mín: ${product.minStock})', style: TextStyle(color: isLowStock ? Colors.red : Colors.grey[600], fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Text('️✏️', style: TextStyle(fontSize: 20)), onPressed: () => _showProductDialog(product: product)),
                            IconButton(icon: const Text('🗑️', style: TextStyle(fontSize: 20)), onPressed: () => _deleteProduct(product)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showProductDialog(),
        backgroundColor: Colors.indigo[700],
        child: const Text('➕', style: TextStyle(fontSize: 24)),
      ),
    );
  }
}