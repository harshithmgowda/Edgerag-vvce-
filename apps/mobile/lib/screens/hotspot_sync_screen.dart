import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../services/sync_service.dart';
import '../services/network_service.dart';
import '../services/database_service.dart';
import 'hq_connection_screen.dart';

class HotspotSyncScreen extends StatefulWidget {
  const HotspotSyncScreen({super.key});

  @override
  State<HotspotSyncScreen> createState() => _HotspotSyncScreenState();
}

class _HotspotSyncScreenState extends State<HotspotSyncScreen> {
  final _syncService = SyncService();
  final _netService = NetworkService();
  final _dbService = DatabaseService();

  bool _checking = false;
  bool _syncing = false;
  double _downloadProgress = 0.0;
  String? _statusLog;
  List<KnowledgePackageModel> _availableUpdates = [];
  String _lastSyncDisplay = 'Never synced';
  String _installedVersionDisplay = 'Checking...';
  int _pendingIncidentsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadSyncMetrics();
  }

  Future<void> _loadSyncMetrics() async {
    final lastSync = await _syncService.getLastSyncTimestamp();
    final pending = await _dbService.getPendingIncidents();
    final db = await _dbService.appDb;
    final installed = await db.query('installed_packages', limit: 1);

    if (mounted) {
      setState(() {
        if (lastSync != null) {
          try {
            final dt = DateTime.parse(lastSync).toLocal();
            _lastSyncDisplay = '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
          } catch (_) {
            _lastSyncDisplay = lastSync;
          }
        }
        _pendingIncidentsCount = pending.length;
        if (installed.isNotEmpty) {
          final ver = installed.first['version'] as String;
          _installedVersionDisplay = ver.length > 14 ? '${ver.substring(0, 14)}...' : ver;
        } else {
          _installedVersionDisplay = 'None installed';
        }
      });
    }
  }

  Future<void> _checkUpdates() async {
    setState(() {
      _checking = true;
      _statusLog = 'Connecting to Headquarters at ${_netService.hqBaseUrl}...';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('device_id') ?? 'unknown-device';

      final updates = await _syncService.checkUpdates(deviceId);
      await _loadSyncMetrics();
      setState(() {
        _availableUpdates = updates;
        _statusLog = updates.isEmpty
            ? 'Installed knowledge is fully up to date with Headquarters.'
            : 'Found ${updates.length} available package update(s) at HQ.';
      });
    } catch (e) {
      setState(() => _statusLog = 'Check failed: $e');
    } finally {
      setState(() => _checking = false);
    }
  }

  Future<void> _startPackageDownload(KnowledgePackageModel package) async {
    setState(() {
      _syncing = true;
      _downloadProgress = 0.0;
      _statusLog = 'Downloading ${package.packageFileName} (${(package.fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB)...';
    });

    try {
      await _syncService.downloadAndInstallPackage(
        package,
        onProgress: (p) => setState(() => _downloadProgress = p),
      );
      await _loadSyncMetrics();
      setState(() {
        _statusLog = 'Verified SHA-256 and atomically installed ${package.packageFileName}!';
        _availableUpdates.removeWhere((p) => p.id == package.id);
      });
    } catch (e) {
      setState(() => _statusLog = 'Notice: $e');
    } finally {
      setState(() => _syncing = false);
    }
  }

  Future<void> _syncIncidents() async {
    setState(() => _statusLog = 'Uploading pending offline incidents outbox...');
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('device_id') ?? 'unknown-device';
      final count = await _syncService.syncIncidents(deviceId);
      await _loadSyncMetrics();
      setState(() {
        _statusLog = count > 0
            ? 'Successfully synchronized $count incidents with Headquarters!'
            : 'No pending incidents in outbox to synchronize.';
      });
    } catch (e) {
      setState(() => _statusLog = 'Incident sync failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Hotspot Synchronization', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // LAN Hotspot Banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.wifi_tethering, color: Colors.green.shade700),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Headquarters LAN Sync', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              InkWell(
                                onTap: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => const HqConnectionScreen()))
                                      .then((_) => setState(() {}));
                                },
                                child: const Text('Configure IP', style: TextStyle(fontSize: 11, color: Color(0xFF0284C7), fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text('API: ${_netService.hqBaseUrl}', style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Color(0xFF64748B))),
                          const SizedBox(height: 1),
                          Row(
                            children: [
                              Text('Web: ${_netService.hqWebUrl}', style: const TextStyle(fontFamily: 'monospace', fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF0284C7))),
                              const SizedBox(width: 4),
                              InkWell(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: _netService.hqWebUrl));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Copied ${_netService.hqWebUrl} to clipboard. Open in mobile browser!'), duration: const Duration(seconds: 2)),
                                  );
                                },
                                child: const Icon(Icons.copy, size: 12, color: Color(0xFF0284C7)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Resilience & Sync Telemetry Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _metricColumn('Last Sync', _lastSyncDisplay, Icons.history),
                        _metricColumn('Installed Pkg', _installedVersionDisplay, Icons.inventory_2_outlined),
                        _metricColumn('Outbox', '$_pendingIncidentsCount pending', Icons.outbox_rounded),
                      ],
                    ),
                    if (_availableUpdates.isNotEmpty) ...[
                      const Divider(height: 18),
                      Row(
                        children: [
                          const Icon(Icons.fiber_new, color: Color(0xFF0B57D0), size: 18),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'HQ has ${_availableUpdates.length} newer package(s) available',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0B57D0)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Action Buttons Row
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _checking || _syncing ? null : _checkUpdates,
                      icon: const Icon(Icons.sync, size: 18),
                      label: Text(_checking ? 'Checking...' : 'Check Updates'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _syncing ? null : _syncIncidents,
                      icon: const Icon(Icons.upload, size: 18),
                      label: Text(_pendingIncidentsCount > 0 ? 'Sync Outbox ($_pendingIncidentsCount)' : 'Sync Outbox'),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Progress Bar if downloading + Cancel Button
              if (_syncing) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _downloadProgress,
                    minHeight: 8,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF0F172A)),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Downloading: ${(_downloadProgress * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    TextButton.icon(
                      onPressed: () => _syncService.cancelDownload(),
                      icon: const Icon(Icons.cancel_outlined, size: 14, color: Colors.red),
                      label: const Text('Cancel / Test Rollback', style: TextStyle(fontSize: 11, color: Colors.red)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],

              // Status Log Box
              if (_statusLog != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(_statusLog!, style: const TextStyle(fontSize: 12, height: 1.4)),
                ),

              const SizedBox(height: 16),
              const Text('Available Package Updates', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 10),

              // Available Updates List
              Expanded(
                child: _availableUpdates.isEmpty
                    ? Center(
                        child: Text(
                          'No pending updates. Your phone has all published equipment manuals.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _availableUpdates.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final pkg = _availableUpdates[index];
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.folder_zip, color: Colors.amber, size: 32),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(pkg.packageFileName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      Text('${pkg.version} • ${(pkg.fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB • ${pkg.chunkCount} chunks',
                                          style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                    ],
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: _syncing ? null : () => _startPackageDownload(pkg),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0F172A),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  child: const Text('Install', style: TextStyle(fontSize: 12)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metricColumn(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: Colors.grey.shade600),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
      ],
    );
  }
}
