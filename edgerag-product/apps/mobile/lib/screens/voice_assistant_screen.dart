import '../widgets/ai_request_picker.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import '../services/voice_capture.dart';
import '../models/models.dart';
import '../services/multimodal_ai_service.dart';
import '../services/agent_controller.dart';

class VoiceAssistantScreen extends StatefulWidget {
  final EquipmentModel equipment;
  final AiMode aiMode;

  const VoiceAssistantScreen({
    super.key,
    required this.equipment,
    this.aiMode = AiMode.smartAuto,
  });

  @override
  State<VoiceAssistantScreen> createState() => _VoiceAssistantScreenState();
}

class _VoiceAssistantScreenState extends State<VoiceAssistantScreen>
    with SingleTickerProviderStateMixin {
  late AiMode _requestMode = widget.aiMode;
  String _cloudProvider = 'auto';
  final _multimodalAi = MultimodalAiService();
  final _agent = AgentController();
  final _capture = VoiceCapture();
  Timer? _limit;

  bool _isListening = false;
  bool _isThinking = false;
  bool _isSpeaking = false;
  String _userSpokenText = '';
  String _assistantSpokenResponse = '';
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _multimodalAi.stopSpeaking();
    _limit?.cancel();
    _capture.dispose();
    _agent.cancel();
    super.dispose();
  }

  void _handlePushToTalk() async {
    if (_isListening) {
      _stopListeningAndProcess();
    } else {
      _startVoiceInput();
    }
  }

  void _startVoiceInput() async {
    await _multimodalAi.stopSpeaking();

    setState(() {
      _isListening = true;
      _isThinking = false;
      _isSpeaking = false;
      _userSpokenText = '';
      _assistantSpokenResponse = '';
    });

    try {
      await _capture.start();
      _limit = Timer(const Duration(seconds: 45), () {
        if (mounted && _isListening) _stopListeningAndProcess();
      });
    } catch (e) {
      if (mounted)
        setState(() {
          _isListening = false;
          _assistantSpokenResponse = '$e';
        });
    }
  }

  void _stopListeningAndProcess() async {
    _limit?.cancel();
    if (!mounted) return;
    setState(() {
      _isListening = false;
      _isThinking = true;
    });
    try {
      final file = await _capture.stop();
      String transcript;
      try {
        transcript = await _multimodalAi.transcribeAudio(file, _requestMode);
      } finally {
        if (await file.exists()) await file.delete();
      }

      if (!mounted) return;
      if (transcript.trim().isEmpty) {
        setState(() {
          _isThinking = false;
          _assistantSpokenResponse =
              'No speech detected. Please speak closer to the mic or tap one of the quick question chips below.';
        });
        return;
      }

      setState(() => _userSpokenText = transcript);
      await _processQuery(transcript);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isThinking = false;
        _assistantSpokenResponse = 'Voice request failed: $e';
      });
      await _multimodalAi.speak(_assistantSpokenResponse);
    }
  }

  Future<void> _processQuery(String queryText) async {
    setState(() {
      _isThinking = true;
      _userSpokenText = queryText;
    });

    try {
      final result = await _agent.executeQuery(
        question: queryText,
        equipmentId: widget.equipment.id,
        aiMode: _requestMode,
        cloudProvider: _cloudProvider,
      );
      final reply = result.answer;
      if (!mounted) return;
      setState(() {
        _assistantSpokenResponse = reply;
        _isThinking = false;
        _isSpeaking = true;
      });

      // Speak answer via on-device TTS
      await _multimodalAi.speak(reply);
      if (mounted) setState(() => _isSpeaking = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isThinking = false;
        _assistantSpokenResponse = 'Processing error: $e';
      });
    }
  }

  void _showTextInputDialog() {
    final controller = TextEditingController(text: _userSpokenText);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Type Query for Voice Assistant',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'e.g. Bleed air from pump casing',
            hintStyle: TextStyle(color: Colors.white38),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              final text = controller.text.trim();
              if (text.isNotEmpty) _processQuery(text);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB)),
            child: const Text('Ask Assistant',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _stopAudioOutput() async {
    await _multimodalAi.stopSpeaking();
    setState(() => _isSpeaking = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context)
          .colorScheme
          .onSurface, // Dark Apple Siri / Assistant theme
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 20, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Voice Assistant',
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.keyboard_rounded, color: Colors.white70),
            tooltip: 'Type Question',
            onPressed:
                _isThinking || _isListening ? null : _showTextInputDialog,
          ),
          if (_isSpeaking)
            IconButton(
              icon:
                  const Icon(Icons.volume_off_rounded, color: Colors.redAccent),
              tooltip: 'Mute Speech',
              onPressed: _stopAudioOutput,
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: ListView(
            children: [
              Theme(
                  data: ThemeData.dark(),
                  child: AiRequestPicker(
                      mode: _requestMode,
                      provider: _cloudProvider,
                      enabled: !(_isListening || _isThinking || _isSpeaking),
                      audio: true,
                      onChanged: (mode, provider) => setState(() {
                            _requestMode = mode;
                            _cloudProvider = provider;
                          }))),
              // Equipment badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${widget.equipment.name} • Voice Assistant',
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 24),

              // Animated Soundwave Visualizer Sphere
              Center(
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final scale = _isListening || _isSpeaking
                        ? 1.0 + (_pulseController.value * 0.25)
                        : 1.0;

                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: _isListening
                                ? [
                                    const Color(0xFF06B6D4),
                                    const Color(0xFF0891B2),
                                    Colors.transparent
                                  ]
                                : (_isSpeaking
                                    ? [
                                        const Color(0xFF10B981),
                                        const Color(0xFF059669),
                                        Colors.transparent
                                      ]
                                    : [
                                        const Color(0xFF6366F1),
                                        const Color(0xFF4F46E5),
                                        Colors.transparent
                                      ]),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (_isListening
                                      ? const Color(0xFF06B6D4)
                                      : (_isSpeaking
                                          ? const Color(0xFF10B981)
                                          : const Color(0xFF6366F1)))
                                  .withValues(alpha: 0.4),
                              blurRadius: 40,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                        child: Icon(
                          _isListening
                              ? Icons.graphic_eq_rounded
                              : (_isSpeaking
                                  ? Icons.volume_up_rounded
                                  : Icons.mic_rounded),
                          color: Theme.of(context).colorScheme.surface,
                          size: 56,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              Text(
                _isListening
                    ? 'Listening to speech...'
                    : (_isThinking
                        ? 'Consulting equipment manuals...'
                        : (_isSpeaking
                            ? 'Speaking verified procedure...'
                            : 'Push to Talk')),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),

              // User question transcript card
              if (_userSpokenText.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('You Asked',
                          style: TextStyle(
                              color: Color(0xFF06B6D4),
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(_userSpokenText,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13)),
                    ],
                  ),
                ),

              // Assistant Spoken Answer card
              if (_assistantSpokenResponse.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Spoken Response',
                              style: TextStyle(
                                  color: Color(0xFF10B981),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.replay_rounded,
                                size: 16, color: Colors.white70),
                            onPressed: () =>
                                _multimodalAi.speak(_assistantSpokenResponse),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _assistantSpokenResponse,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13, height: 1.5),
                      ),
                    ],
                  ),
                ),

              // Quick Suggestion Chips for Fast Testing
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    'Bleed air from pump casing',
                    'Explain error code E-04',
                    'Safe operating discharge pressure',
                    'Bearing temperature limit',
                  ]
                      .map((prompt) => Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ActionChip(
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.1),
                              label: Text(prompt,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 11)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                      color: Colors.white
                                          .withValues(alpha: 0.15))),
                              onPressed: _isThinking || _isListening
                                  ? null
                                  : () => _processQuery(prompt),
                            ),
                          ))
                      .toList(),
                ),
              ),

              // Big Push-To-Talk Action Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isThinking ? null : _handlePushToTalk,
                  icon: Icon(
                      _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                      size: 20),
                  label: Text(_isListening ? 'Stop Speaking' : 'Push to Talk',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isListening
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
