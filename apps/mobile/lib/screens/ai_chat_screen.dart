import 'dart:io';
import '../widgets/ai_request_picker.dart';
import '../services/gemini_service.dart';
import '../services/nvidia_service.dart';
import '../services/local_ai_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/answer_markdown.dart';
import 'audio_scribe_screen.dart';
import 'storage_management_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../services/agent_controller.dart';
import '../services/multimodal_ai_service.dart';
import 'citation_viewer_screen.dart';

class AiChatScreen extends StatefulWidget {
  final EquipmentModel equipment;
  final AiMode aiMode;
  final String? initialQuestion;
  final bool equipmentGrounded;
  final String cloudProvider;

  const AiChatScreen({
    super.key,
    required this.equipment,
    required this.aiMode,
    this.initialQuestion,
    this.equipmentGrounded = true,
    this.cloudProvider = 'auto',
  });

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _agent = AgentController();
  final _multimodalAi = MultimodalAiService();
  final _picker = ImagePicker();

  final _conversation = const Uuid().v4();
  final List<ChatMessageModel> _messages = [];
  late AiMode _requestMode = widget.aiMode;
  late String _cloudProvider = widget.cloudProvider;
  bool _busy = false;
  String _draft = '', _status = '', _error = '';
  List<String> _trace = [];
  int _request = 0;

  // Multimodal Attachments
  File? _attachedImage;
  String? _attachedAudioNote;
  String? _attachedManualTitle;

  Color get ink => Theme.of(context).colorScheme.onSurface;
  Color get green => Theme.of(context).colorScheme.primary;
  String get _mode => _requestMode == AiMode.offlineOnly
      ? 'On-device AI'
      : _requestMode == AiMode.onlineAi
          ? 'Online AI'
          : 'Smart auto';

  @override
  void initState() {
    super.initState();
    if (widget.initialQuestion != null && widget.initialQuestion!.isNotEmpty) {
      _input.text = widget.initialQuestion!;
      WidgetsBinding.instance.addPostFrameCallback((_) => _send());
    }
  }

  @override
  void dispose() {
    _request++;
    _agent.cancel();
    _input.dispose();
    _scroll.dispose();
    _multimodalAi.stopSpeaking();
    super.dispose();
  }

