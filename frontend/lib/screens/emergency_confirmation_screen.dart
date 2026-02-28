import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pharmaco_frontend/services/emergency_service.dart';
import 'package:pharmaco_frontend/services/emergency_notification_service.dart';
import '../theme/design_tokens.dart';

class EmergencyConfirmationScreen extends StatefulWidget {
  const EmergencyConfirmationScreen({Key? key}) : super(key: key);

  @override
  _EmergencyConfirmationScreenState createState() => _EmergencyConfirmationScreenState();
}

class _EmergencyConfirmationScreenState extends State<EmergencyConfirmationScreen> {
  int _secondsRemaining = 10;
  Timer? _timer;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _timer?.cancel();
        _triggerEmergency();
      }
    });
  }

  Future<void> _triggerEmergency() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      await EmergencyService.triggerSOS(
        position.latitude,
        position.longitude,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Emergency Alert Sent!'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error triggering emergency: $e');
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _cancelEmergency() {
    _timer?.cancel();
    EmergencyNotificationService().cancelNotification();
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Emergency confirmation is intentionally dark/urgent – but we still use token-based styling
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF7A1212), // Deep emergency red
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: PharmacoTokens.space24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.warning_amber_rounded, size: 100, color: Colors.white),
                const SizedBox(height: PharmacoTokens.space32),
                const Text(
                  "EMERGENCY DETECTED",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: PharmacoTokens.weightBold,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: PharmacoTokens.space16),
                Text(
                  "Waking system for SOS confirmation.\nAre you safe?",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: PharmacoTokens.space40),

                // Countdown ring
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 160, height: 160,
                      child: CircularProgressIndicator(
                        value: _secondsRemaining / 10,
                        strokeWidth: 10,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    Text(
                      "$_secondsRemaining",
                      style: const TextStyle(
                        fontSize: 56,
                        fontWeight: PharmacoTokens.weightBold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 60),

                if (_isProcessing)
                  const CircularProgressIndicator(color: Colors.white)
                else ...[
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _cancelEmergency,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF7A1212),
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(PharmacoTokens.radiusCard),
                        ),
                      ),
                      child: const Text(
                        "YES, I'M SAFE",
                        style: TextStyle(fontSize: 20, fontWeight: PharmacoTokens.weightBold),
                      ),
                    ),
                  ),
                  const SizedBox(height: PharmacoTokens.space20),
                  TextButton(
                    onPressed: _triggerEmergency,
                    child: const Text(
                      "I NEED HELP NOW",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: PharmacoTokens.weightBold,
                        color: Colors.white,
                        decoration: TextDecoration.underline,
                        decorationColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
