class LocalProduct {
  String? remoteId;
  String name;
  double price;
  int stock;
  bool isActive;
  String? description;
  int minStock;

  LocalProduct({
    this.remoteId,
    this.name = '',
    this.price = 0.0,
    this.stock = 0,
    this.isActive = true,
    this.description,
    this.minStock = 0,
  });
}