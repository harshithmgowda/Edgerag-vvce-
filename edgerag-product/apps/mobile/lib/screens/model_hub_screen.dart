import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/model_registry_service.dart';
import 'ai_chat_screen.dart';
import 'agent_skills_screen.dart';
import 'ask_image_screen.dart';
import 'audio_scribe_screen.dart';
import 'video_insights_screen.dart';
import 'document_scanner_screen.dart';
import 'voice_assistant_screen.dart';
import 'model_manager_screen.dart';

class ModelHubScreen extends StatefulWidget {
  final EquipmentModel equipment;
  final AiMode aiMode;

  const ModelHubScreen({
    super.key,
    required this.equipment,
    this.aiMode = AiMode.smartAuto,
  });

  @override
  State<ModelHubScreen> createState() => _ModelHubScreenState();
}

class _ModelHubScreenState extends State<ModelHubScreen> {
  final _registry = ModelRegistryService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRegistry();
  }

  Future<void> _loadRegistry() async {
    await _registry.scanInstalledModels();
    if (mounted) {
      setState(() => _isLoading = false);
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
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: Color(0xFF0F172A)),
            tooltip: 'Model Manager',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ModelManagerScreen()),
              ).then((_) => _loadRegistry());
            },
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadRegistry,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                  children: [
              // Header title & subtitle
              const Text(
                'Explore AI',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Powerful intelligence, on your device.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 24),

              // Active Equipment & Mode Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.equipment.name,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'Active Asset • ${widget.equipment.modelNumber}',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        widget.aiMode == AiMode.offlineOnly
                            ? 'Offline Only'
                            : (widget.aiMode == AiMode.onlineAi ? 'Online Cloud' : 'Smart Hybrid'),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4F46E5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Responsive Two-Column Grid of the 8 Required Cards
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 0.85,
                children: [
                  // CARD 1: AI Chat (Blue)
                  _buildHubCard(
                    title: 'AI Chat',
                    description: 'General chat with your chosen local or external AI.',
                    icon: Icons.chat_bubble_rounded,
                    accentColor: const Color(0xFF2563EB), // Blue
                    categoryKey: 'chat',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AiChatScreen(
                            equipmentGrounded: false,                            equipment: widget.equipment,
                            aiMode: widget.aiMode,
                          ),
                        ),
                      );
                    },
                  ),

                  // CARD 2: Agent Skills (Golden/Yellow)
                  _buildHubCard(
                    title: 'Agent Skills',
                    description: 'Complete intelligent tasks with chat.',
                    icon: Icons.auto_awesome_rounded,
                    accentColor: const Color(0xFFD97706), // Golden Amber
                    categoryKey: 'agent',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AgentSkillsScreen(
                            equipment: widget.equipment,
                            aiMode: widget.aiMode,
                          ),
                        ),
                      );
                    },
                  ),

                  // CARD 3: Ask Image (Red)
                  _buildHubCard(
                    title: 'Ask Image',
                    description: 'Ask questions about images.',
                    icon: Icons.image_rounded,
                    accentColor: const Color(0xFFDC2626), // Red
                    categoryKey: 'image',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AskImageScreen(
                            equipment: widget.equipment,
                            aiMode: widget.aiMode,
                          ),
                        ),
                      );
                    },
                  ),

                  // CARD 4: Audio Scribe (Green)
                  _buildHubCard(
                    title: 'Audio Scribe',
                    description: 'Transcribe and translate audio.',
                    icon: Icons.mic_rounded,
                    accentColor: const Color(0xFF059669), // Green
                    categoryKey: 'audio',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AudioScribeScreen(
                            equipment: widget.equipment,
                            aiMode: widget.aiMode,
                          ),
                        ),
                      );
                    },
                  ),

                  // CARD 5: Video Insights (Purple)
                  _buildHubCard(
                    title: 'Video Insights',
                    description: 'Understand equipment videos.',
                    icon: Icons.videocam_rounded,
                    accentColor: const Color(0xFF7C3AED), // Purple
                    categoryKey: 'video',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => VideoInsightsScreen(
                            equipment: widget.equipment,
                            aiMode: widget.aiMode,
                          ),
                        ),
                      );
                    },
                  ),

                  // CARD 6: Document Scanner (Orange)
                  _buildHubCard(
                    title: 'Document Scanner',
                    description: 'Read technical documents and labels.',
                    icon: Icons.document_scanner_rounded,
                    accentColor: const Color(0xFFEA580C), // Orange
                    categoryKey: 'scanner',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DocumentScannerScreen(
                            equipment: widget.equipment,
                            aiMode: widget.aiMode,
                          ),
                        ),
                      );
                    },
                  ),

                  // CARD 7: Voice Assistant (Teal/Cyan soundwaves)
                  _buildHubCard(
                    title: 'Voice Assistant',
                    description: 'Talk with your equipment assistant.',
                    icon: Icons.graphic_eq_rounded,
                    accentColor: const Color(0xFF0D9488), // Teal
                    categoryKey: 'voice',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => VoiceAssistantScreen(
                            equipment: widget.equipment,
                            aiMode: widget.aiMode,
                          ),
                        ),
                      );
                    },
                  ),

                  // CARD 8: Model Manager (Indigo Chip)
                  _buildHubCard(
                    title: 'Model Manager',
                    description: 'Install and manage AI models.',
                    icon: Icons.memory_rounded,
                    accentColor: const Color(0xFF4F46E5), // Indigo
                    categoryKey: 'manager',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ModelManagerScreen()),
                      ).then((_) => _loadRegistry());
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHubCard({
    required String title,
    required String description,
    required IconData icon,
    required Color accentColor,
    required String categoryKey,
    required VoidCallback onTap,
  }) {
    final availableCount = _registry.getModelCountForCategory(categoryKey);
    final installedCount = _registry.getInstalledCountForCategory(categoryKey);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Icon container with soft ambient glow
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: accentColor, size: 24),
                ),
                // Local / Online pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: installedCount > 0
                        ? const Color(0xFFECFDF5)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    installedCount > 0 ? 'On-Device' : 'Cloud / Setup',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: installedCount > 0 ? const Color(0xFF059669) : Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),

            // Text block
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.35,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),

            // Footer showing real model count
            Row(
              children: [
                Text(
                  availableCount > 0 ? '$availableCount models available' : 'No models installed',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: availableCount > 0 ? accentColor : Colors.grey.shade400,
                  ),
                ),
                const Spacer(),
                Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Colors.grey.shade400),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
