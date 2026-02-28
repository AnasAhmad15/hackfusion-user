import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../config/app_config.dart';
import '../services/voice_service.dart';
import '../services/localization_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/storage_service.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/design_tokens.dart';

class S2SConversationPage extends StatefulWidget {
  const S2SConversationPage({Key? key}) : super(key: key);

  @override
  _S2SConversationPageState createState() => _S2SConversationPageState();
}

class _S2SConversationPageState extends State<S2SConversationPage>
    with TickerProviderStateMixin {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final ElevenLabsService _elevenLabsService = ElevenLabsService();

  bool _isListening = false;
  bool _isProcessing = false;
  String _lastWords = "";
  String _statusText = "Tap the mic to start";
  final List<Map<String, String>> _conversationHistory = [];
  final ScrollController _scrollController = ScrollController();
  bool _requirePrescription = false;
  final StorageService _storageService = StorageService();
  final ImagePicker _picker = ImagePicker();

  // Animation controllers
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _initSpeech();

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    _waveController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _initSpeech() async {
    await _speech.initialize();
  }

  // ────────────────────────────────────────────────
  // SPEECH LOGIC (unchanged)
  // ────────────────────────────────────────────────

  Future<void> _startListening() async {
    bool available = await _speech.initialize(
      onStatus: (status) {
        debugPrint('Speech Status: $status');
        if (status == 'done' || status == 'notListening') {
          if (mounted) {
            setState(() => _isListening = false);
            if (_lastWords.trim().isNotEmpty && !_isProcessing) {
              _processVoiceInput(_lastWords);
            }
          }
        }
      },
      onError: (val) {
        debugPrint('Speech Error: $val');
        if (mounted) setState(() => _isListening = false);
      },
    );

    if (available) {
      if (mounted) {
        setState(() {
          _isListening = true;
          _lastWords = "";
          _statusText = "Listening...";
        });
      }

      await _speech.listen(
        onResult: (result) {
          if (mounted) {
            setState(() => _lastWords = result.recognizedWords);
            if (result.finalResult && result.recognizedWords.trim().isNotEmpty) {
              _processVoiceInput(result.recognizedWords);
            }
          }
        },
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 5),
        partialResults: true,
        cancelOnError: true,
        listenMode: stt.ListenMode.dictation,
      );
    }
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    if (mounted) {
      setState(() => _isListening = false);
      if (_lastWords.trim().isNotEmpty && !_isProcessing) {
        _processVoiceInput(_lastWords);
      }
    }
  }

  Future<void> _processVoiceInput(String text) async {
    if (text.trim().isEmpty || _isProcessing) return;

    if (mounted) {
      setState(() {
        _isProcessing = true;
        _isListening = false;
        _statusText = "Processing...";
        _conversationHistory.add({"role": "user", "content": text});
        _lastWords = "";
      });
      _scrollToBottom();
    }

    await _speech.stop();

    try {
      final user = Supabase.instance.client.auth.currentUser;
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/chat'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({
          'message': text,
          'user_id': user?.id ?? 'anonymous',
          'language': LocalizationService.currentLanguage,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final reply = data['reply'] ?? "";

        if (mounted) {
          setState(() {
            _statusText = "Speaking...";
            _conversationHistory.add({"role": "bot", "content": reply});
            _requirePrescription = data['require_prescription'] ?? false;
          });
          _scrollToBottom();
        }

        String cleanText = reply.replaceAll("**", "").replaceAll("*", "");
        await _elevenLabsService.speak(cleanText);

        if (mounted) {
          setState(() => _statusText = "Tap to talk again");
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _statusText = "Error occurred. Try again.");
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _directUploadPrescription() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    if (mounted) {
      setState(() {
        _isProcessing = true;
        _statusText = "Uploading...";
        _conversationHistory.add({"role": "user", "content": "Uploaded a prescription: [Image]"});
      });
      _scrollToBottom();
    }

    try {
      final url = await _storageService.uploadPrescription(image);
      final user = Supabase.instance.client.auth.currentUser;

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/chat'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({
          'message': "I have uploaded my prescription. Here is the link: $url. Please confirm my order details.",
          'user_id': user?.id ?? 'anonymous',
          'language': LocalizationService.currentLanguage,
          'image_url': url
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final reply = data['reply'] ?? "";

        if (mounted) {
          setState(() {
            _statusText = "Speaking...";
            _conversationHistory.add({"role": "bot", "content": reply});
            _requirePrescription = data['require_prescription'] ?? false;
          });
          _scrollToBottom();
        }

        String cleanText = reply.replaceAll("**", "").replaceAll("*", "");
        await _elevenLabsService.speak(cleanText);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _statusText = "Upload failed");
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusText = "Tap to talk again";
        });
      }
    }
  }

  // ────────────────────────────────────────────────
  // BUILD
  // ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final lastBotMessage = _conversationHistory.isNotEmpty
        ? _conversationHistory.lastWhere(
            (m) => m['role'] == 'bot',
            orElse: () => {'content': ''},
          )['content'] ?? ''
        : '';

    return Scaffold(
      backgroundColor: PharmacoTokens.white,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              PharmacoTokens.white,
              PharmacoTokens.primarySurface.withValues(alpha: 0.2),
              const Color(0xFFF3F0FF), // Soft violet
              PharmacoTokens.white,
            ],
            stops: const [0.0, 0.35, 0.65, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ─── Top Bar ───
              _buildTopBar(theme),

              // ─── Status ───
              Padding(
                padding: const EdgeInsets.only(top: PharmacoTokens.space4),
                child: Text(
                  LocalizationService.t(_statusText),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: PharmacoTokens.neutral400,
                    fontWeight: PharmacoTokens.weightMedium,
                    letterSpacing: 0.5,
                  ),
                ),
              ),

              // ─── Orb + Wave + Text ───
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Dotted Particle Sphere
                    _buildParticleSphere(size),

                    // Sound Wave Bars (when active)
                    const SizedBox(height: PharmacoTokens.space16),
                    _buildSoundWave(),

                    const SizedBox(height: PharmacoTokens.space24),

                    // Text display
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: PharmacoTokens.space24),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        child: _isListening && _lastWords.isNotEmpty
                            ? Text(
                                _lastWords,
                                key: ValueKey('live_$_lastWords'),
                                textAlign: TextAlign.center,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: PharmacoTokens.neutral800,
                                  fontWeight: PharmacoTokens.weightSemiBold,
                                  height: 1.3,
                                ),
                              )
                            : lastBotMessage.isNotEmpty
                                ? Text(
                                    lastBotMessage.length > 160
                                        ? '${lastBotMessage.substring(0, 160)}...'
                                        : lastBotMessage,
                                    key: ValueKey('response_$lastBotMessage'),
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      color: PharmacoTokens.neutral600,
                                      height: 1.5,
                                    ),
                                  )
                                : Text(
                                    'Ask me anything about\nmedicines or health',
                                    key: const ValueKey('idle'),
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      color: PharmacoTokens.neutral400,
                                      height: 1.5,
                                    ),
                                  ),
                      ),
                    ),
                  ],
                ),
              ),

              // ─── Bottom Controls ───
              _buildBottomControls(theme),
            ],
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────
  // TOP BAR
  // ────────────────────────────────────────────────

  Widget _buildTopBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: PharmacoTokens.space16,
        vertical: PharmacoTokens.space8,
      ),
      child: Row(
        children: [
          _circleButton(Icons.arrow_back_rounded, () => Navigator.pop(context)),
          const Spacer(),
          Text(
            'Pharma Voice AI',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: PharmacoTokens.weightSemiBold,
            ),
          ),
          const Spacer(),
          _circleButton(Icons.history_rounded, _showConversationHistory),
        ],
      ),
    );
  }

  Widget _circleButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42, height: 42,
        decoration: BoxDecoration(
          color: PharmacoTokens.white,
          shape: BoxShape.circle,
          boxShadow: PharmacoTokens.shadowZ1(),
        ),
        child: Icon(icon, size: 20, color: PharmacoTokens.neutral700),
      ),
    );
  }

  // ────────────────────────────────────────────────
  // DOTTED PARTICLE SPHERE
  // ────────────────────────────────────────────────

  Widget _buildParticleSphere(Size screenSize) {
    final orbSize = screenSize.width * 0.55;
    final isActive = _isListening || _isProcessing;

    return AnimatedBuilder(
      animation: Listenable.merge([_rotationController, _pulseController]),
      builder: (context, child) {
        final pulse = isActive
            ? 0.9 + (_pulseController.value * 0.2) // 0.9 to 1.1
            : 1.0;

        return Transform.scale(
          scale: pulse,
          child: SizedBox(
            width: orbSize,
            height: orbSize,
            child: CustomPaint(
              painter: _DottedSpherePainter(
                rotationY: _rotationController.value * 2 * math.pi,
                rotationX: math.pi * 0.15, // slight tilt
                isListening: _isListening,
                isProcessing: _isProcessing,
              ),
            ),
          ),
        );
      },
    );
  }

  // ────────────────────────────────────────────────
  // SOUND WAVE BARS
  // ────────────────────────────────────────────────

  Widget _buildSoundWave() {
    final isActive = _isListening || _isProcessing;

    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        return SizedBox(
          height: 32,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              // Stagger each bar
              final phase = (index - 2).abs() / 2.0; // center bars taller
              final baseHeight = isActive ? 8.0 : 4.0;
              final maxExtra = isActive ? 20.0 : 0.0;
              final wave = math.sin((_waveController.value * math.pi) + (index * 0.8));
              final barHeight = baseHeight + (maxExtra * (1.0 - phase * 0.3) * wave.abs());

              return AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 4,
                height: barHeight.clamp(4.0, 28.0),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: isActive
                      ? PharmacoTokens.primaryBase.withValues(alpha: 0.6 + wave.abs() * 0.4)
                      : PharmacoTokens.neutral300,
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  // ────────────────────────────────────────────────
  // BOTTOM CONTROLS
  // ────────────────────────────────────────────────

  Widget _buildBottomControls(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PharmacoTokens.space32,
        PharmacoTokens.space8,
        PharmacoTokens.space32,
        PharmacoTokens.space24,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Upload prescription (conditional)
          if (_requirePrescription) ...[
            _circleButton(Icons.file_upload_outlined, _directUploadPrescription),
            const SizedBox(width: PharmacoTokens.space20),
          ],

          // Main Mic
          GestureDetector(
            onTap: _isProcessing
                ? null
                : (_isListening ? _stopListening : _startListening),
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _isListening
                      ? [const Color(0xFFEF4444), const Color(0xFFDC2626)]
                      : _isProcessing
                          ? [const Color(0xFF6366F1), const Color(0xFF8B5CF6)]
                          : [PharmacoTokens.primaryBase, const Color(0xFF2563EB)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: (_isListening
                            ? const Color(0xFFEF4444)
                            : _isProcessing
                                ? const Color(0xFF6366F1)
                                : PharmacoTokens.primaryBase)
                        .withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                _isListening
                    ? Icons.stop_rounded
                    : (_isProcessing ? Icons.auto_awesome_rounded : Icons.mic_rounded),
                color: Colors.white,
                size: 32,
              ),
            ),
          ),

          const SizedBox(width: PharmacoTokens.space20),

          // Close
          _circleButton(Icons.close_rounded, () => Navigator.pop(context)),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────
  // CONVERSATION HISTORY
  // ────────────────────────────────────────────────

  void _showConversationHistory() {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(PharmacoTokens.radiusCard)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Column(
          children: [
            const SizedBox(height: PharmacoTokens.space12),
            Container(width: 40, height: 4,
              decoration: BoxDecoration(color: PharmacoTokens.neutral300, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.all(PharmacoTokens.space16),
              child: Text('Conversation', style: theme.textTheme.headlineMedium),
            ),
            Expanded(
              child: _conversationHistory.isEmpty
                  ? Center(
                      child: Text(
                        'No conversation yet.\nTap the mic to start talking.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(color: PharmacoTokens.neutral400),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: PharmacoTokens.space16),
                      itemCount: _conversationHistory.length,
                      itemBuilder: (context, index) {
                        final msg = _conversationHistory[index];
                        final isUser = msg['role'] == 'user';
                        return Align(
                          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: PharmacoTokens.space8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: PharmacoTokens.space16, vertical: PharmacoTokens.space12,
                            ),
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                            decoration: BoxDecoration(
                              color: isUser ? PharmacoTokens.primaryBase : PharmacoTokens.neutral100,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(16),
                                topRight: const Radius.circular(16),
                                bottomLeft: Radius.circular(isUser ? 16 : 0),
                                bottomRight: Radius.circular(isUser ? 0 : 16),
                              ),
                            ),
                            child: Text(
                              msg['content']!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: isUser ? Colors.white : PharmacoTokens.neutral700,
                                height: 1.4,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// DOTTED SPHERE PAINTER  — 3D particle globe
// ─────────────────────────────────────────────────

class _DottedSpherePainter extends CustomPainter {
  final double rotationY;
  final double rotationX;
  final bool isListening;
  final bool isProcessing;

  _DottedSpherePainter({
    required this.rotationY,
    required this.rotationX,
    required this.isListening,
    required this.isProcessing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = size.width * 0.42;

    // Number of rings (latitude) and dots per ring (longitude)
    const int latCount = 18;
    const int lonCount = 28;

    // Precompute rotation matrices
    final cosRY = math.cos(rotationY);
    final sinRY = math.sin(rotationY);
    final cosRX = math.cos(rotationX);
    final sinRX = math.sin(rotationX);

    // Collect dots with z-depth for painter's algorithm
    final dots = <_Dot3D>[];

    for (int lat = 0; lat <= latCount; lat++) {
      final phi = math.pi * lat / latCount; // 0 to PI
      final sinPhi = math.sin(phi);
      final cosPhi = math.cos(phi);

      for (int lon = 0; lon < lonCount; lon++) {
        final theta = 2 * math.pi * lon / lonCount; // 0 to 2*PI

        // 3D point on unit sphere
        double x = sinPhi * math.cos(theta);
        double y = cosPhi;
        double z = sinPhi * math.sin(theta);

        // Rotate around Y axis
        final x1 = x * cosRY + z * sinRY;
        final z1 = -x * sinRY + z * cosRY;

        // Rotate around X axis
        final y1 = y * cosRX - z1 * sinRX;
        final z2 = y * sinRX + z1 * cosRX;

        dots.add(_Dot3D(
          screenX: cx + x1 * radius,
          screenY: cy + y1 * radius,
          z: z2,
          lat: lat,
          lon: lon,
        ));
      }
    }

    // Sort back-to-front
    dots.sort((a, b) => a.z.compareTo(b.z));

    // Draw each dot
    for (final dot in dots) {
      // Depth-based properties
      final depth = (dot.z + 1) / 2; // 0 (far) to 1 (near)
      final dotRadius = 1.2 + depth * 2.8; // 1.2 to 4.0
      final opacity = 0.08 + depth * 0.85; // 0.08 to 0.93

      // Color based on position — gradient from cyan (top) → blue (mid) → violet (bottom)
      final yNorm = (dot.lat / latCount); // 0 to 1 top-to-bottom
      Color dotColor;
      if (isListening) {
        dotColor = Color.lerp(
          const Color(0xFF06B6D4), // Cyan-500
          const Color(0xFF8B5CF6), // Violet-500
          yNorm,
        )!;
      } else if (isProcessing) {
        dotColor = Color.lerp(
          const Color(0xFF8B5CF6), // Violet-500
          const Color(0xFF6366F1), // Indigo-500
          yNorm,
        )!;
      } else {
        dotColor = Color.lerp(
          const Color(0xFF38BDF8), // Sky-400
          const Color(0xFF6366F1), // Indigo-500
          yNorm,
        )!;
      }

      final paint = Paint()
        ..color = dotColor.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(dot.screenX, dot.screenY), dotRadius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DottedSpherePainter oldDelegate) =>
      rotationY != oldDelegate.rotationY ||
      isListening != oldDelegate.isListening ||
      isProcessing != oldDelegate.isProcessing;
}

class _Dot3D {
  final double screenX;
  final double screenY;
  final double z;
  final int lat;
  final int lon;

  _Dot3D({
    required this.screenX,
    required this.screenY,
    required this.z,
    required this.lat,
    required this.lon,
  });
}
