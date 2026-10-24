import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/network_service.dart';
import '../services/database_service.dart';
import '../services/local_ai_service.dart';
import 'ai_chat_screen.dart';
import 'model_hub_screen.dart';
import 'hotspot_sync_screen.dart';
import 'incident_create_screen.dart';
import 'incident_history_screen.dart';
import 'settings_screen.dart';
import 'equipment_selection_screen.dart';

class HomeDashboardScreen extends StatefulWidget {
  final EquipmentModel equipment;

  const HomeDashboardScreen({super.key, required this.equipment});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  final _netService = NetworkService();
  final _dbService = DatabaseService();
  final _localAi = LocalAiService();

  AiMode _aiMode = AiMode.smartAuto;
  int _pendingIncidentsCount = 0;
  bool _hasKnowledgeInstalled = false;

  @override
  void initState() {
    super.initState();
    _refreshState();
  }

  Future<void> _refreshState() async {
    await _localAi.checkModelReadiness();
    final pending = await _dbService.getPendingIncidents();
    final db = await _dbService.appDb;
    final installed = await db.query(
      'installed_packages',
      where: 'equipment_id = ?',
      whereArgs: [widget.equipment.id],
    );

    setState(() {
      _pendingIncidentsCount = pending.length;
      _hasKnowledgeInstalled = installed.isNotEmpty;
    });
  }

  Color _getNetworkColor(NetworkState state) {
    switch (state) {
      case NetworkState.fullyConnected:
      case NetworkState.hqLanHotspot:
        return Colors.green;
      case NetworkState.publicInternetOnly:
        return Colors.blue;
      case NetworkState.offlineAirgap:
        return Colors.amber.shade700;
    }
  }

  String _getNetworkLabel(NetworkState state) {
    switch (state) {
      case NetworkState.fullyConnected:
        return 'HQ LAN + Internet Connected';
      case NetworkState.hqLanHotspot:
        return 'HQ Hotspot LAN (Air-Gapped)';
      case NetworkState.publicInternetOnly:
        return 'Public Internet Only (No HQ)';
      case NetworkState.offlineAirgap:
        return 'Offline Air-Gap (Zero Network)';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFD),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('EdgeRAG Field Assistant',
                style: TextStyle(
                    fontFamily: 'Metropolis',
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
            Text(widget.equipment.name,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: 'Switch Equipment',
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (_) => const EquipmentSelectionScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshState,
          child: ListView(
            padding: const EdgeInsets.all(20.0),
            children: [
              // 1. Network Status Pill
              StreamBuilder<NetworkState>(
                stream: _netService.stateStream,
                initialData: _netService.currentState,
                builder: (context, snapshot) {
                  final state = snapshot.data ?? NetworkState.offlineAirgap;
                  final color = _getNetworkColor(state);
                  final label = _getNetworkLabel(state);

                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: color.withValues(alpha: 0.08)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                              color: color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            label,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: color),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 18),

              // 2. Active Equipment Hero Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF174EA6),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
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
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            widget.equipment.manufacturer,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _hasKnowledgeInstalled
                                ? Colors.green.withValues(alpha: 0.2)
                                : Colors.amber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _hasKnowledgeInstalled
                                ? 'Knowledge Active'
                                : 'Knowledge Missing',
                            style: TextStyle(
                              color: _hasKnowledgeInstalled
                                  ? Colors.greenAccent
                                  : Colors.amberAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.equipment.name,
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Model: ${widget.equipment.modelNumber} • S/N: ${widget.equipment.serialNumber}',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.6)),
                    ),
                    const SizedBox(height: 20),
                    // AI Mode Toggle Selector
                    Row(
                      children: [
                        _buildModeTab(AiMode.smartAuto, 'Smart Auto'),
                        const SizedBox(width: 8),
                        _buildModeTab(AiMode.offlineOnly, 'Offline Only'),
                        const SizedBox(width: 8),
                        _buildModeTab(AiMode.onlineAi, 'Online AI'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 3. AI Readiness Diagnostic Row
              Row(
                children: [
                  Expanded(
                    child: _buildDiagnosticCard(
                      title: 'AI Engine',
                      status: _aiMode == AiMode.onlineAi
                          ? 'NVIDIA NIM'
                          : (_aiMode == AiMode.smartAuto
                              ? 'NIM / Hybrid'
                              : (_localAi.isModelReady
                                  ? 'Offline GGUF'
                                  : 'Embedded RAG')),
                      isSuccess: true,
                      icon: Icons.psychology,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDiagnosticCard(
                      title: 'Vector Engine',
                      status: '384-d Cosine',
                      isSuccess: true,
                      icon: Icons.hub,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDiagnosticCard(
                      title: 'Pending Sync',
                      status: '$_pendingIncidentsCount Items',
                      isSuccess: _pendingIncidentsCount == 0,
                      icon: Icons.outbox,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Multimodal AI Model Hub Showcase
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ModelHubScreen(
                        equipment: widget.equipment,
                        aiMode: _aiMode,
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B57D0),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF312E81).withValues(alpha: 0.08),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.auto_awesome,
                            color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Explore AI',
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.surface,
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.indigoAccent
                                        .withValues(alpha: 0.4),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '8 Tools',
                                    style: TextStyle(
                                      color:
                                          Theme.of(context).colorScheme.surface,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Vision, Audio Scribe, Video Insights, Voice Assistant & 7 Agent Skills',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.75),
                                fontSize: 11,
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded,
                          color: Colors.white70, size: 16),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 4. Main Quick Actions
              Text(
                'Actions',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface),
              ),
              const SizedBox(height: 12),
              _buildActionTile(
                icon: Icons.chat_bubble_outline,
                title: 'Start AI Diagnostics Chat',
                subtitle:
                    'Ask technical questions with verified manual page citations',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AiChatScreen(
                        equipment: widget.equipment,
                        aiMode: _aiMode,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              _buildActionTile(
                icon: Icons.wifi_tethering,
                title: 'Hotspot Synchronization',
                subtitle:
                    'Download updated manual packages & sync offline incident outbox',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const HotspotSyncScreen()),
                  ).then((_) => _refreshState());
                },
              ),
              const SizedBox(height: 10),
              _buildActionTile(
                icon: Icons.warning_amber_rounded,
                title: 'Record Field Incident',
                subtitle:
                    'Log safety issue or machine anomaly offline with permanent UUID',
                badgeText: _pendingIncidentsCount > 0
                    ? '$_pendingIncidentsCount Pending'
                    : null,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          IncidentCreateScreen(equipment: widget.equipment),
                    ),
                  ).then((_) => _refreshState());
                },
              ),
              const SizedBox(height: 10),
              _buildActionTile(
                icon: Icons.history,
                title: 'Incident Outbox History',
                subtitle: 'Inspect queued offline tickets and sync receipts',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const IncidentHistoryScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeTab(AiMode mode, String label) {
    final isSelected = _aiMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _aiMode = mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color:
                isSelected ? Colors.white : Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? Theme.of(context).colorScheme.onSurface
                    : Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDiagnosticCard({
    required String title,
    required String status,
    required bool isSuccess,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon,
              size: 20,
              color: isSuccess ? Colors.green : Colors.amber.shade700),
          const SizedBox(height: 8),
          Text(title,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          const SizedBox(height: 2),
          Text(status,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    String? badgeText,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: const Color(0xFF174EA6), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                          child: Text(title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500, fontSize: 15))),
                      if (badgeText != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade900),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style:
                          TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }
}
