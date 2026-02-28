import '../models/medicine_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MedicineService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<Medicine>> getMedicines() async {
    try {
      final response = await _client.from('medicines').select();
      final data = response as List<dynamic>;
      return data.map((json) => Medicine.fromJson(json)).toList();
    } catch (e) {
      throw 'An error occurred while fetching medicines: $e';
    }
  }
}