  void _bottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 180), curve: Curves.easeOut);
      }
    });
  }

  void _showAttachmentSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add Context Attachment',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16, color: ink)),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.camera_alt,
                        color: Colors.red, size: 20)),
                title: const Text('Capture Equipment Camera Photo',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: const Text(
                    'Take a photo of warning lights or machine parts',
                    style: TextStyle(fontSize: 11)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final picked =
                      await _picker.pickImage(source: ImageSource.camera);
                  if (picked != null)
                    setState(() => _attachedImage = File(picked.path));
                },
              ),
              ListTile(
                leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color:
                            Theme.of(context).colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.photo_library,
                        color: Colors.blue, size: 20)),
                title: const Text('Select Photo from Gallery',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: const Text('Attach schematic or technical photograph',
                    style: TextStyle(fontSize: 11)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final picked =
                      await _picker.pickImage(source: ImageSource.gallery);
                  if (picked != null)
                    setState(() => _attachedImage = File(picked.path));
                },
              ),
              ListTile(
                leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color:
                            Theme.of(context).colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(10)),
                    child:
                        const Icon(Icons.mic, color: Colors.green, size: 20)),
                title: const Text('Record Spoken Audio Note',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: const Text(
                    'Transcribe spoken audio directly into question',
                    style: TextStyle(fontSize: 11)),
                onTap: () async {
                  Navigator.pop(ctx);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => AudioScribeScreen(
                              equipment: widget.equipment,
                              aiMode: _requestMode)));
                },
              ),
              ListTile(
                leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.menu_book,
                        color: Colors.amber, size: 20)),
                title: const Text('Manage Downloaded Manuals',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: Text('${widget.equipment.name} Operating Guide',
                    style: const TextStyle(fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const StorageManagementScreen()));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _send() async {
    final question = _input.text.trim();
    if ((question.isEmpty && _attachedImage == null) || _busy) return;

    final request = ++_request;
    final sentText = question.isNotEmpty
        ? question
        : 'Inspect attached equipment photograph.';

    setState(() {
      _messages.add(ChatMessageModel(
        id: const Uuid().v4(),
        conversationId: _conversation,
        isUser: true,
        content: sentText,
        timestamp: DateTime.now(),
      ));
      _busy = true;
      _draft = '';
      _error = '';
      _status = _attachedImage != null
          ? 'Analyzing visual evidence & manuals…'
          : 'Searching your documents…';
    });

    final currentImage = _attachedImage;
    _input.clear();
    setState(() {
      _attachedImage = null;
      _attachedAudioNote = null;
      _attachedManualTitle = null;
    });
    _bottom();

    try {
      if (currentImage != null) {
        // Run multimodal analysis
        final result = await _multimodalAi.analyzeImage(
          imageFile: currentImage,
          question: sentText,
          equipmentId: widget.equipmentGrounded ? widget.equipment.id : '',
          cloudProvider: _cloudProvider,
          aiMode: _requestMode,
        );

        if (!mounted || request != _request) return;

        setState(() {
          _messages.add(ChatMessageModel(
            id: const Uuid().v4(),
            conversationId: _conversation,
            isUser: false,
            content: result.textResponse,
            timestamp: DateTime.now(),
            citations: result.citations,
            providerUsed: result.usedModelName,
          ));
          _draft = '';
        });
      } else {
        // Standard text RAG query
        final history = _messages
            .take(_messages.length - 1)
            .skip(_messages.length > 7 ? _messages.length - 7 : 0)
            .map((m) => {
                  'role': m.isUser ? 'user' : 'assistant',
                  'content': m.content.length > 4000
                      ? m.content.substring(0, 4000)
                      : m.content
                })
            .toList();

        final result = await (widget.equipmentGrounded
            ? _agent.executeQuery
            : _generalQuery)(
          question: sentText,
          equipmentId: widget.equipmentGrounded ? widget.equipment.id : '',
          cloudProvider: _cloudProvider,
          aiMode: _requestMode,
          history: history,
          onStatus: (value) {
            if (mounted && request == _request) setState(() => _status = value);
          },
          onReset: () {
            if (mounted && request == _request) setState(() => _draft = '');
          },
          onTokenStream: (token) {
            if (mounted && request == _request) {
              setState(() => _draft += token);
              _bottom();
            }
          },
        );

        if (!mounted || request != _request) return;
        setState(() {
          _messages.add(ChatMessageModel(
            id: const Uuid().v4(),
            conversationId: _conversation,
            isUser: false,
            content: result.answer,
            timestamp: DateTime.now(),
            citations: result.citations,
            providerUsed: result.providerUsed,
            evidenceStatus: result.evidenceStatus,
          ));
          _trace = result.executionTrace;
          _draft = '';
        });
      }
    } catch (e) {
      if (mounted && request == _request)
        setState(() => _error = 'Could not complete the answer. $e');
    } finally {
      if (mounted && request == _request) {
        setState(() => _busy = false);
        _bottom();
      }
    }
  }

  Future<AgentResult> _generalQuery(
      {required String question,
      required String equipmentId,
      required AiMode aiMode,
      String cloudProvider = 'auto',
      List<Map<String, String>> history = const [],
      Function(String)? onTokenStream,
      Function(String)? onStatus,
      Function()? onReset}) async {
    const instruction =
        'Answer directly in clear Markdown. This is a general conversation; no equipment manual was retrieved. Do not claim otherwise.';
    final prompt =
        '${history.take(4).map((m) => "${m['role']}: ${m['content']}").join('\n')}\nUser: $question';
    String provider = 'Gemma 4 E2B IT (local)';
    final buffer = StringBuffer();
    if (aiMode != AiMode.offlineOnly) {
      for (final candidate
          in cloudProvider == 'auto' ? ['gemini', 'nvidia'] : [cloudProvider]) {
        try {
          Stream<String> stream;
          if (candidate == 'gemini') {
            provider = 'Gemini · ${await GeminiService().getSelectedModel()}';
            stream = GeminiService().generateResponseStream(
                prompt: prompt, systemInstruction: instruction);
          } else {
            provider = 'NVIDIA · ${await NvidiaService().getSelectedModel()}';
            stream = NvidiaService().generateGroundedAnswerStream(
                question: prompt,
                retrievedChunks: const [],
                instruction: instruction);
          }
          onStatus?.call('Writing with $provider…');
          await for (final token in stream) {
            buffer.write(token);
            onTokenStream?.call(token);
          }
          return AgentResult(
              answer: buffer.toString(),
              citations: [],
              providerUsed: provider,
              executionTrace: [],
              evidenceStatus: 'GENERAL_GUIDANCE');
        } catch (err) {
          if (buffer.isNotEmpty) rethrow;
          if (aiMode == AiMode.onlineAi) {
            throw StateError(
                'Cloud provider usage limit reached or unavailable. Switch AI Mode to "Local AI" at the top to answer 100% offline, or update your API key in Settings -> AI Providers.');
          }
        }
      }
    }
    final localAi = LocalAiService();
    await localAi.checkModelReadiness();
    provider = '${localAi.modelName} (local)';
    await for (final token in localAi.generateLocalResponseStream(
        question: prompt,
        chunks: const [],
        systemPrompt: instruction,
        onStatus: onStatus)) {
      buffer.write(token);
      onTokenStream?.call(token);
    }
    return AgentResult(
        answer: buffer.toString(),
        citations: [],
        providerUsed: provider,
        executionTrace: [],
        evidenceStatus: 'GENERAL_GUIDANCE');
  }

  Future<void> _stop() async {
    ++_request;
    setState(() {
      if (_draft.isNotEmpty) {
        _messages.add(ChatMessageModel(
          id: const Uuid().v4(),
          conversationId: _conversation,
          isUser: false,
          content: _draft,
          timestamp: DateTime.now(),
          providerUsed: 'Stopped · incomplete',
        ));
      }
      _draft = '';
      _busy = false;
    });
    await _agent.cancel();
  }

  void _showTrace() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          children: [
            const Text('Answer activity',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20)),
            const SizedBox(height: 16),
            ..._trace.map((line) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(line,
                      style: const TextStyle(
                          fontFamily: 'OpenSans', fontSize: 12)),
                )),
          ],
        ),
      ),
    );
  }

  String _readable(ChatMessageModel message) =>
      cleanAnswerText(message.content);

  Widget _markdown(String text,
          {List<ChunkModel> sources = const [], bool streaming = false}) =>
      AnswerMarkdown(text, streaming: streaming, onTapLink: (_, href, __) {
        final found = sources.where((c) => href == 'source:${c.id}');
        if (found.isNotEmpty)
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => CitationViewerScreen(chunk: found.first)));
      });

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          title: Text(widget.equipmentGrounded ? 'Ask Equipment' : 'AI Chat',
              style: TextStyle(
                  fontFamily: 'Metropolis',
                  fontWeight: FontWeight.w700,
                  fontSize: 23,
                  letterSpacing: -1,
                  color: Color(0xFF202124))),
          actions: [
            IconButton(
                tooltip: 'Answer activity',
                icon: const Icon(Icons.tune_rounded,
                    size: 21, color: Color(0xFF475569)),
                onPressed: _showTrace),
            IconButton(
                tooltip: 'New chat',
                icon: const Icon(Icons.add_rounded, color: Color(0xFF475569)),
                onPressed: _busy
                    ? null
                    : () => setState(() {
                          _messages.clear();
                          _error = '';
                          _trace = [];
                        })),
          ],
        ),
        body: Column(
          children: [
            AiRequestPicker(
                mode: _requestMode,
                provider: _cloudProvider,
                enabled: !_busy,
                onChanged: (mode, provider) => setState(() {
                      _requestMode = mode;
                      _cloudProvider = provider;
                    })),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFE8F0FE))),
              ),
              child: Row(
                children: [
                  const Icon(Icons.menu_book_outlined,
                      size: 16, color: Color(0xFF0B57D0)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(
                          widget.equipmentGrounded
                              ? widget.equipment.name
                              : 'General conversation · no equipment retrieval',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF202124)))),
                  Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                          color: const Color(0xFFE8F0FE),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(_mode,
                          style: const TextStyle(
                              fontSize: 9,
                              color: Color(0xFF0B57D0),
                              fontWeight: FontWeight.w600))),
                ],
              ),
            ),
            Expanded(
                child: _messages.isEmpty
                    ? _welcome()
                    : ListView(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                        children: [
                            ..._messages.map(_message),
                            if (_busy)
                              _answer(cleanAnswerText(_draft),
                                  provider: 'EdgeRAG', loading: true)
                          ])),
            if (_error.isNotEmpty)
              Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFCA5A5))),
                  child: Text(_error,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF991B1B)))),

            // Attached media preview bar
            if (_attachedImage != null ||
                _attachedAudioNote != null ||
                _attachedManualTitle != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                color: const Color(0xFFF8FAFD),
                child: Row(
                  children: [
                    if (_attachedImage != null)
                      Chip(
                        avatar: const Icon(Icons.image,
                            size: 14, color: Colors.red),
                        label: const Text('Photo Attached',
                            style: TextStyle(fontSize: 11)),
                        onDeleted: () => setState(() => _attachedImage = null),
                      ),
                    if (_attachedAudioNote != null)
                      Chip(
                        avatar: const Icon(Icons.mic,
                            size: 14, color: Colors.green),
                        label: const Text('Audio Attached',
                            style: TextStyle(fontSize: 11)),
                        onDeleted: () =>
                            setState(() => _attachedAudioNote = null),
                      ),
                    if (_attachedManualTitle != null)
                      Chip(
                        avatar: const Icon(Icons.menu_book,
                            size: 14, color: Colors.amber),
                        label: Text(_attachedManualTitle!,
                            style: const TextStyle(fontSize: 11)),
                        onDeleted: () =>
                            setState(() => _attachedManualTitle = null),
                      ),
                  ],
                ),
              ),

            _composer(),
          ],
        ),
      );

  Widget _welcome() => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(26, 42, 26, 20),
        child: Column(
          children: [
            Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                    color: const Color(0xFFE8F0FE),
                    borderRadius: BorderRadius.circular(21),
                    border: Border.all(color: const Color(0xFFBFDBFE))),
                child: const Icon(Icons.auto_awesome_rounded,
                    size: 29, color: Color(0xFF0B57D0))),
            const SizedBox(height: 26),
            const Text('YOUR MULTIMODAL KNOWLEDGE, CONNECTED',
                style: TextStyle(
                    fontSize: 9,
                    letterSpacing: 1.5,
                    color: Color(0xFF5F6368),
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 15),
            const Text('Big questions.\nClear answers.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 35,
                    height: 1.16,
                    letterSpacing: -1.6,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF202124))),
            const SizedBox(height: 16),
            const Text(
                'Ask questions with text, photos, audio recordings, or manual pages.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: 'OpenSans',
                    fontSize: 13,
                    height: 1.7,
                    color: Color(0xFF5F6368))),
            const SizedBox(height: 28),
            _suggestion('💡', 'Understand a concept',
                'Explain the fault recovery procedure for '),
            _suggestion('📷', 'Analyze photographed alarm',
                'Inspect my attached photo and explain error indicator.'),
            _suggestion('📖', 'Explore this document',
                'Summarize the main maintenance guidelines in this document.'),
          ],
        ),
      );

  Widget _suggestion(String emoji, String title, String prompt) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: OutlinedButton(
          onPressed: () {
            _input.text = prompt;
          },
          style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              padding: const EdgeInsets.all(17),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14))),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 19)),
              const SizedBox(width: 14),
              Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF202124)))),
              const Icon(Icons.north_east, size: 16, color: Color(0xFF0B57D0)),
            ],
          ),
        ),
      );

  Widget _message(ChatMessageModel message) {
    if (message.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(left: 40, bottom: 26),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F0FE),
            borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(4)),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: SelectableText(message.content,
              style: const TextStyle(
                  fontFamily: 'OpenSans',
                  fontSize: 14.5,
                  height: 1.6,
                  color: Color(0xFF202124))),
        ),
      );
    }
    return _answer(_readable(message),
        provider: message.providerUsed,
        sources: message.citations,
        evidenceStatus: message.evidenceStatus,
        raw: message.content);
  }

  Widget _answer(String text,
          {required String provider,
          List<ChunkModel> sources = const [],
          String evidenceStatus = 'MANUAL_SUPPORTED',
          bool loading = false,
          String? raw}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                      color: const Color(0xFFE8F0FE),
                      borderRadius: BorderRadius.circular(6)),
                  child: const Icon(Icons.auto_awesome,
                      size: 15, color: Color(0xFF0B57D0)),
                ),
                const SizedBox(width: 8),
                const Text('EdgeRAG',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF202124))),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(provider,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 10, color: Color(0xFF5F6368)))),
                if (text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.volume_up_rounded,
                        size: 16, color: Color(0xFF0B57D0)),
                    tooltip: 'Read Aloud',
                    onPressed: () => _multimodalAi.speak(text),
                  ),
              ],
            ),
            if (!loading && text.isNotEmpty) ...[
              const SizedBox(height: 6),
              if (evidenceStatus == 'MANUAL_SUPPORTED' ||
                  (sources.isNotEmpty && evidenceStatus != 'INSUFFICIENT'))
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6F4EA),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCEEAD6)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified,
                          size: 12, color: Color(0xFF137333)),
                      const SizedBox(width: 6),
                      Text(
                        sources.isNotEmpty
                            ? 'Manual-supported answer · ${sources.map((s) => 'p. ${s.pageNumber}').toSet().join(', ')}'
                            : 'Manual-supported answer',
                        style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF137333)),
                      ),
                    ],
                  ),
                )
              else if (evidenceStatus == 'GENERAL_GUIDANCE')
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF7E0),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFEEFC3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.info_outline,
                          size: 12, color: Color(0xFFB06000)),
                      SizedBox(width: 6),
                      Text(
                        'General guidance — not verified against equipment manual',
                        style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFB06000)),
                      ),
                    ],
                  ),
                )
              else if (evidenceStatus == 'INSUFFICIENT')
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F3F4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFDADCE0)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shield_outlined,
                          size: 12, color: Color(0xFF5F6368)),
                      SizedBox(width: 6),
                      Text(
                        'Insufficient information — manual evidence missing',
                        style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF3C4043)),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 12),
            if (text.isNotEmpty)
              _markdown(text, sources: sources, streaming: loading),
            if (loading)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Color(0xFF0B57D0))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(_status,
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF5F6368)))),
                  ],
                ),
              ),
            if (sources.isNotEmpty) ...[
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('SOURCES',
                      style: TextStyle(
                          fontSize: 9,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF5F6368))),
                  if (sources.length > 1)
                    Text('Synthesizes ${sources.length} manual passages',
                        style: const TextStyle(
                            fontSize: 10,
                            fontStyle: FontStyle.italic,
                            color: Color(0xFF137333))),
                ],
              ),
              const SizedBox(height: 8),
              ...sources.asMap().entries.map((entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  CitationViewerScreen(chunk: entry.value))),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0))),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text('${entry.key + 1}',
                                    style: const TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFF0B57D0),
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: Text(entry.value.manualTitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF202124)))),
                                Text('p. ${entry.value.pageNumber}',
                                    style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0B57D0))),
                                const SizedBox(width: 5),
                                const Icon(Icons.north_east,
                                    size: 12, color: Color(0xFF0B57D0)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  'Rev ${entry.value.manualRevision ?? "v1.0"} · Pkg ${entry.value.packageVersion != null ? entry.value.packageVersion!.substring(0, entry.value.packageVersion!.length > 10 ? 10 : entry.value.packageVersion!.length) : "active"}',
                                  style: const TextStyle(
                                      fontSize: 10, color: Color(0xFF5F6368)),
                                ),
                                const Spacer(),
                                Text(
                                  'Relevance: ${entry.value.similarityScore.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF1B65C4),
                                      fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  )),
            ],
            if (!loading && text.isNotEmpty)
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(
                      ClipboardData(text: cleanAnswerText(raw ?? text)));
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Answer copied')));
                },
                icon: const Icon(Icons.copy_outlined, size: 13),
                label:
                    const Text('Copy answer', style: TextStyle(fontSize: 10)),
                style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF5F6368)),
              ),
          ],
        ),
      );

  Widget _composer() => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(10, 5, 8, 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x0A000000),
                        blurRadius: 16,
                        offset: Offset(0, 4))
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Multimodal Attachment Button
                    IconButton(
                      icon: const Icon(Icons.attach_file_rounded,
                          size: 21, color: Color(0xFF5F6368)),
                      tooltip: 'Attach Media Context',
                      onPressed: _busy ? null : _showAttachmentSheet,
                    ),
                    Expanded(
                      child: TextField(
                        controller: _input,
                        minLines: 1,
                        maxLines: 5,
                        maxLength: 4000,
                        textCapitalization: TextCapitalization.sentences,
                        style: const TextStyle(
                            fontFamily: 'OpenSans',
                            fontSize: 13,
                            color: Color(0xFF202124)),
                        decoration: const InputDecoration(
                          hintText: 'Ask about documents, photos, audio…',
                          counterText: '',
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          hintStyle:
                              TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                        ),
                      ),
                    ),
                    IconButton.filled(
                      tooltip: _busy ? 'Stop generating' : 'Send message',
                      onPressed: _busy ? _stop : _send,
                      style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFF0B57D0),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14))),
                      icon: Icon(
                          _busy
                              ? Icons.stop_rounded
                              : Icons.arrow_upward_rounded,
                          size: 21),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text('AI can make mistakes. Check the verified sources.',
                  style: TextStyle(
                      fontFamily: 'OpenSans',
                      fontSize: 9,
                      color: Color(0xFF94A3B8))),
            ],
          ),
        ),
      );
}
