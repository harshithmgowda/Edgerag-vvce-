import 'package:flutter/material.dart';
import '../services/gemini_service.dart';
import '../services/nvidia_service.dart';

class ProviderSettingsScreen extends StatefulWidget {
  const ProviderSettingsScreen({super.key});

  @override
  State<ProviderSettingsScreen> createState() => _ProviderSettingsScreenState();
}

class _ProviderSettingsScreenState extends State<ProviderSettingsScreen> {
  final _nvidiaKeyController = TextEditingController();
  final _geminiKeyController = TextEditingController();

  final _nvidiaService = NvidiaService();
  final _geminiService = GeminiService();

  String _nvidiaModel = 'nvidia/nemotron-3-ultra-550b-a55b';
  String _geminiModel = 'gemini-flash-latest';

  int _selectedTabIndex = 0; // 0 = NVIDIA NIM, 1 = Google Gemini

  bool _testing = false;
  String? _testResult;
  bool _testSuccess = false;

  @override
  void initState() {
    super.initState();
    _loadKeys();
  }

  Future<void> _loadKeys() async {
    final nvKey = await _nvidiaService.getApiKey();
    final nvModel = await _nvidiaService.getSelectedModel();
    final gemKey = await _geminiService.getApiKey();
    final gemModel = await _geminiService.getSelectedModel();

    final activeNvModel = (nvModel == 'meta/llama-3.2-11b-vision-instruct' || nvModel.isEmpty)
        ? 'nvidia/nemotron-3-ultra-550b-a55b'
        : nvModel;

    setState(() {
      _nvidiaKeyController.text = nvKey.isNotEmpty ? nvKey : NvidiaService.defaultKey;
      _nvidiaModel = activeNvModel;
      if (gemKey != null) _geminiKeyController.text = gemKey;
      _geminiModel = gemModel;
    });
  }

  Future<void> _testAndSaveNvidia() async {
    final key = _nvidiaKeyController.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter an NVIDIA NIM API key.')));
      return;
    }

    setState(() {
      _testing = true;
      _testResult = null;
    });

    final res = await _nvidiaService.testConnection(key, model: _nvidiaModel);

    setState(() {
      _testing = false;
      _testSuccess = res.success;
      _testResult = '${res.message} (${res.latencyMs}ms)';
    });

