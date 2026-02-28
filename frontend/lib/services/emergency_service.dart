import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shake/shake.dart';
import 'package:pharmaco_frontend/services/supabase_service.dart';
import 'package:flutter/services.dart';

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  debugPrint('HEY PHARMA SOS: Background Service onStart triggered');

  // Initialize notifications inside the isolate
  final FlutterLocalNotificationsPlugin notificationsPlugin = FlutterLocalNotificationsPlugin();
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);
  
  await notificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) async {
      debugPrint('HEY PHARMA SOS: Background isolate received notification click');
    },
  );

  try {
    await Supabase.initialize(
      url: SupabaseService.supabaseUrl,
      anonKey: SupabaseService.supabaseAnonKey,
    );
    debugPrint('HEY PHARMA SOS: Supabase initialized in background');
  } catch (e) {
    debugPrint('HEY PHARMA SOS: Supabase init failed: $e');
  }

  int shakeCount = 0;
  DateTime lastShakeTime = DateTime.now();
  const double shakeThreshold = 12.0; // Optimized threshold for directional detection
  String lastDirection = ""; // Track "left" or "right"
  int patternStep = 0; // 0: none, 1: left/right, 2: right/left, 3: left/right (Trigger)

  userAccelerometerEvents.listen((UserAccelerometerEvent event) async {
    // Detect direction based on X-axis (Left/Right)
    // event.x > 0 is Left tilt/move (usually)
    // event.x < 0 is Right tilt/move (usually)
    
    double xAcc = event.x;
    DateTime now = DateTime.now();

    // Reset pattern if too much time passes between movements (e.g., 1.5 seconds)
    if (now.difference(lastShakeTime).inMilliseconds > 1500) {
      patternStep = 0;
      lastDirection = "";
    }

    if (xAcc.abs() > shakeThreshold) {
      String currentDirection = xAcc > 0 ? "LEFT" : "RIGHT";

      // Pattern: Left -> Right -> Left (or vice versa)
      if (currentDirection != lastDirection) {
        if (patternStep == 0) {
          patternStep = 1; // First movement detected
        } else if (patternStep == 1) {
          patternStep = 2; // Second opposite movement detected
        } else if (patternStep == 2) {
          patternStep = 3; // Third opposite movement detected -> TRIGGER
        }

        lastDirection = currentDirection;
        lastShakeTime = now;
        debugPrint('HEY PHARMA SOS: Gesture Step $patternStep ($currentDirection) detected');

        if (patternStep >= 3) {
          patternStep = 0; // Reset after trigger
          lastDirection = "";
          debugPrint('HEY PHARMA SOS: LEFT-RIGHT-LEFT PATTERN MATCHED! TRIGGERING...');
          
          service.invoke('emergency_triggered');
          
          const AndroidNotificationDetails details = AndroidNotificationDetails(
            'sos_high_v4', 
            '🚨 CRITICAL SOS ALERTS',
            channelDescription: 'Emergency SOS confirmation required',
            importance: Importance.max,
            priority: Priority.max,
            fullScreenIntent: true,
            ongoing: true,
            category: AndroidNotificationCategory.alarm,
            visibility: NotificationVisibility.public,
            playSound: true,
            enableVibration: true,
            ticker: 'EMERGENCY SOS',
            showWhen: true,
            autoCancel: false,
          );
          
          await notificationsPlugin.show(
            999, 
            '🚨 EMERGENCY GESTURE DETECTED', 
            'TAP NOW to confirm your safety or send SOS!', 
            const NotificationDetails(android: details),
            payload: 'trigger_emergency'
          );
        }
      }
    }
  });
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

class EmergencyService {
  static final EmergencyService _instance = EmergencyService._internal();
  factory EmergencyService() => _instance;
  EmergencyService._internal();

  bool _isPrompting = false;
  ShakeDetector? _backgroundShakeDetector;

