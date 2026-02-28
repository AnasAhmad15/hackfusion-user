import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import '../theme/design_tokens.dart';
import '../widgets/pharmaco_button.dart';

class LocationPickerScreen extends StatefulWidget {
  final LatLng? initialLocation;
  final String apiKey = "AIzaSyBnrIZ0AEf2PSWbe5qWWErfm0EdJEEqrCw";

  const LocationPickerScreen({super.key, this.initialLocation});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  String _address = "Searching for address...";
  bool _isLoading = true;
  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    if (widget.initialLocation != null) {
      _selectedLocation = widget.initialLocation;
      _updateLocation(_selectedLocation!, animate: false);
    } else {
      await _getCurrentLocation();
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        final latLng = LatLng(position.latitude, position.longitude);
        _updateLocation(latLng);
      }
    } catch (e) {
      debugPrint("Error getting location: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateLocation(LatLng latLng, {bool animate = true}) async {
    setState(() {
      _selectedLocation = latLng;
      _markers.clear();
      _markers.add(
        Marker(
          markerId: const MarkerId('selected_location'),
          position: latLng,
          draggable: true,
          onDragEnd: (newPosition) => _updateLocation(newPosition),
        ),
      );
    });

    if (animate && _mapController != null) {
      _mapController!.animateCamera(CameraUpdate.newLatLng(latLng));
    }

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latLng.latitude,
        latLng.longitude,
      );
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          _address = "${place.name}, ${place.subLocality}, ${place.locality}, ${place.administrativeArea} ${place.postalCode}, ${place.country}";
        });
      }
    } catch (e) {
      setState(() => _address = "Address not found");
      debugPrint("Geocoding error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Delivery Location'),
      ),
      body: Stack(
        children: [
          _isLoading && _selectedLocation == null
              ? const Center(child: CircularProgressIndicator())
              : GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _selectedLocation ?? const LatLng(19.0760, 72.8777),
                    zoom: 15,
                  ),
                  onMapCreated: (controller) {
                    _mapController = controller;
                    if (_selectedLocation != null) {
                      _mapController!.animateCamera(CameraUpdate.newLatLng(_selectedLocation!));
                    }
                  },
                  onTap: (latLng) => _updateLocation(latLng),
                  markers: _markers,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapType: MapType.normal,
                ),

          // Search Bar
          Positioned(
            top: PharmacoTokens.space12,
            left: PharmacoTokens.space16,
            right: PharmacoTokens.space16,
            child: Column(
              children: [
                GooglePlaceAutoCompleteTextField(
                  textEditingController: TextEditingController(),
                  googleAPIKey: widget.apiKey,
                  inputDecoration: InputDecoration(
                    hintText: "Search for area, street name...",
                    fillColor: PharmacoTokens.white,
                    filled: true,
                    prefixIcon: const Icon(Icons.search_rounded, color: PharmacoTokens.primaryBase),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(PharmacoTokens.radiusCard),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: PharmacoTokens.space20, vertical: PharmacoTokens.space12),
                  ),
                  debounceTime: 800,
                  countries: const ["in"],
                  itemClick: (Prediction prediction) async {
                    if (prediction.description != null) {
                      try {
                        List<Location> locations = await locationFromAddress(prediction.description!);
                        if (locations.isNotEmpty) {
                          final latLng = LatLng(locations[0].latitude, locations[0].longitude);
                          _updateLocation(latLng);
                        }
                      } catch (e) {
                        debugPrint("Search error: $e");
                      }
                    }
                  },
                  itemBuilder: (context, index, Prediction prediction) {
                    return Container(
                      padding: const EdgeInsets.all(PharmacoTokens.space12),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on_outlined, color: PharmacoTokens.neutral400),
                          const SizedBox(width: PharmacoTokens.space8),
                          Expanded(child: Text(prediction.description ?? "", style: theme.textTheme.bodySmall)),
                        ],
                      ),
                    );
                  },
                  seperatedBuilder: const Divider(),
                ),
              ],
            ),
          ),

          // Bottom Selection Details
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(PharmacoTokens.space20),
              decoration: BoxDecoration(
                color: PharmacoTokens.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(PharmacoTokens.radiusCard)),
                boxShadow: PharmacoTokens.shadowZ2(),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, color: PharmacoTokens.error, size: 24),
                      const SizedBox(width: PharmacoTokens.space8),
                      Text("Select Location", style: theme.textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: PharmacoTokens.space12),
                  Text(
                    _address,
                    style: theme.textTheme.bodySmall?.copyWith(color: PharmacoTokens.neutral600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: PharmacoTokens.space16),
                  PharmacoButton(
                    label: 'CONFIRM LOCATION',
                    onPressed: _selectedLocation == null
                        ? null
                        : () {
                            Navigator.pop(context, {
                              'latitude': _selectedLocation!.latitude,
                              'longitude': _selectedLocation!.longitude,
                              'address': _address,
                            });
                          },
                  ),
                ],
              ),
            ),
          ),

          // My Location FAB
          Positioned(
            bottom: 200,
            right: PharmacoTokens.space20,
            child: FloatingActionButton(
              onPressed: _getCurrentLocation,
              backgroundColor: PharmacoTokens.white,
              elevation: 4,
              child: const Icon(Icons.my_location_rounded, color: PharmacoTokens.primaryBase),
            ),
          ),
        ],
      ),
    );
  }
}
