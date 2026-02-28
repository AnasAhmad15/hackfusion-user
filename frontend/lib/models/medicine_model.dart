class Medicine {
  final String id;
  final String name;
  final String description;
  final double price;
  final int stock;
  final bool prescriptionRequired;
  final String brand;
  final String category;
  final int minOrderQuantity;

  Medicine({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.stock,
    required this.prescriptionRequired,
    required this.brand,
    required this.category,
    this.minOrderQuantity = 1,
  });

  factory Medicine.fromJson(Map<String, dynamic> json) {
    return Medicine(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      stock: json['stock'] ?? 0,
      prescriptionRequired: json['prescription_required'] ?? false,
      brand: json['brand'] ?? 'General',
      category: json['category'] ?? 'General',
      minOrderQuantity: json['min_order_quantity'] ?? 1,
    );
  }
}
