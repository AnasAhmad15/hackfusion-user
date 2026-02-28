import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

class EmergencyNotificationService {
  static final EmergencyNotificationService _instance = EmergencyNotificationService._internal();
  factory EmergencyNotificationService() => _instance;
  EmergencyNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    
    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handled in main.dart or via navigation
      },
    );

    // Create a high priority channel for SOS
    const androidChannel = AndroidNotificationChannel(
      'emergency_sos_channel',
      'Emergency SOS Alerts',
      description: 'Used for critical emergency alerts and confirmation',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  Future<void> showFullScreenEmergencyNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'emergency_sos_channel',
      'Emergency SOS Alerts',
      channelDescription: 'Used for critical emergency alerts and confirmation',
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.call,
      visibility: NotificationVisibility.public,
      ongoing: true,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      playSound: true,
      styleInformation: BigTextStyleInformation(''),
    );

    await _notificationsPlugin.show(
      888,
      '🚨 EMERGENCY DETECTED',
      'WAKING SYSTEM FOR SOS CONFIRMATION',
      const NotificationDetails(android: androidDetails),
      payload: 'emergency_shake',
    );
  }

  Future<void> cancelNotification() async {
    await _notificationsPlugin.cancel(888);
  }
}
