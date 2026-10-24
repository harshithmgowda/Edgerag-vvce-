import '../widgets/ai_request_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/agent_skills_service.dart';
import 'citation_viewer_screen.dart';

class AgentSkillsScreen extends StatefulWidget {
  final EquipmentModel equipment;
  final AiMode aiMode;

  const AgentSkillsScreen({
    super.key,
    required this.equipment,
    this.aiMode = AiMode.smartAuto,
  });

  @override
  State<AgentSkillsScreen> createState() => _AgentSkillsScreenState();
}

class _AgentSkillsScreenState extends State<AgentSkillsScreen> {
  late AiMode _requestMode = widget.aiMode;
  String _cloudProvider = 'auto';
  final _skillsService = AgentSkillsService();

  AgentSkillDefinition? _selectedSkill;
  final Map<String, TextEditingController> _inputControllers = {};
  bool _isExecuting = false;
  AgentSkillExecutionResult? _lastResult;

  @override
  void initState() {
    super.initState();
    _selectSkill(_skillsService.availableSkills.first);
  }

  void _selectSkill(AgentSkillDefinition skill) {
    setState(() {
      _selectedSkill = skill;
      if (skill.id == 'transcribe_audio' && _cloudProvider == 'nvidia')
        _cloudProvider = 'auto';
      _lastResult = null;
      _inputControllers.clear();

      for (final inputKey in skill.requiredInputs) {
        if (inputKey == 'equipment_id') {
          _inputControllers[inputKey] = TextEditingController(
            text: widget.equipment.id.isNotEmpty
                ? widget.equipment.id
                : 'pump-01',
          );
        } else if (inputKey == 'query') {
          _inputControllers[inputKey] =
              TextEditingController(text: 'air bleed procedure');
        } else if (inputKey == 'error_code') {
          _inputControllers[inputKey] = TextEditingController(text: 'E-04');
        } else if (inputKey == 'manual_id') {
          _inputControllers[inputKey] =
              TextEditingController(text: 'man_pump_01');
        } else if (inputKey == 'page_number') {
          _inputControllers[inputKey] = TextEditingController(text: '1');
        } else if (inputKey == 'description') {
          _inputControllers[inputKey] = TextEditingController(
              text: 'Main motor vibration exceeded 4.5 mm/s limit.');
        } else if (inputKey == 'image_path') {
          _inputControllers[inputKey] =
              TextEditingController(text: 'sample_pump_inspection.jpg');
        } else if (inputKey == 'question') {
          _inputControllers[inputKey] = TextEditingController(
              text: 'Inspect pump casing and check for cavitation damage.');
        } else if (inputKey == 'audio_path') {
          _inputControllers[inputKey] =
              TextEditingController(text: 'sample_audio_note.wav');
        } else {
          _inputControllers[inputKey] = TextEditingController();
        }
      }
    });
  }

  Future<void> _executeSelectedSkill() async {
    if (_selectedSkill == null) return;

    setState(() {
      _isExecuting = true;
      _lastResult = null;
    });

    final inputs = <String, dynamic>{};
    _inputControllers.forEach((key, ctrl) {
      inputs[key] = ctrl.text.trim();
    });

    final result = await _skillsService.executeSkill(
      skillId: _selectedSkill!.id,
      inputs: inputs,
      aiMode: _requestMode,
      cloudProvider: _cloudProvider,
    );

    if (mounted) {
      setState(() {
        _lastResult = result;
        _isExecuting = false;
      });
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
          'Agent Skills Workbench',
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
                enabled: !(_isExecuting),
                audio: _selectedSkill?.id == 'transcribe_audio',
                onChanged: (mode, provider) => setState(() {
                      _requestMode = mode;
                      _cloudProvider = provider;
                    })),
            // Security Guarantee Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield_rounded,
                      size: 16, color: Color(0xFFD97706)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Bounded Deterministic Tools • Strict Allowlist • Zero Shell Execution',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFB45309)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Skills Selector Chips Carousel
            Text(
              'Select Authorized Skill',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _skillsService.availableSkills.map((s) {
                  final isSel = _selectedSkill?.id == s.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(s.name,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight:
                                  isSel ? FontWeight.bold : FontWeight.normal)),
                      selected: isSel,
                      selectedColor: const Color(0xFFD97706),
                      labelStyle: TextStyle(
                          color: isSel
                              ? Colors.white
                              : Theme.of(context).colorScheme.onSurface),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      onSelected: (_) => _selectSkill(s),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Skill Configuration & Input Form
            if (_selectedSkill != null) ...[
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
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.build_circle_rounded,
                              color: Color(0xFFD97706), size: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_selectedSkill!.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14)),
                              Text(_selectedSkill!.category,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade500)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _selectedSkill!.description,
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          height: 1.4),
                    ),
                    const Divider(height: 24),

                    // Inputs list
                    Text('Skill Parameters',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface)),
                    const SizedBox(height: 10),
                    ..._selectedSkill!.requiredInputs.map((inputKey) {
                      final ctrl = _inputControllers[inputKey];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              inputKey.toUpperCase().replaceAll('_', ' '),
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 4),
                            TextField(
                              controller: ctrl,
                              decoration: InputDecoration(
                                isDense: true,
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                fillColor: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerLow,
                                filled: true,
                                suffixIcon: inputKey == 'image_path'
                                    ? IconButton(
                                        icon: const Icon(Icons.add_a_photo,
                                            size: 18),
                                        tooltip: 'Take Photo / Pick Image',
                                        onPressed: () async {
                                          final picker = ImagePicker();
                                          final picked = await picker.pickImage(
                                              source: ImageSource.camera);
                                          if (picked != null) {
                                            ctrl?.text = picked.path;
                                          }
                                        },
                                      )
                                    : null,
                              ),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isExecuting ? null : _executeSelectedSkill,
                        icon: _isExecuting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.play_arrow_rounded, size: 18),
                        label: Text(
                            _isExecuting
                                ? 'Executing Skill...'
                                : 'Run Authorized Skill',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD97706),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],

            // Execution Output Card
            if (_lastResult != null) ...[
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _lastResult!.success
                        ? const Color(0xFF10B981).withValues(alpha: 0.3)
                        : Colors.red.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _lastResult!.success
                                  ? Icons.check_circle_rounded
                                  : Icons.error_rounded,
                              color: _lastResult!.success
                                  ? const Color(0xFF10B981)
                                  : Colors.red,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _lastResult!.success
                                  ? 'Skill Execution Succeeded'
                                  : 'Execution Error',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: _lastResult!.success
                                    ? const Color(0xFF10B981)
                                    : Colors.red,
                              ),
                            ),
                          ],
                        ),
                        Text('${_lastResult!.executionTimeMs}ms',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade500)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(_lastResult!.summary,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.onSurface)),
                    const SizedBox(height: 10),

                    // Structured JSON Data Preview
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.onSurface,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        _lastResult!.data.toString(),
                        style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: Color(0xFF38BDF8)),
                      ),
                    ),
                  ],
                ),
              ),
              if (_lastResult!.citations.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Retrieved Manual Citations',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface)),
                const SizedBox(height: 8),
                ..._lastResult!.citations.map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      CitationViewerScreen(chunk: c)));
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
                                  size: 16, color: Color(0xFFD97706)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                    '${c.manualTitle} (Page ${c.pageNumber})',
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
}
