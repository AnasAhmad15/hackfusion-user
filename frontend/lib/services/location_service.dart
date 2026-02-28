import 'package:geocoding/geocoding.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class LocationService {
  static final _supabase = Supabase.instance.client;

  /// Returns a formatted address string from coordinates
  static Future<String?> getAddressFromCoords(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        Placemark p = placemarks[0];
        // Format: Name, SubLocality, Locality, AdministrativeArea, PostalCode, Country
        final parts = [
          p.name,
          p.subLocality,
          p.locality,
          p.subAdministrativeArea,
          p.administrativeArea,
          p.postalCode,
          // p.country // Optional
        ].where((part) => part != null && part.isNotEmpty).toList();
        
        return parts.join(', ');
      }
    } catch (e) {
      debugPrint("Error in getAddressFromCoords: $e");
    }
    return null;
  }

  /// Syncs the user's address fields based on latitude and longitude
  /// Returns the synced address string if successful
  static Future<String?> syncUserAddress(String userId, {double? lat, double? lng}) async {
    try {
      double? finalLat = lat;
      double? finalLng = lng;

      // If lat/lng not provided, fetch from profile
      if (finalLat == null || finalLng == null) {
        final profile = await _supabase
            .from('user_profiles')
            .select('latitude, longitude')
            .eq('id', userId)
            .maybeSingle();
        
        if (profile != null) {
          finalLat = profile['latitude'];
          finalLng = profile['longitude'];
        }
      }

      if (finalLat == null || finalLng == null) {
        debugPrint("Cannot sync address: Latitude or Longitude is missing.");
        return null;
      }

      final address = await getAddressFromCoords(finalLat, finalLng);
      if (address != null) {
        await _supabase.from('user_profiles').update({
          'address': address,
          'city_area': address, // Updating both for consistency
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', userId);
        
        return address;
      }
    } catch (e) {
      debugPrint("Error in syncUserAddress: $e");
    }
    return null;
  }
}
