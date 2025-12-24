enum StockStatus {
  inStock,
  lowStock,
  outOfStock;

  String get label {
    switch (this) {
      case StockStatus.inStock:
        return 'In Stock';
      case StockStatus.lowStock:
        return 'Low Stock';
      case StockStatus.outOfStock:
        return 'Out of Stock';
    }
  }
}

class Product {
  final String id;
  final String supplier;
  final StockStatus stockStatus;

  Product({
    required this.id,
    required this.supplier,
    required this.stockStatus,
  });

  Product copyWith({String? id, String? supplier, StockStatus? stockStatus}) {
    return Product(
      id: id ?? this.id,
      supplier: supplier ?? this.supplier,
      stockStatus: stockStatus ?? this.stockStatus,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'supplier': supplier, 'stockStatus': stockStatus.index};
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      supplier: json['supplier'],
      stockStatus: StockStatus.values[json['stockStatus']],
    );
  }
}
