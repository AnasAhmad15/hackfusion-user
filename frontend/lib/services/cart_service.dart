import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/cart_item_model.dart';
import '../models/medicine_model.dart';

class CartService extends ChangeNotifier {
  static final CartService _instance = CartService._internal();
  factory CartService() => _instance;
  CartService._internal();

  final _supabase = Supabase.instance.client;
  List<CartItem> _items = [];

  // Prescription validation state
  String? _prescriptionUrl;
  List<String> _validatedMedicines = [];
  List<String> _missingMedicines = [];
  Map<String, dynamic>? _prescriptionDetails;
  bool _isValidating = false;
  String? _validationError;

  List<CartItem> get items => _items;
  String? get prescriptionUrl => _prescriptionUrl;
  List<String> get validatedMedicines => _validatedMedicines;
  List<String> get missingMedicines => _missingMedicines;
  Map<String, dynamic>? get prescriptionDetails => _prescriptionDetails;
  bool get isValidating => _isValidating;
  String? get validationError => _validationError;

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
        // Update quantity for THIS specific medicine only
        final newQuantity = existingResponse['quantity'] + 1;
        await _supabase
            .from('cart')
            .update({'quantity': newQuantity})
            .eq('id', existingResponse['id'])
            .eq('user_id', userId); // Explicitly target this user's item
      } else {
        // Insert new item with minimum quantity
        await _supabase.from('cart').insert({
          'user_id': userId,
          'medicine_id': int.parse(medicine.id),
          'quantity': medicine.minOrderQuantity, // Use minOrderQuantity
        });
      }
      await fetchCart();
      if (_prescriptionUrl != null && medicine.prescriptionRequired) {
        await validatePrescription(_prescriptionUrl!);
      }
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
          .eq('user_id', userId)
          .order('id', ascending: true); // Sort by ID to maintain order
      
      final List<CartItem> fetchedItems = (response as List).map((item) {
        return CartItem(
          medicine: Medicine.fromJson(item['medicines']),
          quantity: item['quantity'],
        );
      }).toList();

      // Update local state ONLY if it's different to prevent UI glitches
      _items = fetchedItems;

      // Automatically clear prescription state if cart is fetched as empty
      if (_items.isEmpty) {
        _prescriptionUrl = null;
        _validatedMedicines = [];
        _missingMedicines = [];
        _prescriptionDetails = null;
        _validationError = null;
      }
      
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
    final itemIndex = _items.indexWhere((i) => i.medicine.id == medicineId);
    if (itemIndex == -1) return;
    
    final item = _items[itemIndex];
    final minQty = item.medicine.minOrderQuantity;
    final finalQuantity = quantity < minQty ? minQty : quantity;

    try {
      // 1. Update local state IMMEDIATELY for snappy UI
      _items[itemIndex].quantity = finalQuantity;
      notifyListeners();

      // 2. Update specific row in database
      await _supabase
          .from('cart')
          .update({'quantity': finalQuantity})
          .eq('user_id', userId)
          .eq('medicine_id', int.parse(medicineId));
      
      // 3. Optional: Silent fetch to ensure server sync
      final response = await _supabase
          .from('cart')
          .select('*, medicines(*)')
          .eq('user_id', userId)
          .order('id', ascending: true); // Sort by ID to maintain order
      
      _items = (response as List).map((item) {
        return CartItem(
          medicine: Medicine.fromJson(item['medicines']),
          quantity: item['quantity'],
        );
      }).toList();

      notifyListeners();
    } catch (e) {
      debugPrint('Error updating cart: $e');
      // Revert on error
      await fetchCart();
    }
  }

  Future<void> removeFromCart(String medicineId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final itemToRemove = _items.firstWhere((i) => i.medicine.id == medicineId);
      final wasRxRequired = itemToRemove.medicine.prescriptionRequired;

      await _supabase
          .from('cart')
          .delete()
          .eq('user_id', userId)
          .eq('medicine_id', int.parse(medicineId));
      await fetchCart();

      // Clear prescription if cart becomes empty
      if (_items.isEmpty) {
        _prescriptionUrl = null;
        _validatedMedicines = [];
        _missingMedicines = [];
        _prescriptionDetails = null;
        _validationError = null;
      } else if (_prescriptionUrl != null && wasRxRequired) {
        await validatePrescription(_prescriptionUrl!);
      }
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
      _prescriptionUrl = null;
      _validatedMedicines = [];
      _missingMedicines = [];
      _prescriptionDetails = null;
      _validationError = null;
      notifyListeners();
    } catch (e) {
      debugPrint('Error clearing cart: $e');
    }
  }

  Future<void> setPrescriptionUrl(String url) async {
    _prescriptionUrl = url;
    await validatePrescription(url);
    notifyListeners();
  }

  Future<void> validatePrescription(String url) async {
    _isValidating = true;
    _prescriptionUrl = url;
    _validationError = null;
    notifyListeners();

    try {
      final userId = _supabase.auth.currentUser?.id;
      final rxItems = _items
          .where((item) => item.medicine.prescriptionRequired)
          .map((item) => item.medicine.name)
          .toList();

      if (rxItems.isEmpty) {
        _validatedMedicines = [];
        _missingMedicines = [];
        _prescriptionDetails = null;
        _validationError = null;
        _isValidating = false;
        notifyListeners();
        return;
      }

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/validate_prescription_cart'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'image_url': url,
          'cart_items': rxItems,
        }),
      ).timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          _validatedMedicines = List<String>.from(data['validated_items']);
          _missingMedicines = List<String>.from(data['missing_items']);
          _prescriptionDetails = data['prescription_details'];
          _validationError = null;
        } else {
          _validationError = data['error'] ?? 'Validation failed';
          _validatedMedicines = [];
          _missingMedicines = rxItems;
        }
      } else {
        _validationError = 'Server error (${response.statusCode}). Please try again.';
      }
    } on TimeoutException {
      _validationError = 'Analysis is taking longer than expected. Please retry.';
    } catch (e) {
      debugPrint('Validation error in CartService: $e');
      _validationError = 'Connection error. Please try again.';
    } finally {
      _isValidating = false;
      notifyListeners();
    }
  }

  double get totalCost {
    return _items.fold(0, (total, current) => total + (current.medicine.price * current.quantity));
  }

  bool get requiresPrescription {
    return _items.any((item) => item.medicine.prescriptionRequired);
  }
}

