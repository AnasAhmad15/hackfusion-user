import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

class StorageService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<String> uploadPrescription(XFile image) async {
    try {
      final userId = _client.auth.currentUser!.id;
      final fileExt = image.path.split('.').last;
      final fileName = '${DateTime.now().toIso8601String()}.$fileExt';
      final filePath = '$userId/$fileName';

      final file = File(image.path);
      await _client.storage.from('prescriptions').upload(filePath, file);

      // Return the public URL of the uploaded file
      final response = _client.storage.from('prescriptions').getPublicUrl(filePath);
      return response;
    } catch (e) {
      throw 'Failed to upload prescription: $e';
    }
  }

  Future<String> uploadAvatar(XFile image) async {
    try {
      final userId = _client.auth.currentUser!.id;
      final fileExt = image.path.split('.').last;
      final fileName = '${DateTime.now().toIso8601String()}.$fileExt';
      final filePath = '$userId/$fileName';

      final file = File(image.path);
      await _client.storage.from('avatars').upload(filePath, file);

      final response = _client.storage.from('avatars').getPublicUrl(filePath);
      return response;
    } catch (e) {
      throw 'Failed to upload avatar: $e';
    }
  }
}
