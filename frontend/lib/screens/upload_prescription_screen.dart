import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/storage_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/design_tokens.dart';
import '../widgets/pharmaco_button.dart';

import 'medicine_search_screen.dart';

class UploadPrescriptionScreen extends StatefulWidget {
  const UploadPrescriptionScreen({Key? key}) : super(key: key);

  @override
  _UploadPrescriptionScreenState createState() => _UploadPrescriptionScreenState();
}

class _UploadPrescriptionScreenState extends State<UploadPrescriptionScreen> {
  XFile? _imageFile;
  final ImagePicker _picker = ImagePicker();
  final StorageService _storageService = StorageService();
  final _client = Supabase.instance.client;
  bool _isUploading = false;
  List<dynamic> _extractedMedicines = [];
  bool _isLoadingHistory = true;

  @override
  void initState() {
    super.initState();
    _fetchLastExtraction();
  }

  Future<void> _fetchLastExtraction() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    final response = await _client
        .from('prescriptions')
        .select('extracted_medicines')
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (response != null && response['extracted_medicines'] != null) {
      setState(() => _extractedMedicines = response['extracted_medicines']);
    }
    setState(() => _isLoadingHistory = false);
  }

  Future<void> _pickImage() async {
    final XFile? selectedImage = await _picker.pickImage(source: ImageSource.gallery);
    setState(() => _imageFile = selectedImage);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Upload Prescription')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(PharmacoTokens.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image picker area
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: isDark ? PharmacoTokens.darkSurface : PharmacoTokens.neutral100,
                  borderRadius: PharmacoTokens.borderRadiusCard,
                  border: Border.all(
                    color: PharmacoTokens.neutral300,
                    width: 1.5,
                    strokeAlign: BorderSide.strokeAlignInside,
                  ),
                ),
                child: _imageFile != null
                    ? ClipRRect(
                        borderRadius: PharmacoTokens.borderRadiusCard,
                        child: Image.file(File(_imageFile!.path), fit: BoxFit.cover),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.cloud_upload_outlined,
                              size: 48, color: PharmacoTokens.neutral400),
                          const SizedBox(height: PharmacoTokens.space12),
                          Text('Tap to select prescription image',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: PharmacoTokens.neutral500,
                              )),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: PharmacoTokens.space16),

            // Upload button
            PharmacoButton(
              label: 'Upload Prescription',
              icon: Icons.cloud_upload_rounded,
              onPressed: _imageFile == null || _isUploading ? null : _uploadPrescription,
              isLoading: _isUploading,
            ),

            // Extracted medicines
            if (_extractedMedicines.isNotEmpty) ...[
              const SizedBox(height: PharmacoTokens.space24),
              Text('Extracted Medicines', style: theme.textTheme.headlineMedium),
              const SizedBox(height: PharmacoTokens.space12),
              ...List.generate(_extractedMedicines.length, (index) {
                final med = _extractedMedicines[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: PharmacoTokens.space8),
                  decoration: BoxDecoration(
                    color: isDark ? PharmacoTokens.darkSurface : PharmacoTokens.white,
                    borderRadius: PharmacoTokens.borderRadiusCard,
                    boxShadow: isDark ? null : PharmacoTokens.shadowZ1(),
                    border: isDark ? Border.all(color: PharmacoTokens.darkBorder) : null,
                  ),
                  child: ListTile(
                    shape: RoundedRectangleBorder(borderRadius: PharmacoTokens.borderRadiusCard),
                    leading: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: PharmacoTokens.primarySurface,
                        borderRadius: PharmacoTokens.borderRadiusSmall,
                      ),
                      child: const Icon(Icons.medication_rounded,
                          color: PharmacoTokens.primaryBase, size: 20),
                    ),
                    title: Text(med.toString(), style: theme.textTheme.bodyMedium),
                    trailing: SizedBox(
                      height: PharmacoTokens.buttonHeightSmall,
                      child: ElevatedButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const MedicineSearchScreen()),
                        ),
                        child: const Text('Refill'),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _uploadPrescription() async {
    if (_imageFile == null) return;

    setState(() => _isUploading = true);
    try {
      final imageUrl = await _storageService.uploadPrescription(_imageFile!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Prescription uploaded successfully! URL: $imageUrl'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _imageFile = null);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }
}
