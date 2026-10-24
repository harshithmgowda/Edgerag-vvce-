import '../widgets/ai_request_picker.dart';
import '../widgets/answer_markdown.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/models.dart';
import '../services/multimodal_ai_service.dart';
import 'citation_viewer_screen.dart';

class AskImageScreen extends StatefulWidget {
  final EquipmentModel equipment;
  final AiMode aiMode;

  const AskImageScreen({
    super.key,
    required this.equipment,
    this.aiMode = AiMode.smartAuto,
  });

  @override
  State<AskImageScreen> createState() => _AskImageScreenState();
}

class _AskImageScreenState extends State<AskImageScreen> {
  late AiMode _requestMode = widget.aiMode;
  String _cloudProvider = 'auto';
  final _multimodalAi = MultimodalAiService();
  final _picker = ImagePicker();
  final _questionController = TextEditingController();

  File? _selectedImage;
  bool _isAnalyzing = false;
  MultimodalAnalysisResult? _analysisResult;
  String _selectedMode = 'Visual Troubleshooting';

  final List<String> _inspectionModes = [
    'Visual Troubleshooting',
    'Component & Label Reading',
    'Error Code Identification',
    'Technical Diagram Analysis',
  ];

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 88,
      );
      if (picked != null) {
        setState(() {
          _selectedImage = File(picked.path);
          _analysisResult = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not access image: $e')),
        );
      }
    }
  }

  Future<void> _runImageAnalysis() async {
    if (_selectedImage == null) return;

    setState(() {
      _isAnalyzing = true;
      _analysisResult = null;
    });

    final promptText = _questionController.text.trim().isEmpty
        ? 'Perform $_selectedMode on this ${widget.equipment.name} component. Cross-reference visible error codes or warning indicators with technical manuals.'
        : _questionController.text.trim();

    try {
      final result = await _multimodalAi.analyzeImage(
        imageFile: _selectedImage!,
        question: promptText,
        equipmentId: widget.equipment.id,
        aiMode: _requestMode,
        cloudProvider: _cloudProvider,
      );

      if (mounted) {
        setState(() {
          _analysisResult = result;
          _isAnalyzing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAnalyzing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Analysis failed: $e')),
        );
      }
    }
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
          'Ask Image',
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
                enabled: !(_isAnalyzing),
                audio: false,
                onChanged: (mode, provider) => setState(() {
                      _requestMode = mode;
                      _cloudProvider = provider;
                    })),
            // Mode selector chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _inspectionModes.map((mode) {
                  final isSel = _selectedMode == mode;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(mode,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight:
                                  isSel ? FontWeight.bold : FontWeight.normal)),
                      selected: isSel,
                      selectedColor: const Color(0xFFDC2626),
                      labelStyle: TextStyle(
                          color: isSel
                              ? Colors.white
                              : Theme.of(context).colorScheme.onSurface),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      onSelected: (val) => setState(() => _selectedMode = mode),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Image Picker / Preview Zone
            if (_selectedImage == null)
              Container(
                height: 220,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                      color: Colors.black.withValues(alpha: 0.08),
                      strokeAlign: BorderSide.strokeAlignInside),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.add_a_photo_rounded,
                          color: Color(0xFFDC2626), size: 28),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Capture or Upload Equipment Photo',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurface),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'High-resolution label, component, or schematic',
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _pickImage(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt, size: 16),
                          label: const Text('Camera'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.onSurface,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: () => _pickImage(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library, size: 16),
                          label: const Text('Gallery'),
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
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.file(
                      _selectedImage!,
                      height: 240,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: CircleAvatar(
                      backgroundColor: Colors.black.withValues(alpha: 0.6),
                      child: IconButton(
                        icon: const Icon(Icons.close,
                            color: Colors.white, size: 18),
                        onPressed: () => setState(() {
                          _selectedImage = null;
                          _analysisResult = null;
                        }),
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 16),

            // Question Input Box
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
              ),
              child: TextField(
                controller: _questionController,
                decoration: InputDecoration(
                  hintText: 'Ask a specific question about this image...',
                  hintStyle:
                      TextStyle(fontSize: 12, color: Colors.grey.shade400),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Submit Button
            ElevatedButton(
              onPressed: _selectedImage == null || _isAnalyzing
                  ? null
                  : _runImageAnalysis,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _isAnalyzing
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white)),
                        SizedBox(width: 10),
                        Text('Analyzing Visuals & Grounding in Manuals...',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    )
                  : const Text('Analyze Visual Evidence',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
            const SizedBox(height: 24),

            // Analysis Result Cards
            if (_analysisResult != null) ...[
              // Model Badge & Latency
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _analysisResult!.usedModelName,
                      style: const TextStyle(
                          color: Color(0xFFDC2626),
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(
                    '${_analysisResult!.latencyMs}ms • ${_analysisResult!.isOffline ? "Offline" : "Cloud"}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Visual Observations Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: Colors.black.withValues(alpha: 0.05)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Visual Diagnosis & Procedure',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface),
                    ),
                    const SizedBox(height: 8),
                    AnswerMarkdown(_analysisResult!.textResponse),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Verified Manual Citations (Grounded Evidence)
              if (_analysisResult!.citations.isNotEmpty) ...[
                Text(
                  'Verified Manual Citations',
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
                              builder: (_) => CitationViewerScreen(chunk: c),
                            ),
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
                              Icon(Icons.menu_book_rounded,
                                  size: 16,
                                  color:
                                      Theme.of(context).colorScheme.onSurface),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        '${c.manualTitle} — Page ${c.pageNumber}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11)),
                                    Text(c.chunkText,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey.shade600)),
                                  ],
                                ),
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
}
