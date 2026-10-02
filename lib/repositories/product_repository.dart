import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/local_product.dart';

class ProductRepository {
  final _client = Supabase.instance.client;

  Future<List<LocalProduct>> getAllProducts() async {
    final response = await _client.from('products').select();
    return List<Map<String, dynamic>>.from(response).map((data) {
      return LocalProduct()
        ..remoteId = data['id']
        ..name = data['name'] ?? ''
        ..description = data['description']
        ..price = (data['price'] as num?)?.toDouble() ?? 0.0
        ..stock = (data['stock'] as int?) ?? 0
        ..minStock = (data['min_stock'] as int?) ?? 0
        ..isActive = data['is_active'] ?? true;
    }).toList();
  }

  Future<LocalProduct?> findByRemoteId(String remoteId) async {
    final response = await _client
        .from('products')
        .select()
        .eq('id', remoteId)
        .maybeSingle();
    if (response == null) return null;
    return LocalProduct()
      ..remoteId = response['id']
      ..name = response['name'] ?? ''
      ..description = response['description']
      ..price = (response['price'] as num?)?.toDouble() ?? 0.0
      ..stock = (response['stock'] as int?) ?? 0
      ..minStock = (response['min_stock'] as int?) ?? 0
      ..isActive = response['is_active'] ?? true;
  }

  Future<List<LocalProduct>> getLowStockProducts() async {
    final all = await getAllProducts();
    return all.where((p) => p.stock <= p.minStock).toList();
  }

  Future<LocalProduct> createProduct(LocalProduct product) async {
    final id = product.remoteId ?? 'prod-${DateTime.now().millisecondsSinceEpoch}';
    product.remoteId = id;
    await _client.from('products').insert({
      'id': id,
      'name': product.name,
      'description': product.description,
      'price': product.price,
      'stock': product.stock,
      'min_stock': product.minStock,
      'is_active': true,
    });
    print('✅ Producto creado: ${product.name}');
    return product;
  }

  Future<LocalProduct> updateProduct(LocalProduct product) async {
    await _client.from('products')
        .update({
          'name': product.name,
          'description': product.description,
          'price': product.price,
          'stock': product.stock,
          'min_stock': product.minStock,
        })
        .eq('id', product.remoteId!);
    print('✅ Producto actualizado: ${product.name}');
    return product;
  }

  Future<void> deleteProduct(String remoteId) async {
    await _client.from('products')
        .update({'is_active': false})
        .eq('id', remoteId);
    print('✅ Producto eliminado: $remoteId');
  }
}