    if (res.success) {
      await _nvidiaService.saveApiKey(key, model: _nvidiaModel);
    }
  }

  Future<void> _testAndSaveGemini() async {
    final key = _geminiKeyController.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid Gemini API key.')));
      return;
    }

    setState(() {
      _testing = true;
      _testResult = null;
    });

    final res = await _geminiService.testConnection(key, model: _geminiModel);

    setState(() {
      _testing = false;
      _testSuccess = res.success;
      _testResult = '${res.message} (${res.latencyMs}ms)';
    });

    if (res.success) {
      await _geminiService.saveApiKey(key, model: _geminiModel);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Online AI Providers (BYOK)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24.0),
          children: [
            // Provider Tab Switcher
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _selectedTabIndex = 0;
                        _testResult = null;
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedTabIndex == 0 ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: _selectedTabIndex == 0
                              ? const [BoxShadow(color: Color(0x0F000000), blurRadius: 4, offset: Offset(0, 2))]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.bolt, size: 16, color: _selectedTabIndex == 0 ? const Color(0xFF16A34A) : Colors.grey),
                            const SizedBox(width: 6),
                            Text(
                              'NVIDIA NIM',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _selectedTabIndex == 0 ? const Color(0xFF0F172A) : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _selectedTabIndex = 1;
                        _testResult = null;
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedTabIndex == 1 ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: _selectedTabIndex == 1
                              ? const [BoxShadow(color: Color(0x0F000000), blurRadius: 4, offset: Offset(0, 2))]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.auto_awesome, size: 16, color: _selectedTabIndex == 1 ? Colors.blue : Colors.grey),
                            const SizedBox(width: 6),
                            Text(
                              'Google Gemini',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _selectedTabIndex == 1 ? const Color(0xFF0F172A) : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (_selectedTabIndex == 0) _buildNvidiaSection() else _buildGeminiSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildNvidiaSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.bolt, color: Color(0xFF16A34A), size: 20),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('NVIDIA NIM API', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text('NVIDIA Nemotron 3 Ultra 550B · Cloud Inference', style: TextStyle(color: Colors.grey, fontSize: 11)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text('API Key Secret *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
          const SizedBox(height: 6),
          TextField(
            controller: _nvidiaKeyController,
            obscureText: true,
            decoration: InputDecoration(
              hintText: 'nvapi-...',
              filled: true,
              fillColor: Colors.blueGrey.shade50,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.key, size: 18),
            ),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
          const SizedBox(height: 14),
          const Text('Target Model', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _nvidiaModel,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.blueGrey.shade50,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: const [
              DropdownMenuItem(
                value: 'nvidia/nemotron-3-ultra-550b-a55b',
                child: Text('nvidia/nemotron-3-ultra-550b-a55b (550B Ultra - Recommended)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              DropdownMenuItem(
                value: 'meta/llama-3.2-11b-vision-instruct',
                child: Text('meta/llama-3.2-11b-vision-instruct (Vision)', style: TextStyle(fontSize: 12)),
              ),
              DropdownMenuItem(
                value: 'deepseek-ai/deepseek-v4.1-flash',
                child: Text('deepseek-ai/deepseek-v4.1-flash', style: TextStyle(fontSize: 12)),
              ),
              DropdownMenuItem(
                value: 'google/gemma-3-12b-it',
                child: Text('google/gemma-3-12b-it', style: TextStyle(fontSize: 12)),
              ),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _nvidiaModel = val);
            },
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _testing ? null : _testAndSaveNvidia,
              icon: _testing
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.check, size: 18),
              label: Text(_testing ? 'Testing Live NIM Connection...' : 'Test & Save to Secure Storage'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          if (_testResult != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _testSuccess ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _testSuccess ? Colors.green.shade200 : Colors.red.shade200),
              ),
              child: Text(
                _testResult!,
                style: TextStyle(
                  fontSize: 12,
                  color: _testSuccess ? Colors.green.shade900 : Colors.red.shade900,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGeminiSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.auto_awesome, color: Colors.blue, size: 20),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Google Gemini API', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text('Personal field key for direct cloud RAG', style: TextStyle(color: Colors.grey, fontSize: 11)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text('API Key Secret *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
          const SizedBox(height: 6),
          TextField(
            controller: _geminiKeyController,
            obscureText: true,
            decoration: InputDecoration(
              hintText: 'AIzaSy...',
              filled: true,
              fillColor: Colors.blueGrey.shade50,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.key, size: 18),
            ),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
          const SizedBox(height: 14),
          const Text('Model Version', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _geminiModel,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.blueGrey.shade50,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: const [
              DropdownMenuItem(value: 'gemini-flash-latest', child: Text('gemini-flash-latest (Recommended)', style: TextStyle(fontSize: 12))),
              DropdownMenuItem(value: 'gemini-3.8-flash', child: Text('gemini-3.8-flash', style: TextStyle(fontSize: 12))),
              DropdownMenuItem(value: 'gemini-2.5-flash', child: Text('gemini-2.5-flash', style: TextStyle(fontSize: 12))),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _geminiModel = val);
            },
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _testing ? null : _testAndSaveGemini,
              icon: _testing
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.check, size: 18),
              label: Text(_testing ? 'Testing Live Request...' : 'Test & Save to Secure Storage'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          if (_testResult != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _testSuccess ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _testSuccess ? Colors.green.shade200 : Colors.red.shade200),
              ),
              child: Text(
                _testResult!,
                style: TextStyle(
                  fontSize: 12,
                  color: _testSuccess ? Colors.green.shade900 : Colors.red.shade900,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
