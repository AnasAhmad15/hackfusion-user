import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String name,
    required String age,
    required String gender,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'name': name, 'age': age, 'gender': gender},
      );
      if (response.user == null) {
        throw 'Registration failed: No user returned.';
      }
    } on AuthException catch (e) {
      throw 'Registration failed: ${e.message}';
    } catch (e) {
      throw 'An unexpected error occurred during registration.';
    }
  }

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (response.user == null) {
        throw 'Login failed: No user returned.';
      }
      return response;
    } on AuthException catch (e) {
      throw 'Login failed: ${e.message}';
    } catch (e) {
      throw 'An unexpected error occurred during login.';
    }
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  User? get currentUser => _client.auth.currentUser;
}
