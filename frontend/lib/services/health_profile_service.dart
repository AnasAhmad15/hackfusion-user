import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/health_profile_model.dart';

class HealthProfileService {
  final _client = Supabase.instance.client;

  Future<HealthProfile?> getProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final response = await _client
        .from('health_profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (response == null) return null;
    return HealthProfile.fromJson(response);
  }

  Future<void> updateProfile(HealthProfile profile) async {
    await _client.from('health_profiles').upsert(profile.toJson());
  }
}