  static Future<void> initializeBackgroundService() async {
    try {
      final service = FlutterBackgroundService();

      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'emergency_service',
        'Emergency Protection',
        description: 'Monitoring for emergency gestures',
        importance: Importance.max, // High importance for SOS
        enableVibration: true,
        playSound: true,
      );

      final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
          FlutterLocalNotificationsPlugin();

      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      await service.configure(
        androidConfiguration: AndroidConfiguration(
          onStart: onStart,
          autoStart: true,
          isForegroundMode: true,
          notificationChannelId: 'emergency_service',
          initialNotificationTitle: 'PharmaCo Protection Active',
          initialNotificationContent: 'Monitoring for SOS gestures (Shake phone)',
          foregroundServiceNotificationId: 888,
          autoStartOnBoot: true,
        ),
        iosConfiguration: IosConfiguration(
          autoStart: true,
          onForeground: onStart,
          onBackground: onIosBackground,
        ),
      );
      debugPrint('Background service configured successfully');
    } catch (e) {
      debugPrint('Error configuring background service: $e');
    }
  }

  static void initializeGlobalListener(BuildContext context) {
    try {
      FlutterBackgroundService().on('emergency_triggered').listen((event) {
        debugPrint('HEY PHARMA SOS: Background emergency event received in UI');
        _instance._showEmergencyPrompt(context);
      });

      // Handle notification clicks when app is in background
      final FlutterLocalNotificationsPlugin notifications = FlutterLocalNotificationsPlugin();
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initializationSettings =
          InitializationSettings(android: initializationSettingsAndroid);
      
      notifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          if (response.payload == 'trigger_emergency') {
            debugPrint('HEY PHARMA SOS: Notification tapped, triggering UI prompt');
            _instance._showEmergencyPrompt(context);
          }
        },
      );
    } catch (e) {
      debugPrint('HEY PHARMA SOS: Error initializing global listener: $e');
    }
  }

  void startListening(BuildContext context) {
    debugPrint('HEY PHARMA SOS: startListening called in UI');
    _backgroundShakeDetector ??= ShakeDetector.autoStart(
      onPhoneShake: (event) {
        debugPrint('HEY PHARMA SOS: SHAKE DETECTED IN FOREGROUND!');
        if (!_isPrompting) {
          _showEmergencyPrompt(context);
        }
      },
      shakeThresholdGravity: 2.5,
    );
  }

  void stopListening() {
    _backgroundShakeDetector?.stopListening();
  }

  Future<void> _showEmergencyPrompt(BuildContext context) async {
    _isPrompting = true;
    int secondsLeft = 10;
    Timer? countdownTimer;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            countdownTimer ??= Timer.periodic(const Duration(seconds: 1), (timer) {
              if (secondsLeft > 0) {
                setState(() => secondsLeft--);
              } else {
                timer.cancel();
                Navigator.of(context).pop(true); // Auto-confirm on timeout
              }
            });

            return AlertDialog(
              title: const Text('EMERGENCY DETECTED', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Are you in an emergency?'),
                  const SizedBox(height: 20),
                  Text('Sending alerts in $secondsLeft seconds...', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    countdownTimer?.cancel();
                    Navigator.of(context).pop(false);
                  },
                  child: const Text('I AM SAFE'),
                ),
                ElevatedButton(
                  onPressed: () {
                    countdownTimer?.cancel();
                    Navigator.of(context).pop(true);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('YES, HELP!'),
                ),
              ],
            );
          },
        );
      },
    );

    _isPrompting = false;
    if (confirmed == true) {
      // Use Geolocator to get position for the old manual method
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition();
      } catch (e) {
        debugPrint('HEY PHARMA SOS: Could not get position for prompt trigger: $e');
      }
      
      await triggerSOS(
        position?.latitude ?? 0.0,
        position?.longitude ?? 0.0,
      );
    }
  }

  static Future<void> triggerSOS(double latitude, double longitude) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;

    try {
      await client.from('orders').insert({
        'user_id': user.id,
        'is_emergency': true,
        'status': 'pending',
        'delivery_estimate_minutes': 15,
        'customer_address': '$latitude, $longitude',
      });

      String sosText = "EMERGENCY! I need immediate help. I am NOT safe.";
      try {
        final profileData = await client
            .from('user_profiles')
            .select('custom_sos_message')
            .eq('id', user.id)
            .maybeSingle();
        if (profileData != null && profileData['custom_sos_message'] != null) {
          sosText = profileData['custom_sos_message'];
        }
      } catch (_) {}

      await client.functions.invoke('send-sos-sms', body: {
        'user_id': user.id,
        'latitude': latitude,
        'longitude': longitude,
        'message': sosText
      });
      debugPrint('HEY PHARMA SOS: Automated SOS triggered successfully');
    } catch (e) {
      debugPrint('HEY PHARMA SOS: triggerSOS failed: $e');
    }
  }
}
