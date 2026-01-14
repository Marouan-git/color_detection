/// Represents a single order record in the order history.
class OrderRecord {
  final String id; // Unique ID for this order record
  final String productId; // Product this order is for (stockCode)
  final String supplier; // Supplier name for reference
  final DateTime orderDate;
  final int quantity;
  final bool delivered;
  final DateTime? deliveryDate;
  final DateTime?
  previousOrderDate; // Previous order date for interval tracking

  OrderRecord({
    required this.id,
    required this.productId,
    required this.supplier,
    required this.orderDate,
    required this.quantity,
    this.delivered = false,
    this.deliveryDate,
    this.previousOrderDate,
  });

  OrderRecord copyWith({
    String? id,
    String? productId,
    String? supplier,
    DateTime? orderDate,
    int? quantity,
    bool? delivered,
    DateTime? deliveryDate,
    DateTime? previousOrderDate,
  }) {
    return OrderRecord(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      supplier: supplier ?? this.supplier,
      orderDate: orderDate ?? this.orderDate,
      quantity: quantity ?? this.quantity,
      delivered: delivered ?? this.delivered,
      deliveryDate: deliveryDate ?? this.deliveryDate,
      previousOrderDate: previousOrderDate ?? this.previousOrderDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'productId': productId,
      'supplier': supplier,
      'orderDate': orderDate.toIso8601String(),
      'quantity': quantity,
      'delivered': delivered,
      'deliveryDate': deliveryDate?.toIso8601String(),
      'previousOrderDate': previousOrderDate?.toIso8601String(),
    };
  }

  factory OrderRecord.fromJson(Map<String, dynamic> json) {
    return OrderRecord(
      id: json['id'] as String,
      productId: json['productId'] as String,
      supplier: json['supplier'] as String? ?? '',
      orderDate: DateTime.parse(json['orderDate'] as String),
      quantity: json['quantity'] as int,
      delivered: json['delivered'] as bool? ?? false,
      deliveryDate: json['deliveryDate'] != null
          ? DateTime.parse(json['deliveryDate'] as String)
          : null,
      previousOrderDate: json['previousOrderDate'] != null
          ? DateTime.parse(json['previousOrderDate'] as String)
          : null,
    );
  }
}
