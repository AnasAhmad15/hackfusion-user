import 'auth_service.dart';
import 'cart_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrderService {
  final SupabaseClient _client = Supabase.instance.client;
  final AuthService _authService = AuthService();
  final CartService _cartService = CartService();

  Future<List<Map<String, dynamic>>> getOrders() async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        throw 'User is not logged in.';
      }

      final response = await _client
          .from('orders')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      return response as List<Map<String, dynamic>>;
    } catch (e) {
      throw 'An error occurred while fetching orders: $e';
    }
  }

  Future<void> placeOrder() async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        throw 'User is not logged in.';
      }

      final items = _cartService.items;
      if (items.isEmpty) {
        throw 'Cart is empty.';
      }

      final total = _cartService.totalCost;
      final userId = user.id;

      final orderData = {
        'user_id': userId,
        'total': total,
        'items': items.map((item) => {
          'medicine_id': item.medicine.id,
          'quantity': item.quantity,
          'price': item.medicine.price,
        }).toList(),
      };

      await _client.from('orders').insert(orderData);

      _cartService.clearCart();
    } catch (e) {
      throw 'An error occurred while placing the order: $e';
    }
  }
}
