import '../widgets/ai_request_picker.dart';
import 'dart:async';
import '../services/voice_capture.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../services/multimodal_ai_service.dart';
import 'ai_chat_screen.dart';
import 'incident_create_screen.dart';

class AudioScribeScreen extends StatefulWidget {
  final EquipmentModel equipment;
  final AiMode aiMode;

  const AudioScribeScreen({
    super.key,
    required this.equipment,
    this.aiMode = AiMode.smartAuto,
  });

  @override
  State<AudioScribeScreen> createState() => _AudioScribeScreenState();
}

class _AudioScribeScreenState extends State<AudioScribeScreen> {
  late AiMode _requestMode = widget.aiMode;
  String _cloudProvider = 'auto';
  final _multimodalAi = MultimodalAiService();
  final _capture = VoiceCapture();

  bool _isRecording = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  String _transcribedText = '';
  String _translatedText = '';
  String _summaryText = '';
  bool _isProcessing = false;

  void _toggleRecording() async {
    if (_isRecording) {
      _stopRecording();
    } else {
      _startRecording();
    }
  }

  void _startRecording() async {
    try {
      await _capture.start();
      if (!mounted) return;
      setState(() {
        _isRecording = true;
        _recordSeconds = 0;
        _transcribedText = '';
        _translatedText = '';
        _summaryText = '';
      });
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _recordSeconds++);
        if (_recordSeconds >= 85) _stopRecording();
      });
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  void _stopRecording() async {
    _recordTimer?.cancel();
    setState(() {
      _isRecording = false;
      _isProcessing = true;
    });
    File? file;
    try {
      file = await _capture.stop();
      final text = await _multimodalAi.transcribeAudio(file, _requestMode);
      if (mounted) setState(() => _transcribedText = text);
    } catch (e) {
      if (mounted && _transcribedText.trim().isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Transcription failed: $e')));
      }
    } finally {
      if (file != null && await file.exists()) await file.delete();
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _translateSpeech() async {
    if (_transcribedText.isEmpty) return;
    setState(() => _isProcessing = true);

    try {
      final res = await _multimodalAi.transformText(
        'Translate the following industrial voice note into formal technical English:\n"$_transcribedText"',
        'You are an accurate technical translator.',
        _requestMode,
        cloudProvider: _cloudProvider,
      );
      if (!mounted) return;
      setState(() {
        _translatedText = res;
        _isProcessing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _translatedText =
            'Translation failed. Check the selected model or cloud provider.';
        _isProcessing = false;
      });
    }
  }

  Future<void> _summarizeVoiceNote() async {
    if (_transcribedText.isEmpty) return;
    setState(() => _isProcessing = true);

    try {
      final res = await _multimodalAi.transformText(
        'Summarize the core technical symptoms from this voice note in 2 concise bullet points:\n"$_transcribedText"',
        'You are an industrial engineer summarizer.',
        _requestMode,
        cloudProvider: _cloudProvider,
      );
      if (!mounted) return;
      setState(() {
        _summaryText = res;
        _isProcessing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _summaryText =
            'Summary failed. Check the selected model or cloud provider.';
        _isProcessing = false;
      });
    }
  }

  Future<void> _importAudio() async {
    final picked = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (!mounted || picked?.files.single.path == null) return;
    setState(() => _isProcessing = true);
    try {
      final text = await _multimodalAi.transcribeAudio(
          File(picked!.files.single.path!), _requestMode);
      if (mounted) setState(() => _transcribedText = text);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Transcription failed: $e')));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _capture.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new,
              size: 20, color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Audio Scribe',
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            AiRequestPicker(
                mode: _requestMode,
                provider: _cloudProvider,
                enabled: !(_isProcessing || _isRecording),
                audio: true,
                onChanged: (mode, provider) => setState(() {
                      _requestMode = mode;
                      _cloudProvider = provider;
                    })),
            OutlinedButton.icon(
                onPressed: _isProcessing || _isRecording ? null : _importAudio,
                icon: const Icon(Icons.audio_file_outlined),
                label: const Text('Import audio · up to 90 seconds offline')),
            // Voice Recording Studio Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Animated Microphone Button
                  GestureDetector(
                    onTap: _isProcessing ? null : _toggleRecording,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: _isRecording
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF059669),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (_isRecording
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFF059669))
                                .withValues(alpha: 0.3),
                            blurRadius: 20,
                            spreadRadius: _isRecording ? 4 : 0,
                          ),
                        ],
                      ),
                      child: Icon(
                        _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                        color: Theme.of(context).colorScheme.surface,
                        size: 38,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isRecording
                        ? 'Listening & Transcribing...'
                        : 'Tap Mic to Record Speech',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _isRecording
                          ? const Color(0xFFDC2626)
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isRecording
                        ? _formatDuration(_recordSeconds)
                        : 'Local offline Whisper & Speech recognition',
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: _isRecording ? 'monospace' : null,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Live Transcription Container
            if (_transcribedText.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  border:
                      Border.all(color: Colors.black.withValues(alpha: 0.05)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.notes_rounded,
                                size: 16, color: Color(0xFF059669)),
                            SizedBox(width: 6),
                            Text('Speech Transcript',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded,
                              size: 16, color: Colors.grey),
                          onPressed: () => _copyToClipboard(_transcribedText),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _transcribedText,
                      style: const TextStyle(
                          fontSize: 13, height: 1.5, color: Color(0xFF1E293B)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Action Buttons Row (Translate, Summarize, Ask RAG, Create Incident)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isProcessing ? null : _translateSpeech,
                      icon: const Icon(Icons.translate, size: 14),
                      label: const Text('Translate',
                          style: TextStyle(fontSize: 11)),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isProcessing ? null : _summarizeVoiceNote,
                      icon: const Icon(Icons.auto_awesome, size: 14),
                      label: const Text('Summarize',
                          style: TextStyle(fontSize: 11)),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // "Ask EdgeRAG about this problem" Primary Button
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AiChatScreen(
                        equipment: widget.equipment,
                        aiMode: _requestMode,
                        cloudProvider: _cloudProvider,
                        initialQuestion: _transcribedText,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.psychology_rounded, size: 18),
                label: const Text('Ask EdgeRAG About This Problem',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
              ),
              const SizedBox(height: 8),

              // "Attach Transcript to Incident Ticket" Button
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => IncidentCreateScreen(
                        equipment: widget.equipment,
                        initialDescription: _transcribedText,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.receipt_long_rounded, size: 16),
                label: const Text('Log as Incident Ticket',
                    style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],

            // Translated Text Card
            if (_translatedText.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Technical Translation (EN)',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Color(0xFF1D4ED8))),
                    const SizedBox(height: 6),
                    Text(_translatedText,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF1E3A8A))),
                  ],
                ),
              ),
            ],

            // Summary Card
            if (_summaryText.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Key Symptoms Summary',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Color(0xFF15803D))),
                    const SizedBox(height: 6),
                    Text(_summaryText,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF14532D))),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
