import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/reminder_model.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class ReminderService {
  final _client = Supabase.instance.client;
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  static final ReminderService _instance = ReminderService._internal();
  factory ReminderService() => _instance;
  ReminderService._internal();

  Future<void> initialize() async {
    tz.initializeTimeZones();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);
    await _notifications.initialize(initSettings);
  }

  Future<List<MedicineReminder>> getReminders() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    final response = await _client
        .from('medicine_reminders')
        .select()
        .eq('user_id', user.id);

    return (response as List).map((json) => MedicineReminder.fromJson(json)).toList();
  }

  Future<void> addReminder(MedicineReminder reminder) async {
    final response = await _client.from('medicine_reminders').insert(reminder.toJson()).select().single();
    final newReminder = MedicineReminder.fromJson(response);
    await _scheduleNotification(newReminder);
  }

  Future<void> deleteReminder(String id) async {
    await _client.from('medicine_reminders').delete().eq('id', id);
    await _notifications.cancel(id.hashCode);
  }

  Future<void> _scheduleNotification(MedicineReminder reminder) async {
    final timeParts = reminder.scheduleTime.split(':');
    final hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);

    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _notifications.zonedSchedule(
      reminder.id.hashCode,
      'Medicine Reminder',
      'Time to take ${reminder.dosage} of ${reminder.medicineName}',
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails('reminder_channel', 'Reminders', importance: Importance.max),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
}
