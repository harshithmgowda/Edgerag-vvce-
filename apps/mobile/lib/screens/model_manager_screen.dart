import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import '../models/ai_model_profile.dart';
import '../services/model_registry_service.dart';
import '../services/semantic_encoder.dart';
import '../services/local_ai_service.dart';

class ModelManagerScreen extends StatefulWidget {
  const ModelManagerScreen({super.key});

  @override
  State<ModelManagerScreen> createState() => _ModelManagerScreenState();
}

class _ModelManagerScreenState extends State<ModelManagerScreen> {
  final _registry = ModelRegistryService();
  bool _isLoading = true;
  String _activeTab = 'catalog'; // 'catalog' | 'installed' | 'tasks'

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    await _registry.scanInstalledModels();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _importModel(AiModelProfile model) async {
    if (model.format != ModelFormat.gguf && model.format != ModelFormat.litertLm) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Configure system speech and TTS in Android language settings.')));
      return;
    }
    final defaultExt = model.format == ModelFormat.litertLm ? 'litertlm' : 'gguf';
    final allowedExts = model.format == ModelFormat.litertLm
        ? ['litertlm', 'bin', 'tflite', 'task']
        : ['gguf', 'bin'];
    final picked = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: allowedExts);
    if (picked?.files.single.path == null || !mounted) return;
    setState(() => _isLoading = true);
    try {
      final pickedPath = picked!.files.single.path!;
      var ext = pickedPath.split('.').last.toLowerCase();
      if (!allowedExts.contains(ext)) ext = defaultExt;
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory('${docs.path}/models');
      await dir.create(recursive: true);
      final target = File('${dir.path}/${model.id}.$ext');
      if (await target.exists()) throw StateError('A model with this name already exists. Delete it first.');
      final staging = File('${target.path}.partial');
      try {
        await File(picked.files.single.path!).openRead().pipe(staging.openWrite());
        if (await staging.length() == 0) throw StateError('The selected file is empty.');
        await staging.rename(target.path);
      } finally { if (await staging.exists()) await staging.delete(); }
      await _refresh();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Model import failed: $e')));
    } finally { if (mounted) setState(() => _isLoading = false); }
  }

  Future<void> _importEncoder() async {
    final picked = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['zip']);
    if (picked?.files.single.path == null || !mounted) return;
    setState(() => _isLoading = true);
    try {
      await SemanticEncoder.importBundle(picked!.files.single.path!);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('MiniLM installed. Tokenizer and vector parity checks passed.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Encoder import failed: $e')));
    } finally { if (mounted) setState(() => _isLoading = false); }
  }

  Future<void> _testOffline() async {
    setState(() => _isLoading = true);
    final watch = Stopwatch()..start();
    var answer = '';
    try {
      await for (final token in LocalAiService().generateLocalResponseStream(question: 'Reply with: Local inference works.', chunks: const []).timeout(const Duration(seconds: 90))) { answer += token; }
      if (answer.trim().isEmpty) throw StateError('Model returned no output');
      if (mounted) showDialog<void>(context: context, builder: (ctx) => AlertDialog(title: const Text('Local inference completed'), content: Text('${watch.elapsedMilliseconds} ms\n\n$answer\n\nThis checks local generation, not answer accuracy. Repeat in airplane mode.'), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))]));
    } catch (e) {
      await LocalAiService().cancel();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Local inference failed: $e')));
    } finally { if (mounted) setState(() => _isLoading = false); }
  }

  Future<void> _deleteModel(AiModelProfile model) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${model.displayName}?'),
        content: Text(
          'This will remove the ${model.fileSizeDisplay} model weights file from your phone storage. Technical manuals, incidents, and chat history will NOT be deleted.',
          style: const TextStyle(fontSize: 12),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete Model'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _registry.deleteModel(model.id);
      if (success) {
        await _refresh();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${model.displayName} removed from device')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = _registry.allModels;
    final installed = all.where((m) => m.isInstalled).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 20, color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'AI Model Manager',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Theme.of(context).colorScheme.onSurface),
            onPressed: _refresh,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  OutlinedButton.icon(onPressed: _importEncoder, icon: const Icon(Icons.manage_search), label: const Text('Import matching MiniLM encoder')),
                  OutlinedButton.icon(onPressed: _testOffline, icon: const Icon(Icons.offline_bolt), label: const Text('Test local inference')),
                  // Storage Health Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onSurface,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.storage_rounded, color: Colors.white70, size: 18),
                                SizedBox(width: 8),
                                Text('Device AI Storage', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                            ),
                            Text('${installed.length} Models Installed', style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 14),
                        // Storage Bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: 0.35,
                            backgroundColor: Colors.white.withValues(alpha: 0.15),
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
                            minHeight: 8,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Installed Models Space: ~${(installed.fold<int>(0, (sum, m) => sum + m.fileSizeBytes) / (1024 * 1024)).toStringAsFixed(0)} MB', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11)),
                            const Text('arm64-v8a • Pixel 9a', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Tabs: Catalog | Installed | Task Assignment
                  Row(
                    children: [
                      _buildTabBtn('catalog', 'Model Catalog (${all.length})'),
                      const SizedBox(width: 8),
                      _buildTabBtn('installed', 'Installed (${installed.length})'),
                      const SizedBox(width: 8),
                      _buildTabBtn('tasks', 'Task Routing'),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // TAB CONTENT
                  if (_activeTab == 'catalog' || _activeTab == 'installed') ...[
                    // Gemma 4 E2B IT Primary Showcase Card
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF312E81).withValues(alpha: 0.25),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.auto_awesome, color: Colors.amberAccent, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      'Gemma 4 E2B IT',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.greenAccent.withValues(alpha: 0.3),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(_registry.getModel('gemma-4-e2b-it')!.isInstalled ? 'Installed' : 'Not installed', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Configured & active in app for Chat, Vision, Audio & Agent Tools.',
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...(_activeTab == 'installed' ? installed : all).map((model) => _buildModelCard(model)),
                  ] else ...[
                    // TASK ROUTING TAB
                    _buildTaskAssignmentCard('AI Chat Task', _registry.activeChatModelId, 'chat'),
                    _buildTaskAssignmentCard('Ask Image / Vision Task', _registry.activeVisionModelId, 'vision'),
                    _buildTaskAssignmentCard('Audio Scribe Task', _registry.activeAudioModelId, 'audio'),
                    _buildTaskAssignmentCard('Voice Assistant Output', _registry.activeTtsModelId, 'tts'),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _buildTabBtn(String key, String label) {
    final isSel = _activeTab == key;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTab = key),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSel ? Theme.of(context).colorScheme.onSurface : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isSel ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModelCard(AiModelProfile model) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(model.displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text('${model.family} • ${model.hardwareBackend}', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: model.isInstalled ? Theme.of(context).colorScheme.surfaceContainerLow : Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  model.isInstalled
                      ? (model.id == 'gemma-4-e2b-it' ? 'Installed • Primary' : 'Installed')
                      : 'Ready to Download',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: model.isInstalled ? const Color(0xFF059669) : Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(model.description, style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.4)),
          const SizedBox(height: 12),

          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(6)),
                child: Text(model.fileSizeDisplay, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(6)),
                child: Text(model.ramDisplay, style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ),
              const Spacer(),
              if (model.id == 'gemma-4-e2b-it')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF312E81).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF312E81).withValues(alpha: 0.2)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF312E81)),
                      SizedBox(width: 4),
                      Text('Active in App', style: TextStyle(color: Color(0xFF312E81), fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                )
              else if (model.isInstalled && model.format != ModelFormat.systemNative && model.format != ModelFormat.restCloudApi)
                TextButton.icon(
                  onPressed: () => _deleteModel(model),
                  icon: const Icon(Icons.delete_outline, size: 14, color: Colors.red),
                  label: const Text('Delete', style: TextStyle(color: Colors.red, fontSize: 11)),
                )
              else if (!model.isInstalled && model.format != ModelFormat.restCloudApi)
                OutlinedButton.icon(
                  onPressed: () => _importModel(model),
                  icon: const Icon(Icons.download_rounded, size: 14),
                  label: const Text('Download / Import', style: TextStyle(fontSize: 11)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTaskAssignmentCard(String taskTitle, String activeModelId, String taskKey) {
    final activeModel = _registry.getModel(activeModelId);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(taskTitle, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Theme.of(context).colorScheme.onSurface)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
            ),
            child: DropdownButton<String>(
              value: activeModel?.id,
              isExpanded: true,
              underline: const SizedBox(),
              items: _registry.allModels.map((m) {
                return DropdownMenuItem<String>(
                  value: m.id,
                  child: Text(
                    '${m.displayName} (${m.isInstalled ? "Installed" : "Available"})',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: m.isInstalled ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (val) async {
                if (val == null) return;
                try {
                  await _registry.setActiveModelForTask(taskKey, val);
                  if (mounted) setState(() {});
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
