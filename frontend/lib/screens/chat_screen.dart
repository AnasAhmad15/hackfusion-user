import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../theme/design_tokens.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/voice_service.dart';
import 'package:animate_do/animate_do.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/localization_service.dart';
import '../services/storage_service.dart';
import 'package:image_picker/image_picker.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;
  late stt.SpeechToText _speech;
  final ElevenLabsService _elevenLabsService = ElevenLabsService();
  bool _isListening = false;
  bool _isWakeWordMode = false;
  String _recognizedText = "";
  bool _requirePrescription = false;
  final StorageService _storageService = StorageService();
  final ImagePicker _picker = ImagePicker();

  String _wakeWord = "hey pharma";

  Map<String, String> _translatedStrings = {
    'Hey Pharma Assistant': 'Hey Pharma Assistant',
    'Type your health concern...': 'Type your health concern...',
    'Listening...': 'Listening...',
  };

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    LocalizationService.addListener(_translateUI);
    _translateUI();
    
    // Check if there's an initial message from arguments
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null && args.containsKey('initialMessage')) {
        final initialMessage = args['initialMessage'] as String;
        _sendMessage(customMessage: initialMessage);
      }
    });
  }

  @override
  void dispose() {
    LocalizationService.removeListener(_translateUI);
    super.dispose();
  }

  void _translateUI() {
    if (!mounted) return;
    setState(() {
      _translatedStrings = {
        'Hey Pharma Assistant': LocalizationService.t('Hey Pharma Assistant'),
        'Type your health concern...': LocalizationService.t('Type your health concern...'),
        'Listening...': LocalizationService.t('Listening...'),
      };
    });
  }

  String t(String key) => _translatedStrings[key] ?? key;

  Future<void> _sendMessage({String? customMessage}) async {
    final text = customMessage ?? _controller.text.trim();
    if (text.isEmpty) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    setState(() {
      _messages.add({"sender": "user", "text": text});
      _isLoading = true;
    });
    _controller.clear();

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/chat'), // Centralized URL
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode({
          'message': text,
          'user_id': user.id,
          'language': LocalizationService.currentLanguage,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final reply = data['reply'] ?? "I couldn't understand that.";
        setState(() {
          _messages.add({"sender": "bot", "text": reply});
          _requirePrescription = data['require_prescription'] ?? false;
        });
        await _speak(reply);
      } else {
        setState(() {
          _messages.add({"sender": "ai", "text": "Error: ${response.reasonPhrase}"});
        });
      }
    } catch (e) {
      setState(() {
        _messages.add({"sender": "ai", "text": "Error: $e"});
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _directUploadPrescription() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() => _isLoading = true);
    try {
      final url = await _storageService.uploadPrescription(image);
      
      // Add a placeholder message to chat
      setState(() {
        _messages.add({"sender": "user", "text": "Uploaded a prescription: [Image]"});
      });

      // Send to backend with the image URL
      final user = Supabase.instance.client.auth.currentUser;
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/chat'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({
          'message': "I have uploaded my prescription. Here is the link: $url. Please process my order for the medicine we were discussing.",
          'user_id': user?.id,
          'language': LocalizationService.currentLanguage,
          'image_url': url
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final reply = data['reply'] ?? "";
        setState(() {
          _messages.add({"sender": "bot", "text": reply});
          _requirePrescription = data['require_prescription'] ?? false;
        });
        await _speak(reply);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Upload failed: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _speak(String text) async {
    // Remove asterisks for speech
    String cleanText = text.replaceAll("**", "").replaceAll("*", "");
    await _elevenLabsService.speak(cleanText);
  }

  void _listen() async {
    Navigator.pushNamed(context, '/s2s-voice');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: Text(t('Hey Pharma Assistant')),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isUser = message['sender'] == 'user';
                return FadeInUp(
                  duration: const Duration(milliseconds: 300),
                  child: Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.7,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isUser ? const Color(0xFF673AB7) : Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(20),
                          topRight: const Radius.circular(20),
                          bottomLeft: Radius.circular(isUser ? 20 : 0),
                          bottomRight: Radius.circular(isUser ? 0 : 20),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        message['text']!,
                        style: TextStyle(
                          color: isUser ? Colors.white : Colors.black87,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Center(child: CircularProgressIndicator()),
            ),
          
          if (_isListening)
            Pulse(
              infinite: true,
              child: Container(
                padding: const EdgeInsets.all(8),
                child: Text(
                  t("Listening..."),
                  style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                ),
              ),
            ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: t('Type your health concern...'),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF5F6F9),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                    onSubmitted: (value) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                if (_requirePrescription)
                  IconButton(
                    icon: const Icon(Icons.file_upload, color: Colors.orangeAccent),
                    tooltip: "Upload Prescription",
                    onPressed: _directUploadPrescription,
                  ),
                const SizedBox(width: 8),
                GestureDetector(
                  onLongPress: _listen,
                  onLongPressUp: () {
                    if (_isListening) {
                      _speech.stop();
                      setState(() => _isListening = false);
                    }
                  },
                  child: FloatingActionButton(
                    onPressed: _isListening ? () {
                      _speech.stop();
                      setState(() => _isListening = false);
                    } : _listen,
                    backgroundColor: _isListening ? Colors.redAccent : const Color(0xFF673AB7),
                    elevation: 2,
                    mini: true,
                    child: Icon(_isListening ? Icons.mic : Icons.mic_none, color: Colors.white),
                  ),
                ),
                if (_requirePrescription)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: IconButton(
                      icon: const Icon(Icons.file_upload, color: Colors.orangeAccent),
                      tooltip: "Upload Prescription",
                      onPressed: () => Navigator.pushNamed(context, '/upload-prescription'),
                    ),
                  ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: Color(0xFF673AB7)),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
