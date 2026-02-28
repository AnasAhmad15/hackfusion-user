import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static const String supabaseUrl = 'https://nlhuukhyqnkniugrgtwp.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5saHV1a2h5cW5rbml1Z3JndHdwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzAxMDQ0ODEsImV4cCI6MjA4NTY4MDQ4MX0.zBLp0QoPAU3JR53yduzsoYInNV80NJQJn_4iB7kZmuo';

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
