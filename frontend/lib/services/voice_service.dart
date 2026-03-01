import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import '../config/app_config.dart';

class ElevenLabsService {
  static const String _apiKey = "sk_2997fd7d3d9ef55025c8340f6ef27e91108bc3179bd92eec"; // Place your API key here
  static const String _voiceId = "21m00Tcm4TlvDq8ikWAM"; // Example: Rachel voice
  
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isSpeaking = false;
  bool get isSpeaking => _isSpeaking;

  Future<void> speak(String text, {VoidCallback? onComplete}) async {
    try {
      _isSpeaking = true;
      // Use the centralized base URL
      final String baseUrl = AppConfig.baseUrl;
      
      final response = await http.post(
        Uri.parse('$baseUrl/tts'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "text": text,
          "voice_id": _voiceId
        }),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data.containsKey('audio_base64')) {
          final bytes = base64Decode(data['audio_base64']);
          final dir = await getTemporaryDirectory();
          final file = File('${dir.path}/elevenlabs_audio.mp3');
          await file.writeAsBytes(bytes);
          
          // Set up completion listener
          _audioPlayer.onPlayerComplete.listen((event) {
            _isSpeaking = false;
            if (onComplete != null) onComplete();
          });

          await _audioPlayer.play(DeviceFileSource(file.path));
        } else {
          _isSpeaking = false;
          if (data.containsKey('error')) {
            print("Backend TTS Error: ${data['error']}");
          }
        }
      } else {
        _isSpeaking = false;
        print("Backend Response Error: ${response.statusCode}");
      }
    } catch (e) {
      _isSpeaking = false;
      print("Error calling Backend TTS: $e");
    }
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
    _isSpeaking = false;
  }
}
