import 'package:flutter/material.dart';
import '../models/local_product.dart';
import '../repositories/product_repository.dart';
import '../services/settings_service.dart';
import '../main.dart';
import '../services/role_permissions.dart';

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
    setState(() { _products = products; _isLoading = false; });
  }

  InputDecoration _dec(String label, String icon) {
    return InputDecoration(
      labelText: label,
      prefixText: '$icon  ',
      labelStyle: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
      floatingLabelStyle: const TextStyle(color: Color(0xFF6366F1), fontSize: 13, fontWeight: FontWeight.bold),
      filled: true,
      fillColor: const Color(0xFF0F172A),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.white10)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.white10)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2)),
    );
  }

  Widget _fieldLabel(String icon, String label, bool required) {
    return Padding(padding: const EdgeInsets.only(left: 4, bottom: 6), child: Row(children: [Text(icon, style: const TextStyle(fontSize: 13)), const SizedBox(width: 6), Text(required ? "$label *" : label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700))])); 
  }

  void _showProductDialog({LocalProduct? product}) {
    final nameController = TextEditingController(text: product?.name ?? '');
    final descriptionController = TextEditingController(text: product?.description ?? '');
    final priceController = TextEditingController(text: product?.price.toString() ?? '');
    final stockController = TextEditingController(text: product?.stock.toString() ?? '');
    final minStockController = TextEditingController(text: product?.minStock.toString() ?? '');

    showDialog(context: context, builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(product == null ? 'Nuevo Producto' : 'Editar Producto', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      content: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _fieldLabel('🏷️', 'Nombre del Producto', true),
        TextField(controller: nameController, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500), decoration: _dec('Nombre *', '')),
        const SizedBox(height: 14),
        _fieldLabel('📝', 'Descripcion / Detalle', false),
        TextField(controller: descriptionController, style: const TextStyle(color: Colors.white, fontSize: 14), decoration: _dec('Descripcion', ''), maxLines: 2),
        const SizedBox(height: 14),
        _fieldLabel('💰', 'Precio de Venta', true),
        TextField(controller: priceController, style: const TextStyle(color: Colors.white, fontSize: 14), decoration: _dec('Precio *', '')),
        const SizedBox(height: 14),
        _fieldLabel('📦', 'Stock Actual', false),
        TextField(controller: stockController, style: const TextStyle(color: Colors.white, fontSize: 14), decoration: _dec('Stock', '')),
        const SizedBox(height: 14),
        _fieldLabel('⚠️', 'Stock Minimo Alerta', false),
        TextField(controller: minStockController, style: const TextStyle(color: Colors.white, fontSize: 14), decoration: _dec('Stock minimo', '')),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey, fontSize: 13))),
        Container(decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF818CF8)]), borderRadius: BorderRadius.circular(10)), child: ElevatedButton(onPressed: () async {
          if (nameController.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El nombre es obligatorio'), backgroundColor: Colors.red)); return; }
          final newProduct = LocalProduct()
            ..remoteId = product?.remoteId ?? 'prod-${DateTime.now().millisecondsSinceEpoch}'
            ..name = nameController.text.trim()
            ..description = descriptionController.text.trim()
            ..price = double.tryParse(priceController.text) ?? 0.0
            ..stock = int.tryParse(stockController.text) ?? 0
            ..minStock = int.tryParse(minStockController.text) ?? 0
            ..isActive = true;
          if (product == null) await _productRepo.createProduct(newProduct); else await _productRepo.updateProduct(newProduct);
          Navigator.pop(context);
          await _loadProducts();
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(product == null ? '✅ Producto creado' : '✅ Producto actualizado'), backgroundColor: Colors.green));
        }, style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text('Guardar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)))),
      ],
    ));
  }

  Future<void> _deleteProduct(LocalProduct product) async {
    final confirm = await showDialog<bool>(context: context, builder: (context) => AlertDialog(backgroundColor: const Color(0xFF1E293B), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), title: const Text('Confirmar eliminacion', style: TextStyle(color: Colors.white, fontSize: 15)), content: Text('¿Eliminar ${product.name}?', style: const TextStyle(color: Colors.white70, fontSize: 13)), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar', style: TextStyle(color: Colors.grey, fontSize: 13))), ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text('Eliminar', style: TextStyle(fontSize: 13)))]));
    if (confirm == true) { await _productRepo.deleteProduct(product.remoteId!); await _loadProducts(); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Producto eliminado'), backgroundColor: Colors.orange)); }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = RolePermissions.isAdmin(currentUserRole);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)), title: const Text('Productos Premium', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), backgroundColor: const Color(0xFF1E293B), foregroundColor: Colors.white, elevation: 0),
      body: _isLoading ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1))) : _products.isEmpty ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('📦', style: TextStyle(fontSize: 64)), SizedBox(height: 16), Text('No hay productos registrados', style: TextStyle(color: Colors.white54, fontSize: 15))])) : ListView.builder(padding: const EdgeInsets.all(16), itemCount: _products.length, itemBuilder: (context, index) {
        final product = _products[index];
        final isLowStock = product.stock <= product.minStock;
        return Container(
          margin: const EdgeInsets.only(bottom: 12), 
          decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.05)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 12, offset: const Offset(0,4))]), 
          child: Material(
            type: MaterialType.transparency,
            child: ListTile(
              contentPadding: const EdgeInsets.all(14), 
              leading: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: isLowStock ? Colors.red.withOpacity(0.15) : const Color(0xFFF59E0B).withOpacity(0.15), shape: BoxShape.circle, border: Border.all(color: isLowStock ? Colors.red.withOpacity(0.3) : const Color(0xFFF59E0B).withOpacity(0.3))), child: const Text('🛍️', style: TextStyle(fontSize: 18))), 
              title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)), 
              subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [if (product.description != null && product.description!.isNotEmpty) Text(product.description!, style: const TextStyle(color: Colors.white54, fontSize: 12)), const SizedBox(height: 3), Text('💰 ${SettingsService.formatCurrency(product.price)}', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 13)), const SizedBox(height: 2), Text('📦 Stock: ${product.stock} (min: ${product.minStock})', style: TextStyle(color: isLowStock ? Colors.redAccent : Colors.white38, fontSize: 11, fontWeight: FontWeight.w600))]), 
              trailing: isAdmin ? Row(mainAxisSize: MainAxisSize.min, children: [
                Container(decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(10)), child: IconButton(icon: const Text('✏️', style: TextStyle(fontSize: 16)), onPressed: () => _showProductDialog(product: product))), 
                const SizedBox(width: 6), 
                Container(decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: IconButton(icon: const Text('🗑️', style: TextStyle(fontSize: 16)), onPressed: () => _deleteProduct(product)))
              ]) : null
            )
          )
        );
      }),
      floatingActionButton: isAdmin ? Container(decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF818CF8)]), borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.4), blurRadius: 12, offset: const Offset(0,6))]), child: FloatingActionButton(onPressed: () => _showProductDialog(), backgroundColor: Colors.transparent, elevation: 0, child: const Icon(Icons.add_rounded, color: Colors.white, size: 28))) : null,
    );
  }
}