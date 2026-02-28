import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/cart_item_model.dart';
import '../models/medicine_model.dart';

class CartService extends ChangeNotifier {
  static final CartService _instance = CartService._internal();
  factory CartService() => _instance;
  CartService._internal();

  final _supabase = Supabase.instance.client;
  List<CartItem> _items = [];

  List<CartItem> get items => _items;

  Future<void> addToCart(Medicine medicine) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      // Check if medicine already in cart
      final existingResponse = await _supabase
          .from('cart')
          .select()
          .eq('user_id', userId)
          .eq('medicine_id', int.parse(medicine.id))
          .maybeSingle();

      if (existingResponse != null) {
        // Update quantity
        final newQuantity = existingResponse['quantity'] + 1;
        await _supabase
            .from('cart')
            .update({'quantity': newQuantity})
            .eq('id', existingResponse['id']);
      } else {
        // Insert new item with minimum quantity
        await _supabase.from('cart').insert({
          'user_id': userId,
          'medicine_id': int.parse(medicine.id),
          'quantity': medicine.minOrderQuantity, // Use minOrderQuantity
        });
      }
      await fetchCart();
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding to cart: $e');
    }
  }

  Future<void> fetchCart() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final response = await _supabase
          .from('cart')
          .select('*, medicines(*)')
          .eq('user_id', userId);
      
      _items = (response as List).map((item) {
        return CartItem(
          medicine: Medicine.fromJson(item['medicines']),
          quantity: item['quantity'],
        );
      }).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching cart: $e');
    }
  }

  Future<void> updateQuantity(String medicineId, int quantity) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    if (quantity <= 0) {
      await removeFromCart(medicineId);
      return;
    }

    // Find the item to get its minOrderQuantity
    final item = _items.firstWhere((i) => i.medicine.id == medicineId);
    final minQty = item.medicine.minOrderQuantity;
    final finalQuantity = quantity < minQty ? minQty : quantity;

    try {
      await _supabase
          .from('cart')
          .update({'quantity': finalQuantity})
          .eq('user_id', userId)
          .eq('medicine_id', int.parse(medicineId));
      await fetchCart();
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating cart: $e');
    }
  }

  Future<void> removeFromCart(String medicineId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _supabase
          .from('cart')
          .delete()
          .eq('user_id', userId)
          .eq('medicine_id', int.parse(medicineId));
      await fetchCart();
      notifyListeners();
    } catch (e) {
      debugPrint('Error removing from cart: $e');
    }
  }

  Future<void> clearCart() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _supabase.from('cart').delete().eq('user_id', userId);
      _items.clear();
      notifyListeners();
    } catch (e) {
      debugPrint('Error clearing cart: $e');
    }
  }

  double get totalCost {
    return _items.fold(0, (total, current) => total + (current.medicine.price * current.quantity));
  }

  bool get requiresPrescription {
    return _items.any((item) => item.medicine.prescriptionRequired);
  }
}

