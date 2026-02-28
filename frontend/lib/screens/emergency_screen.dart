import 'package:flutter/material.dart';
import '../services/emergency_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/design_tokens.dart';
import '../widgets/pharmaco_button.dart';

class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  bool _isListening = false;
  final EmergencyService _emergencyService = EmergencyService();
  final _client = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _startEmergencyMode();
  }

  void _startEmergencyMode() {
    setState(() => _isListening = true);
    _emergencyService.startListening(context);
  }

  void _stopEmergencyMode() {
    setState(() => _isListening = false);
    _emergencyService.stopListening();
  }

  @override
  void dispose() {
    _emergencyService.stopListening();
    super.dispose();
  }

  Future<void> _orderEmergencyKit() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    setState(() => _isListening = false);

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      await _client.from('orders').insert({
        'user_id': user.id,
        'is_emergency': true,
        'status': 'priority_dispatch',
        'delivery_estimate_minutes': 15,
        'items': [{'name': 'Emergency First Aid Kit', 'quantity': 1, 'price': 500}],
        'total_price': 500,
        'customer_address': 'Current Live Location',
      });

      Navigator.pop(context);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: PharmacoTokens.borderRadiusCard),
          title: const Text('Priority Order Placed'),
          content: const Text('An emergency kit is being dispatched to your location. Expected delivery: 15 minutes.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
          ],
        ),
      );
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to place emergency order: $e')),
      );
    } finally {
      setState(() => _isListening = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Emergency Mode')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(PharmacoTokens.space24),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                // Status circle
                Container(
                  width: 120, height: 120,
                  decoration: BoxDecoration(
                    color: _isListening ? PharmacoTokens.emergencyBg : PharmacoTokens.neutral100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isListening ? Icons.vibration_rounded : Icons.not_interested_rounded,
                    size: 56,
                    color: _isListening ? PharmacoTokens.error : PharmacoTokens.neutral400,
                  ),
                ),
                const SizedBox(height: PharmacoTokens.space24),
                Text(
                  _isListening ? 'Shake Phone for Help' : 'Emergency Mode Off',
                  style: theme.textTheme.headlineLarge,
                ),
                const SizedBox(height: PharmacoTokens.space16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: PharmacoTokens.space16),
                  child: Text(
                    'In case of a medical emergency, shake your phone vigorously. We will notify your emergency contacts and dispatch a priority medical kit.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(color: PharmacoTokens.neutral500),
                  ),
                ),
                const SizedBox(height: PharmacoTokens.space40),

                // Quick Order button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _orderEmergencyKit,
                    icon: const Icon(Icons.flash_on_rounded),
                    label: const Text('Quick Order Emergency Kit'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PharmacoTokens.warning,
                      foregroundColor: PharmacoTokens.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: PharmacoTokens.borderRadiusMedium),
                    ),
                  ),
                ),
                const SizedBox(height: PharmacoTokens.space16),
                PharmacoButton.text(
                  label: _isListening ? 'Deactivate Shake Detection' : 'Activate Shake Detection',
                  onPressed: () {
                    if (_isListening) {
                      _stopEmergencyMode();
                    } else {
                      _startEmergencyMode();
                    }
                  },
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
