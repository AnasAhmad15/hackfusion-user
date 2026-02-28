import 'dart:async';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:sensors_plus/sensors_plus.dart';

// The task handler that will run in the background isolate.
class BackgroundTaskHandler extends TaskHandler {
  StreamSubscription<UserAccelerometerEvent>? _accelerometerSubscription;
  int _shakeCount = 0;
  DateTime _lastShakeTime = DateTime.now();
  static const double _shakeThreshold = 20.0;
  static const int _shakeSlopTimeMs = 500;
  static const int _shakeCountResetTimeMs = 3000;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    debugPrint('Foreground Service: onStart');
    
    // Listen to accelerometer data
    _accelerometerSubscription = userAccelerometerEvents.listen((UserAccelerometerEvent event) {
      double acceleration = event.x.abs() + event.y.abs() + event.z.abs();
      
      if (acceleration > _shakeThreshold) {
        final now = DateTime.now();
        
        // Ignore shakes that are too close together (slop time)
        if (now.difference(_lastShakeTime).inMilliseconds > _shakeSlopTimeMs) {
          _shakeCount++;
          _lastShakeTime = now;
          debugPrint('Foreground Service: Shake detected! Count: $_shakeCount');
          
          if (_shakeCount >= 2) {
            _shakeCount = 0;
            debugPrint('Foreground Service: EMERGENCY_SHAKE_DETECTED Triggered');
            // Send critical event to main app using the new key
            FlutterForegroundTask.sendDataToMain('EMERGENCY_SHAKE_DETECTED');
          }
        }
      }
      
      // Reset shake count if too much time has passed
      if (DateTime.now().difference(_lastShakeTime).inMilliseconds > _shakeCountResetTimeMs) {
        _shakeCount = 0;
      }
    });
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Optional: perform periodic tasks here
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    debugPrint('Foreground Service: onDestroy (isTimeout: $isTimeout)');
    await _accelerometerSubscription?.cancel();
  }

  @override
  void onNotificationPressed() {
    // Called when the notification is pressed
    FlutterForegroundTask.launchApp();
  }
}
