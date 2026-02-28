import 'cart_item_model.dart';

class Order {
  final String id;
  final String userId;
  final double totalAmount;
  final String status;
  final String paymentMethod;
  final String? paymentReference;
  final String deliveryAddress;
  final DateTime createdAt;
  final String? paymentStatus;
  final String? patientId;
  final int? patientAge;
  final String? patientGender;
  final List<OrderItem>? items;
  final Map<String, dynamic>? pharmacy;
  final Map<String, dynamic>? deliveryPartner;
  final double serviceFee;
  final double deliveryFee;
  final double totalTax;

  Order({
    required this.id,
    required this.userId,
    required this.totalAmount,
    required this.status,
    required this.paymentMethod,
    this.paymentReference,
    required this.deliveryAddress,
    required this.createdAt,
    this.paymentStatus,
    this.patientId,
    this.patientAge,
    this.patientGender,
    this.items,
    this.pharmacy,
    this.deliveryPartner,
    this.serviceFee = 0.0,
    this.deliveryFee = 0.0,
    this.totalTax = 0.0,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    // Handle cases where Supabase might return relations as a list
    dynamic pharmacyData = json['medical_partners'];
    if (pharmacyData is List && pharmacyData.isNotEmpty) {
      pharmacyData = pharmacyData[0];
    } else if (pharmacyData is List) {
      pharmacyData = null;
    }

    dynamic partnerData = json['profiles'];
    if (partnerData is List && partnerData.isNotEmpty) {
      partnerData = partnerData[0];
    } else if (partnerData is List) {
      partnerData = null;
    }

    return Order(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] ?? 'pending',
      paymentMethod: json['payment_method'] ?? 'Unknown',
      paymentReference: json['payment_reference'],
      deliveryAddress: json['delivery_address'] ?? 'Default Address',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      paymentStatus: json['payment_status'],
      patientId: json['patient_id'],
      patientAge: json['patient_age'],
      patientGender: json['patient_gender'],
      items: json['order_items'] != null
          ? (json['order_items'] as List)
              .map((i) => OrderItem.fromJson(i))
              .toList()
          : null,
      pharmacy: pharmacyData,
      deliveryPartner: partnerData,
      serviceFee: (json['service_fee'] as num?)?.toDouble() ?? 0.0,
      deliveryFee: (json['delivery_fee'] as num?)?.toDouble() ?? 0.0,
      totalTax: (json['total_tax'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class OrderItem {
  final String id;
  final int medicineId;
  final String name;
  final int quantity;
  final double price;
  final String? dosageFrequency;
  final bool? prescriptionRequired;

  OrderItem({
    required this.id,
    required this.medicineId,
    required this.name,
    required this.quantity,
    required this.price,
    this.dosageFrequency,
    this.prescriptionRequired,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'],
      medicineId: json['medicine_id'],
      name: json['name'],
      quantity: json['quantity'],
      price: (json['price'] as num).toDouble(),
      dosageFrequency: json['dosage_frequency'],
      prescriptionRequired: json['prescription_required'],
    );
  }
}
