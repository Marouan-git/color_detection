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
  final String id; // Unique identifier (for internal use)
  final String supplier;
  final String stockCode; // Separate stock code for sorting
  final StockStatus stockStatus;
  final DateTime lastUpdated;

  // Order tracking fields
  final bool isOrdered;
  final bool isDelivered;
  final int? quantityOrdered;
  final DateTime? lastOrderDate;

  Product({
    required this.id,
    required this.supplier,
    required this.stockCode,
    required this.stockStatus,
    required this.lastUpdated,
    this.isOrdered = false,
    this.isDelivered = false,
    this.quantityOrdered,
    this.lastOrderDate,
  });

  Product copyWith({
    String? id,
    String? supplier,
    String? stockCode,
    StockStatus? stockStatus,
    DateTime? lastUpdated,
    bool? isOrdered,
    bool? isDelivered,
    int? quantityOrdered,
    DateTime? lastOrderDate,
  }) {
    return Product(
      id: id ?? this.id,
      supplier: supplier ?? this.supplier,
      stockCode: stockCode ?? this.stockCode,
      stockStatus: stockStatus ?? this.stockStatus,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isOrdered: isOrdered ?? this.isOrdered,
      isDelivered: isDelivered ?? this.isDelivered,
      quantityOrdered: quantityOrdered ?? this.quantityOrdered,
      lastOrderDate: lastOrderDate ?? this.lastOrderDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'supplier': supplier,
      'stockCode': stockCode,
      'stockStatus': stockStatus.index,
      'lastUpdated': lastUpdated.toIso8601String(),
      'isOrdered': isOrdered,
      'isDelivered': isDelivered,
      'quantityOrdered': quantityOrdered,
      'lastOrderDate': lastOrderDate?.toIso8601String(),
    };
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    // Handle migration from old format (where stockCode might not exist)
    final id = json['id'] as String;
    final supplier = json['supplier'] as String? ?? '';

    // If stockCode doesn't exist, derive from id or use id as stockCode
    final stockCode = json['stockCode'] as String? ?? id;

    return Product(
      id: id,
      supplier: supplier,
      stockCode: stockCode,
      stockStatus: StockStatus.values[json['stockStatus'] as int],
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'])
          : DateTime.now(),
      isOrdered: json['isOrdered'] as bool? ?? false,
      isDelivered: json['isDelivered'] as bool? ?? false,
      quantityOrdered: json['quantityOrdered'] as int?,
      lastOrderDate: json['lastOrderDate'] != null
          ? DateTime.parse(json['lastOrderDate'])
          : null,
    );
  }
}
