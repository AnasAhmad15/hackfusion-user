import 'package:flutter/material.dart';
import '../models/health_profile_model.dart';
import '../services/health_profile_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/design_tokens.dart';
import '../widgets/pharmaco_button.dart';

class HealthProfileScreen extends StatefulWidget {
  const HealthProfileScreen({Key? key}) : super(key: key);

  @override
  _HealthProfileScreenState createState() => _HealthProfileScreenState();
}

class _HealthProfileScreenState extends State<HealthProfileScreen> {
  final _service = HealthProfileService();
  final _allergyController = TextEditingController();
  final _conditionController = TextEditingController();

  List<String> _allergies = [];
  List<String> _conditions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _service.getProfile();
      if (profile != null) {
        setState(() {
          _allergies = profile.allergies;
          _conditions = profile.chronicConditions;
        });
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final profile = HealthProfile(
      id: userId,
      allergies: _allergies,
      chronicConditions: _conditions,
      updatedAt: DateTime.now(),
    );

    try {
      await _service.updateProfile(profile);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully'), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _addItem(TextEditingController controller, List<String> list) {
    if (controller.text.isNotEmpty) {
      setState(() {
        list.add(controller.text.trim());
        controller.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Allergy & Health Profile')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Allergy & Health Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(PharmacoTokens.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Allergies
            Text('Allergies', style: theme.textTheme.headlineMedium),
            const SizedBox(height: PharmacoTokens.space12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _allergyController,
                    decoration: const InputDecoration(
                      hintText: 'Add Allergy',
                      prefixIcon: Icon(Icons.warning_amber_rounded),
                    ),
                    onSubmitted: (_) => _addItem(_allergyController, _allergies),
                  ),
                ),
                const SizedBox(width: PharmacoTokens.space8),
                IconButton(
                  icon: const Icon(Icons.add_circle_rounded, color: PharmacoTokens.primaryBase),
                  iconSize: 32,
                  onPressed: () => _addItem(_allergyController, _allergies),
                ),
              ],
            ),
            const SizedBox(height: PharmacoTokens.space8),
            Wrap(
              spacing: PharmacoTokens.space8,
              runSpacing: PharmacoTokens.space4,
              children: _allergies.map((a) => Chip(
                label: Text(a),
                backgroundColor: PharmacoTokens.primarySurface,
                deleteIcon: const Icon(Icons.close_rounded, size: 16),
                onDeleted: () => setState(() => _allergies.remove(a)),
              )).toList(),
            ),
            const SizedBox(height: PharmacoTokens.space24),

            // Chronic Conditions
            Text('Chronic Conditions', style: theme.textTheme.headlineMedium),
            const SizedBox(height: PharmacoTokens.space12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _conditionController,
                    decoration: const InputDecoration(
                      hintText: 'Add Condition',
                      prefixIcon: Icon(Icons.history_rounded),
                    ),
                    onSubmitted: (_) => _addItem(_conditionController, _conditions),
                  ),
                ),
                const SizedBox(width: PharmacoTokens.space8),
                IconButton(
                  icon: const Icon(Icons.add_circle_rounded, color: PharmacoTokens.primaryBase),
                  iconSize: 32,
                  onPressed: () => _addItem(_conditionController, _conditions),
                ),
              ],
            ),
            const SizedBox(height: PharmacoTokens.space8),
            Wrap(
              spacing: PharmacoTokens.space8,
              runSpacing: PharmacoTokens.space4,
              children: _conditions.map((c) => Chip(
                label: Text(c),
                backgroundColor: PharmacoTokens.primarySurface,
                deleteIcon: const Icon(Icons.close_rounded, size: 16),
                onDeleted: () => setState(() => _conditions.remove(c)),
              )).toList(),
            ),
            const SizedBox(height: PharmacoTokens.space32),

            PharmacoButton(
              label: 'Save Profile',
              icon: Icons.save_rounded,
              onPressed: _saveProfile,
            ),
          ],
        ),
      ),
    );
  }
}
