import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/storage_service.dart';
import '../services/fcm_service.dart';
import '../services/location_service.dart';
import '../theme/design_tokens.dart';
import '../widgets/pharmaco_button.dart';
import 'location_picker_screen.dart';

class ProfileCompletionScreen extends StatefulWidget {
  const ProfileCompletionScreen({super.key});

  @override
  State<ProfileCompletionScreen> createState() => _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState extends State<ProfileCompletionScreen> {
  final _client = Supabase.instance.client;
  final _storageService = StorageService();
  final _formKey = GlobalKey<FormState>();

  // Section 1: Basic Info
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _ageController = TextEditingController();
  String? _selectedGender;
  String? _selectedBloodGroup;
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();

  // Section 2: Location
  final _locationController = TextEditingController();
  final _sosMessageController = TextEditingController();
  double? _lat;
  double? _lng;

  // Section 3: Health Info
  final List<String> _allergies = [];
  final List<String> _chronicConditions = [];
  final List<String> _regularMeds = [];
  final _allergyInputController = TextEditingController();
  final _chronicInputController = TextEditingController();
  final _medsInputController = TextEditingController();

  // Section 4: Prescription
  XFile? _prescriptionImage;
  String? _uploadedPrescriptionUrl;

  // Section 5: Avatar
  XFile? _avatarImage;
  String? _uploadedAvatarUrl;

  bool _isLoading = false;
  bool _isLocating = false;

  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  static const LatLng _defaultLocation = LatLng(19.0760, 72.8777);

  @override
  void initState() {
    super.initState();
    final user = _client.auth.currentUser;
    if (user != null) {
      _nameController.text = user.userMetadata?['name'] ?? '';
      _ageController.text = user.userMetadata?['age']?.toString() ?? '';
      final metadataGender = user.userMetadata?['gender']?.toString().toLowerCase();
      if (metadataGender != null) {
        if (metadataGender == 'male') _selectedGender = 'Male';
        else if (metadataGender == 'female') _selectedGender = 'Female';
        else if (metadataGender == 'other') _selectedGender = 'Other';
      }
    }
    _fetchExistingProfile();
  }

  Future<void> _fetchExistingProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      final data = await _client.from('user_profiles').select().eq('id', user.id).maybeSingle();
      if (data != null) {
        setState(() {
          _nameController.text = data['full_name'] ?? _nameController.text;
          _phoneController.text = data['phone_number'] ?? '';
          _ageController.text = data['age']?.toString() ?? '';
          _selectedGender = data['gender'];
          _selectedBloodGroup = data['blood_group'];
          _locationController.text = data['city_area'] ?? '';
          _sosMessageController.text = data['custom_sos_message'] ?? '';
          _lat = data['latitude'];
          _lng = data['longitude'];

          if (_lat != null && _lng != null) {
            _updateLocation(LatLng(_lat!, _lng!));
            if (_locationController.text.isEmpty || _locationController.text == 'No address set in profile') {
              LocationService.getAddressFromCoords(_lat!, _lng!).then((addr) {
                if (mounted && addr != null) setState(() => _locationController.text = addr);
              });
            }
          }

          if (data['allergies'] != null) {
            _allergies.clear();
            _allergies.addAll(List<String>.from(data['allergies']));
          }
          if (data['chronic_conditions'] != null) {
            _chronicConditions.clear();
            _chronicConditions.addAll(List<String>.from(data['chronic_conditions']));
          }
          if (data['regular_medications'] != null) {
            _regularMeds.clear();
            _regularMeds.addAll(List<String>.from(data['regular_medications']));
          }

          _uploadedPrescriptionUrl = data['last_prescription_url'];
          _uploadedAvatarUrl = data['avatar_url'];
        });
      }
    } catch (e) {
      debugPrint('Error fetching existing profile: $e');
    }
  }

  void _addItem(List<String> list, TextEditingController controller) {
    if (controller.text.trim().isNotEmpty) {
      setState(() {
        list.add(controller.text.trim());
        controller.clear();
      });
    }
  }

  void _removeItem(List<String> list, int index) {
    setState(() => list.removeAt(index));
  }

  void _updateLocation(LatLng latLng) {
    setState(() {
      _lat = latLng.latitude;
      _lng = latLng.longitude;
      _markers.clear();
      _markers.add(Marker(markerId: const MarkerId('selected_location'), position: latLng));
    });
  }

  void _openLocationPicker() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerScreen(
          initialLocation: _lat != null && _lng != null ? LatLng(_lat!, _lng!) : null,
        ),
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      _updateLocation(LatLng(result['latitude'], result['longitude']));
      setState(() => _locationController.text = result['address']);
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(result['latitude'], result['longitude']), 15),
      );
    }
  }

  Future<void> _pickPrescription() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) setState(() => _prescriptionImage = image);
  }

  Future<void> _pickAvatar() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) setState(() => _avatarImage = image);
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final user = _client.auth.currentUser;
      if (user == null) return;

      if (_avatarImage != null) {
        _uploadedAvatarUrl = await _storageService.uploadAvatar(_avatarImage!);
      }

      if (_prescriptionImage != null) {
        _uploadedPrescriptionUrl = await _storageService.uploadPrescription(_prescriptionImage!);
      }

      await _client.from('user_profiles').upsert({
        'id': user.id,
        'full_name': _nameController.text,
        'phone_number': _phoneController.text,
        'age': int.tryParse(_ageController.text),
        'gender': _selectedGender,
        'blood_group': _selectedBloodGroup,
        'weight': double.tryParse(_weightController.text),
        'height': double.tryParse(_heightController.text),
        'address': _locationController.text,
        'city_area': _locationController.text,
        'custom_sos_message': _sosMessageController.text,
        'latitude': _lat,
        'longitude': _lng,
        'allergies': _allergies,
        'chronic_conditions': _chronicConditions,
        'regular_medications': _regularMeds,
        'last_prescription_url': _uploadedPrescriptionUrl,
        'avatar_url': _uploadedAvatarUrl,
        'is_profile_complete': true,
      });

      if (mounted) {
        await FCMService.initialize();
        await FCMService.sendWelcomeNotification('profile_completion');
        Navigator.of(context).pushReplacementNamed('/app-tour');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving profile: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Your Profile'),
        automaticallyImplyLeading: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(PharmacoTokens.space16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Avatar
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 56,
                      backgroundColor: PharmacoTokens.primarySurface,
                      backgroundImage: _avatarImage != null
                          ? FileImage(File(_avatarImage!.path))
                          : (_uploadedAvatarUrl != null
                              ? NetworkImage(_uploadedAvatarUrl!)
                              : null) as ImageProvider?,
                      child: _avatarImage == null && _uploadedAvatarUrl == null
                          ? const Icon(Icons.person, size: 56, color: PharmacoTokens.primaryBase)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _pickAvatar,
                        child: Container(
                          padding: const EdgeInsets.all(PharmacoTokens.space8),
                          decoration: const BoxDecoration(
                            color: PharmacoTokens.primaryBase,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt_rounded, color: PharmacoTokens.white, size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: PharmacoTokens.space24),

              // Basic Information
              _buildSectionCard(
                theme: theme,
                isDark: isDark,
                title: "Basic Information",
                icon: Icons.person_rounded,
                children: [
                  _buildTextField(_nameController, "Full Name", Icons.person_outline_rounded),
                  const SizedBox(height: PharmacoTokens.space12),
                  _buildTextField(_phoneController, "Mobile Number", Icons.phone_outlined, keyboardType: TextInputType.phone),
                  const SizedBox(height: PharmacoTokens.space12),
                  Row(
                    children: [
                      Expanded(child: _buildTextField(_ageController, "Age", Icons.cake_outlined, keyboardType: TextInputType.number)),
                      const SizedBox(width: PharmacoTokens.space12),
                      Expanded(child: _buildDropdown("Gender", _selectedGender, ['Male', 'Female', 'Other'], (v) => setState(() => _selectedGender = v))),
                    ],
                  ),
                  const SizedBox(height: PharmacoTokens.space12),
                  Row(
                    children: [
                      Expanded(child: _buildTextField(_weightController, "Weight (kg)", Icons.monitor_weight_outlined, keyboardType: TextInputType.number)),
                      const SizedBox(width: PharmacoTokens.space12),
                      Expanded(child: _buildTextField(_heightController, "Height (cm)", Icons.height_rounded, keyboardType: TextInputType.number)),
                    ],
                  ),
                  const SizedBox(height: PharmacoTokens.space12),
                  _buildDropdown("Blood Group", _selectedBloodGroup, ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'], (v) => setState(() => _selectedBloodGroup = v)),
                ],
              ),
              const SizedBox(height: PharmacoTokens.space16),

              // Location Details
              _buildSectionCard(
                theme: theme,
                isDark: isDark,
                title: "Location Details",
                icon: Icons.location_on_rounded,
                children: [
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: PharmacoTokens.borderRadiusMedium,
                      border: Border.all(color: PharmacoTokens.neutral300),
                    ),
                    child: ClipRRect(
                      borderRadius: PharmacoTokens.borderRadiusMedium,
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: _lat != null && _lng != null ? LatLng(_lat!, _lng!) : _defaultLocation,
                          zoom: 12,
                        ),
                        onMapCreated: (controller) => _mapController = controller,
                        onTap: _updateLocation,
                        markers: _markers,
                        myLocationEnabled: true,
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
                      ),
                    ),
                  ),
                  const SizedBox(height: PharmacoTokens.space12),
                  _buildTextField(
                    _locationController,
                    "City / Area",
                    Icons.map_outlined,
                    suffixIcon: IconButton(
                      icon: _isLocating
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.search_rounded),
                      onPressed: _isLocating ? null : _openLocationPicker,
                    ),
                  ),
                  const SizedBox(height: PharmacoTokens.space12),
                  _buildTextField(
                    _sosMessageController,
                    "Custom SOS Message",
                    Icons.message_outlined,
                    maxLines: 2,
                    hintText: "e.g. Help! I'm a heart patient. Please reach out.",
                  ),
                  const SizedBox(height: PharmacoTokens.space12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _openLocationPicker,
                      icon: const Icon(Icons.location_on_rounded),
                      label: const Text("PICK LOCATION FROM MAP"),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: PharmacoTokens.space12),
                        shape: RoundedRectangleBorder(borderRadius: PharmacoTokens.borderRadiusMedium),
                        side: const BorderSide(color: PharmacoTokens.primaryBase),
                      ),
                    ),
                  ),
                  const SizedBox(height: PharmacoTokens.space8),
                  Text("Tip: Tap on the map to select your location",
                      style: theme.textTheme.labelSmall?.copyWith(color: PharmacoTokens.neutral500)),
                ],
              ),
              const SizedBox(height: PharmacoTokens.space16),

              // Health History
              _buildSectionCard(
                theme: theme,
                isDark: isDark,
                title: "Health History",
                icon: Icons.health_and_safety_rounded,
                children: [
                  _buildMultiInputSection(theme, "Allergies", _allergies, _allergyInputController, Icons.warning_amber_rounded),
                  const SizedBox(height: PharmacoTokens.space16),
                  _buildMultiInputSection(theme, "Chronic Conditions", _chronicConditions, _chronicInputController, Icons.history_rounded),
                  const SizedBox(height: PharmacoTokens.space16),
                  _buildMultiInputSection(theme, "Regular Medications", _regularMeds, _medsInputController, Icons.medication_outlined),
                ],
              ),
              const SizedBox(height: PharmacoTokens.space16),

              // Prescription
              _buildSectionCard(
                theme: theme,
                isDark: isDark,
                title: "Prescription (Last Used)",
                icon: Icons.description_rounded,
                children: [
                  if (_uploadedPrescriptionUrl != null && _prescriptionImage == null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: PharmacoTokens.space12),
                      child: ClipRRect(
                        borderRadius: PharmacoTokens.borderRadiusMedium,
                        child: Image.network(_uploadedPrescriptionUrl!, height: 150, width: double.infinity, fit: BoxFit.cover),
                      ),
                    ),
                  if (_prescriptionImage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: PharmacoTokens.space12),
                      child: ClipRRect(
                        borderRadius: PharmacoTokens.borderRadiusMedium,
                        child: Image.file(File(_prescriptionImage!.path), height: 150, width: double.infinity, fit: BoxFit.cover),
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: _pickPrescription,
                    icon: const Icon(Icons.camera_alt_rounded),
                    label: Text(_prescriptionImage == null && _uploadedPrescriptionUrl == null ? "Upload Prescription Image" : "Change Prescription"),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: PharmacoTokens.borderRadiusMedium),
                      side: const BorderSide(color: PharmacoTokens.primaryBase),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: PharmacoTokens.space32),

              PharmacoButton(
                label: 'SAVE HEALTH PROFILE',
                icon: Icons.save_rounded,
                onPressed: _isLoading ? null : _saveProfile,
                isLoading: _isLoading,
              ),
              const SizedBox(height: PharmacoTokens.space40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMultiInputSection(ThemeData theme, String label, List<String> items, TextEditingController controller, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.titleSmall),
        const SizedBox(height: PharmacoTokens.space8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: "Add $label",
                  prefixIcon: Icon(icon, color: PharmacoTokens.primaryBase),
                ),
                onFieldSubmitted: (_) => _addItem(items, controller),
              ),
            ),
            const SizedBox(width: PharmacoTokens.space8),
            IconButton(
              icon: const Icon(Icons.add_circle_rounded, color: PharmacoTokens.primaryBase),
              iconSize: 32,
              onPressed: () => _addItem(items, controller),
            ),
          ],
        ),
        if (items.isNotEmpty) ...[
          const SizedBox(height: PharmacoTokens.space8),
          Wrap(
            spacing: PharmacoTokens.space8,
            runSpacing: PharmacoTokens.space4,
            children: items.asMap().entries.map((entry) {
              return Chip(
                label: Text(entry.value),
                backgroundColor: PharmacoTokens.primarySurface,
                deleteIcon: const Icon(Icons.close_rounded, size: 16),
                onDeleted: () => _removeItem(items, entry.key),
                shape: RoundedRectangleBorder(borderRadius: PharmacoTokens.borderRadiusSmall),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildSectionCard({
    required ThemeData theme,
    required bool isDark,
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(PharmacoTokens.space16),
      decoration: BoxDecoration(
        color: isDark ? PharmacoTokens.darkSurface : PharmacoTokens.white,
        borderRadius: PharmacoTokens.borderRadiusCard,
        boxShadow: isDark ? null : PharmacoTokens.shadowZ1(),
        border: isDark ? Border.all(color: PharmacoTokens.darkBorder) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: PharmacoTokens.primaryBase),
              const SizedBox(width: PharmacoTokens.space8),
              Text(title, style: theme.textTheme.titleMedium),
            ],
          ),
          const Divider(height: PharmacoTokens.space24),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {TextInputType keyboardType = TextInputType.text, int maxLines = 1, Widget? suffixIcon, String? hintText}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: Icon(icon, color: PharmacoTokens.primaryBase),
        suffixIcon: suffixIcon,
      ),
      validator: (v) => v == null || v.isEmpty ? "Field required" : null,
    );
  }

  Widget _buildDropdown(String label, String? value, List<String> items, Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.info_outline_rounded, color: PharmacoTokens.primaryBase),
      ),
      validator: (v) => v == null ? "Required" : null,
    );
  }
}
