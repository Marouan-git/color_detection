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
  final DateTime lastUpdated;

  Product({
    required this.id,
    required this.supplier,
    required this.stockStatus,
    required this.lastUpdated,
  });

  Product copyWith({
    String? id,
    String? supplier,
    StockStatus? stockStatus,
    DateTime? lastUpdated,
  }) {
    return Product(
      id: id ?? this.id,
      supplier: supplier ?? this.supplier,
      stockStatus: stockStatus ?? this.stockStatus,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'supplier': supplier,
      'stockStatus': stockStatus.index,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      supplier: json['supplier'],
      stockStatus: StockStatus.values[json['stockStatus']],
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'])
          : DateTime.now(), // Fallback for old data
    );
  }
}
