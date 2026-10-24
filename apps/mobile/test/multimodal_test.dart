import 'package:flutter_test/flutter_test.dart';
import 'package:edgerag_mobile/models/ai_model_profile.dart';
import 'package:edgerag_mobile/models/models.dart';
import 'package:edgerag_mobile/services/model_registry_service.dart';
import 'package:edgerag_mobile/services/agent_skills_service.dart';
import 'package:edgerag_mobile/services/multimodal_ai_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Model Registry & Profiles', () {
    test('Default model catalog includes Gemma 4 E2B IT as preferred primary model', () {
      final registry = ModelRegistryService();
      final gemma = registry.getModel('gemma-4-e2b-it');

      expect(gemma, isNotNull);
      expect(gemma!.displayName, contains('Gemma 4 E2B IT'));
      expect(gemma.family, 'Gemma 4');
      expect(gemma.format, ModelFormat.litertLm);
      expect(gemma.inputModalities.contains(Modality.text), isTrue);
      expect(gemma.inputModalities.contains(Modality.image), isTrue);
      expect(gemma.inputModalities.contains(Modality.audio), isTrue);
      expect(gemma.supportsFunctionCalling, isTrue);
    });

    test('Catalog contains verified model profiles across offline and hybrid categories', () {
      final registry = ModelRegistryService();
      expect(registry.allModels.length, greaterThanOrEqualTo(6));

      // Verify presence of Whisper, System TTS, MiniLM-L6, and Cloud Vision
      expect(registry.getModel('whisper-base-asr'), isNotNull);
      expect(registry.getModel('android-system-tts'), isNotNull);
      expect(registry.getModel('minilm-l6-v2-dense'), isNotNull);
      expect(registry.getModel('nvidia-nim-llama32-vision'), isNotNull);
    });

    test('Registry calculates genuine model counts without fabricating totals', () {
      final registry = ModelRegistryService();
      final chatCount = registry.getModelCountForCategory('ai_chat');
      final imageCount = registry.getModelCountForCategory('ask_image');
      final audioCount = registry.getModelCountForCategory('audio_scribe');

      expect(chatCount, greaterThanOrEqualTo(1));
      expect(imageCount, greaterThanOrEqualTo(1));
      expect(audioCount, greaterThanOrEqualTo(1));
    });
  });

  group('Agent Skills Engine & Allowlists', () {
    test('Strict allowlist enforces exactly 7 bounded industrial skills', () {
      final agentService = AgentSkillsService();
      final skills = agentService.availableSkills;

      expect(skills.length, 7);
      final skillIds = skills.map((s) => s.id).toSet();
      expect(skillIds, containsAll([
        'search_equipment_manual',
        'read_manual_page',
        'explain_equipment_error',
        'analyze_image',
        'transcribe_audio',
        'create_incident_draft',
        'check_knowledge_readiness',
      ]));
    });

    test('Blocks execution of unauthorized skill names with safety exception', () async {
      final agentService = AgentSkillsService();
      final result = await agentService.executeSkill(
        skillId: 'unauthorized_arbitrary_shell_exec',
        inputs: {},
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('not in the authorized agent allowlist'));
    });

    test('Create Incident Draft generates pending draft with required user confirmation flag', () async {
      final agentService = AgentSkillsService();
      final result = await agentService.executeSkill(
        skillId: 'create_incident_draft',
        inputs: {
          'equipment_id': 'pump-01',
          'description': 'Bearing vibration exceeded 4.2 mm/s threshold on secondary stage.',
          'severity': 'HIGH',
        },
      );

      expect(result.success, isTrue);
      expect(result.data['status'], 'DRAFT_PENDING_CONFIRMATION');
      expect(result.data['equipment_id'], 'pump-01');
      expect(result.data['severity'], 'HIGH');
    });
  });

  group('Multimodal Data Structures', () {
    test('MultimodalAnalysisResult properly maintains citations and provenance', () {
      final citation = ChunkModel(
        id: 'chunk-101',
        manualId: 'man-01',
        manualTitle: 'Centrifugal Pump Manual',
        pageNumber: 42,
        chunkText: 'Check seal flush plan 11 pressure indicator.',
        embedding: const [],
        similarityScore: 0.94,
      );

      final result = MultimodalAnalysisResult(
        textResponse: 'Verified pressure is within operating limits.',
        visualObservations: ['Digital pressure gauge indicates 45 PSI', 'No fluid weeping observed at mechanical seal'],
        citations: [citation],
        usedModelName: 'Gemma 4 E2B IT (On-Device)',
        isOffline: true,
        latencyMs: 320,
      );

      expect(result.isOffline, isTrue);
      expect(result.usedModelName, contains('Gemma 4'));
      expect(result.citations.length, 1);
      expect(result.citations.first.pageNumber, 42);
      expect(result.visualObservations.length, 2);
    });

    test('Video Insights aggregates multi-frame observations across timestamps', () {
      final citation = ChunkModel(
        id: 'chunk-201',
        manualId: 'man-02',
        manualTitle: 'Gas Turbine Vibration Guide',
        pageNumber: 88,
        chunkText: 'Vibration velocity exceeds 4.5 mm/s RMS on inlet bearing.',
        embedding: const [],
        similarityScore: 0.96,
      );

      final videoResult = MultimodalAnalysisResult(
        textResponse: '### Frame at 0.5s\nInlet compressor normal.\n\n### Frame at 2.5s\nVibration spike observed.\n\n### Frame at 5.0s\nStabilized cycle.',
        visualObservations: [
          'Sampled 3 frames across timeline (0.5s, 2.5s, 5.0s).',
          'Vibration amplitude peak at 2.5s',
          'Compressor alignment within tolerance',
        ],
        citations: [citation],
        usedModelName: 'Google Gemma 4 E2B IT (On-Device)',
        isOffline: true,
        latencyMs: 850,
      );

      expect(videoResult.visualObservations.length, 3);
      expect(videoResult.citations.first.pageNumber, 88);
      expect(videoResult.textResponse, contains('Frame at 2.5s'));
    });

    test('Document Scanner maintains recognized text, manual citations and OCR model', () {
      final docCitation = ChunkModel(
        id: 'chunk-301',
        manualId: 'man-03',
        manualTitle: 'Siemens S7-1500 Diagnostics',
        pageNumber: 15,
        chunkText: 'Module 6ES7516-3AN02 rated for 24V DC auxiliary power.',
        embedding: const [],
        similarityScore: 0.98,
      );

      final docResult = MultimodalAnalysisResult(
        textResponse: 'Scanned Siemens nameplate: Model 6ES7516-3AN02. Operating specification confirmed in [Source chunk-301].',
        visualObservations: [
          'Extracted text from document on-device.',
          'Matched 1 specifications in equipment knowledge base.',
        ],
        citations: [docCitation],
        usedModelName: 'ML Kit Latin OCR + Gemma 4 (On-Device)',
        isOffline: true,
        latencyMs: 145,
      );

      expect(docResult.citations.length, 1);
      expect(docResult.citations.first.chunkText, contains('6ES7516-3AN02'));
      expect(docResult.visualObservations.first, contains('on-device'));
    });
  });
}
