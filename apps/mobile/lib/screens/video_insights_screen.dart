import '../widgets/ai_request_picker.dart';
import '../widgets/answer_markdown.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/models.dart';
import '../services/multimodal_ai_service.dart';
import 'citation_viewer_screen.dart';

class VideoInsightsScreen extends StatefulWidget {
  final EquipmentModel equipment;
  final AiMode aiMode;

  const VideoInsightsScreen({
    super.key,
    required this.equipment,
    this.aiMode = AiMode.smartAuto,
  });

  @override
  State<VideoInsightsScreen> createState() => _VideoInsightsScreenState();
}

class _VideoInsightsScreenState extends State<VideoInsightsScreen> {
  late AiMode _requestMode = widget.aiMode;
  String _cloudProvider = 'auto';
  final _multimodalAi = MultimodalAiService();
  final _picker = ImagePicker();
  final _queryController = TextEditingController();

  File? _videoFile;
  bool _isProcessing = false;
  List<File> _extractedFrames = [];
  List<int> _frameTimestamps = [];
  MultimodalAnalysisResult? _analysisResult;

  Future<void> _pickVideo(ImageSource source) async {
    try {
      final picked = await _picker.pickVideo(
        source: source,
        maxDuration: const Duration(seconds: 45),
      );

      if (picked != null) {
        setState(() {
          _videoFile = File(picked.path);
          _analysisResult = null;
          _extractedFrames = [];
        });
        _extractRepresentativeFrames();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not access video: $e')),
        );
      }
    }
  }

  /// Resource-conscious frame extraction pipeline
  Future<void> _extractRepresentativeFrames() async {
    if (_videoFile == null) return;
    setState(() => _isProcessing = true);

    try {
      final rows = await MultimodalAiService.mediaChannel
          .invokeListMethod<dynamic>(
              'extractFrames', {'path': _videoFile!.path});
      if (rows == null || rows.isEmpty)
        throw StateError('No decodable frames found.');
      final frames = rows.map((r) => File(r['path'] as String)).toList();
      if (!mounted) {
        for (final f in frames) {
          await f.delete();
        }
        return;
      }
      setState(() {
        _extractedFrames = frames;
        _frameTimestamps =
            rows.map((r) => (r['timestampMs'] as num).toInt()).toList();
        _isProcessing = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Frame extraction failed: $e')));
      }
    }
  }

  Future<void> _runVideoAnalysis() async {
    if (_videoFile == null || _extractedFrames.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _analysisResult = null;
    });

    final question = _queryController.text.trim().isEmpty
        ? 'Analyze this video clip of ${widget.equipment.name}. Identify observable machine states, mechanical vibration, error lights, or irregular cycle motion.'
        : _queryController.text.trim();

    try {
      final result = await _multimodalAi.analyzeVideoFrames(
        frames: _extractedFrames,
        timestampsMs: _frameTimestamps,
        question: question,
        equipmentId: widget.equipment.id,
        aiMode: _requestMode,
        cloudProvider: _cloudProvider,
      );

      if (mounted) {
        setState(() {
          _analysisResult = result;
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Video analysis failed: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _queryController.dispose();
    for (final frame in _extractedFrames) {
      frame.delete().ignore();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new,
              size: 20, color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Video Insights',
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
                enabled: !(_isProcessing),
                audio: false,
                onChanged: (mode, provider) => setState(() {
                      _requestMode = mode;
                      _cloudProvider = provider;
                    })),
            // Video Select Zone
            if (_videoFile == null)
              Container(
                height: 220,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  border:
                      Border.all(color: Colors.black.withValues(alpha: 0.08)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color:
                            Theme.of(context).colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.video_library_rounded,
                          color: Color(0xFF7C3AED), size: 28),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Record or Import Short Equipment Video',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurface),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Up to 45 seconds • Frame-by-frame visual analysis',
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _pickVideo(ImageSource.camera),
                          icon: const Icon(Icons.videocam_rounded, size: 16),
                          label: const Text('Record Video'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7C3AED),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: () => _pickVideo(ImageSource.gallery),
                          icon: const Icon(Icons.folder_open_rounded, size: 16),
                          label: const Text('Browse Files'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor:
                                Theme.of(context).colorScheme.onSurface,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            else
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
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerLow,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.movie_filter_rounded,
                                  color: Color(0xFF7C3AED), size: 20),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Equipment Video Clip',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13)),
                                Text('Ready for frame extraction',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade500)),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () => setState(() {
                            _videoFile = null;
                            _extractedFrames = [];
                            _analysisResult = null;
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Frame thumbnails strip
                    Row(
                      children: _frameTimestamps
                          .asMap()
                          .entries
                          .map((entry) => Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: _buildFrameChip('Frame ${entry.key + 1}',
                                    '${(entry.value / 1000).toStringAsFixed(1)}s'),
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),

            // Question Input
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
              ),
              child: TextField(
                controller: _queryController,
                decoration: InputDecoration(
                  hintText: 'What should the AI look for in this video?',
                  hintStyle:
                      TextStyle(fontSize: 12, color: Colors.grey.shade400),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Submit Button
            ElevatedButton(
              onPressed: _videoFile == null || _isProcessing
                  ? null
                  : _runVideoAnalysis,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _isProcessing
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white)),
                        SizedBox(width: 10),
                        Text('Sampling Frames & Synthesizing Diagnostics...',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    )
                  : const Text('Generate Video Insights',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
            const SizedBox(height: 24),

            // Results Container
            if (_analysisResult != null) ...[
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
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerLow,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _analysisResult!.usedModelName,
                            style: const TextStyle(
                                color: Color(0xFF7C3AED),
                                fontSize: 11,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        Text('${_analysisResult!.latencyMs}ms',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade500)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('Video Event Summary',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    AnswerMarkdown(_analysisResult!.textResponse),
                  ],
                ),
              ),
              if (_analysisResult!.citations.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Correlated Technical Manual Citations',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface),
                ),
                const SizedBox(height: 8),
                ..._analysisResult!.citations.map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => CitationViewerScreen(chunk: c)),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerLow,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.menu_book_rounded,
                                  size: 16, color: Color(0xFF7C3AED)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                    '${c.manualTitle} (p. ${c.pageNumber})',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11)),
                              ),
                              const Icon(Icons.arrow_forward_ios,
                                  size: 10, color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                    )),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFrameChip(String title, String timestamp) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        ),
        child: Column(
          children: [
            const Icon(Icons.image_outlined,
                size: 16, color: Color(0xFF7C3AED)),
            const SizedBox(height: 4),
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
            Text(timestamp,
                style: TextStyle(fontSize: 9, color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }
}
