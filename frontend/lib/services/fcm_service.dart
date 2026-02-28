import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class FCMService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'This channel is used for important notifications.',
    importance: Importance.max,
  );

  static Future<void> initialize() async {
    // 1. Request permissions
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('FCMService: User granted notification permission');
    }

    // 2. Initialize Flutter Local Notifications
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(android: androidSettings);
    
    await _localNotifications.initialize(initSettings);
    
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // 3. Configure FCM options
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 4. Get the token
    String? token = await _messaging.getToken();
    debugPrint('FCMService: Current Token: $token');
    if (token != null) {
      await _saveTokenToSupabase(token);
    }

    // 5. Listen for token refreshes
    _messaging.onTokenRefresh.listen((newToken) {
      _saveTokenToSupabase(newToken);
    });

    // 6. Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 7. Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('FCMService: Received foreground message: ${message.notification?.title}');
      
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && android != null) {
        _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _channel.id,
              _channel.name,
              channelDescription: _channel.description,
              importance: Importance.max,
              priority: Priority.high,
              icon: android.smallIcon,
            ),
          ),
        );
      }
    });
  }

  static Future<void> sendWelcomeNotification(String type) async {
    final user = Supabase.instance.client.auth.currentUser;
    debugPrint('FCMService: Attempting to send $type notification for user: ${user?.id}');
    if (user == null) {
      debugPrint('FCMService: No user logged in, skipping notification');
      return;
    }

    try {
      String? token = await _messaging.getToken();
      debugPrint('FCMService: FCM Token: $token');
      if (token == null) {
        debugPrint('FCMService: Could not retrieve FCM token');
        return;
      }

      final response = await Supabase.instance.client.functions.invoke(
        'welcome-notification',
        body: {
          'fcm_token': token,
          'full_name': user.userMetadata?['name'] ?? 'User',
          'type': type,
        },
      );
      debugPrint('FCMService: Welcome notification invoked. Status: ${response.status}, Data: ${response.data}');
    } catch (e) {
      debugPrint('FCMService: Error invoking welcome notification: $e');
    }
  }

  static Future<void> _saveTokenToSupabase(String token) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        debugPrint('FCMService: Saving token for user ${user.id}...');
        await Supabase.instance.client
            .from('user_profiles')
            .update({'fcm_token': token})
            .eq('id', user.id);
        debugPrint('FCMService: FCM Token successfully saved to Supabase');
      } catch (e) {
        debugPrint('FCMService: Error saving FCM Token to database: $e');
      }
    } else {
      debugPrint('FCMService: No user session found, token not saved to database');
    }
  }

  @pragma('vm:entry-point')
  static Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    debugPrint("Handling a background message: ${message.messageId}");
  }
}
