import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../services/network_service.dart';
import 'device_registration_screen.dart';

class HqConnectionScreen extends StatefulWidget {
  const HqConnectionScreen({super.key});

  @override
  State<HqConnectionScreen> createState() => _HqConnectionScreenState();
}

class _HqConnectionScreenState extends State<HqConnectionScreen> {
  final _netService = NetworkService();
  late final TextEditingController _urlController;
  bool _testing = false;
  bool _discovering = false;
  bool _testingWeb = false;
  String? _statusMessage;
  bool _isSuccess = false;
  bool? _webPortalReachable;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: _netService.hqBaseUrl);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _statusMessage = null;
      _webPortalReachable = null;
    });

    try {
      final cleanUrl = _urlController.text.trim();
      await _netService.updateHqUrl(cleanUrl);
      final state = await _netService.checkConnectivity();

      if (state == NetworkState.hqLanHotspot || state == NetworkState.fullyConnected) {
        // Also probe web portal (port 3000)
        final webOk = await _netService.probeWebPortal();
        setState(() {
          _isSuccess = true;
          _webPortalReachable = webOk;
          _statusMessage = 'Connected to Backend (${_netService.hqHost}:8000)!';
        });
      } else {
        setState(() {
          _isSuccess = false;
          _statusMessage = 'Could not reach Headquarters server at $cleanUrl.\nEnsure your phone is connected to the laptop Hotspot.';
        });
      }
    } catch (e) {
      setState(() {
        _isSuccess = false;
        _statusMessage = 'Connection error: $e';
      });
    } finally {
      setState(() => _testing = false);
    }
  }

  Future<void> _runAutoDiscovery() async {
    setState(() {
      _discovering = true;
      _statusMessage = 'Scanning network interfaces and common hotspot gateways...';
      _isSuccess = false;
    });

    try {
      final found = await _netService.autoDiscoverHotspotGateway();
      if (found != null) {
        _urlController.text = found;
        final webOk = await _netService.probeWebPortal();
        setState(() {
          _isSuccess = true;
          _webPortalReachable = webOk;
          _statusMessage = 'Auto-discovered active Headquarters server at $found!';
        });
      } else {
        setState(() {
          _isSuccess = false;
          _statusMessage = 'No active Headquarters found on scanned subnets. Check hotspot connection.';
        });
      }
    } catch (e) {
      setState(() {
        _isSuccess = false;
        _statusMessage = 'Discovery failed: $e';
      });
    } finally {
      setState(() => _discovering = false);
    }
  }

  Future<void> _testWebOnly() async {
    setState(() => _testingWeb = true);
    final ok = await _netService.probeWebPortal();
    setState(() {
      _testingWeb = false;
      _webPortalReachable = ok;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok
              ? 'HQ Web Portal at ${_netService.hqWebUrl} is reachable!'
              : 'HQ Web Portal at ${_netService.hqWebUrl} did not respond. Check Next.js dev server.'),
          backgroundColor: ok ? Colors.green.shade800 : Colors.red.shade800,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _copyWebLink() {
    Clipboard.setData(ClipboardData(text: _netService.hqWebUrl));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied ${_netService.hqWebUrl} to clipboard. Open in mobile browser!'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Hotspot & Web Network Setup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hotspot instruction banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Row(
                  children: [
                    Icon(Icons.wifi_tethering, color: Colors.blue.shade700, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Connect your phone to the laptop Hotspot to sync offline knowledge packages and access the Web portal.',
                        style: TextStyle(fontSize: 13, color: Colors.blue.shade900, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Server URL input
              const Text(
                'Headquarters API Endpoint',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _urlController,
                decoration: InputDecoration(
                  hintText: 'http://192.168.137.1:8000/api/v1',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  prefixIcon: const Icon(Icons.link, size: 20),
                ),
                style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 10),

              // Hotspot preset chips
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.wifi_tethering, size: 15, color: Color(0xFF0F172A)),
                    label: const Text('Windows Hotspot (192.168.137.1)', style: TextStyle(fontSize: 11)),
                    onPressed: () {
                      _urlController.text = 'http://192.168.137.1:8000/api/v1';
                      _testConnection();
                    },
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.phone_android, size: 15, color: Color(0xFF0F172A)),
                    label: const Text('Phone Hotspot (192.168.43.1)', style: TextStyle(fontSize: 11)),
                    onPressed: () {
                      _urlController.text = 'http://192.168.43.1:8000/api/v1';
                      _testConnection();
                    },
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.wifi, size: 15, color: Color(0xFF0F172A)),
                    label: const Text('Wi-Fi LAN (192.168.1.85)', style: TextStyle(fontSize: 11)),
                    onPressed: () {
                      _urlController.text = 'http://192.168.1.85:8000/api/v1';
                      _testConnection();
                    },
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.explore, size: 15, color: Color(0xFF0B57D0)),
                    label: const Text('Auto-Discover Hotspot', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0B57D0))),
                    onPressed: _discovering ? null : _runAutoDiscovery,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Action buttons row
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: OutlinedButton.icon(
                        onPressed: _testing || _discovering ? null : _testConnection,
                        icon: _testing
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.refresh, size: 16),
                        label: Text(_testing ? 'Testing...' : 'Test Connection'),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: ElevatedButton.icon(
                        onPressed: _discovering || _testing ? null : _runAutoDiscovery,
                        icon: _discovering
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.radar, size: 16),
                        label: Text(_discovering ? 'Scanning...' : 'Scan Subnets'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Status message box
              if (_statusMessage != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isSuccess ? Colors.green.shade50 : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _isSuccess ? Colors.green.shade200 : Colors.red.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(_isSuccess ? Icons.check_circle : Icons.error, color: _isSuccess ? Colors.green : Colors.red, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _statusMessage!,
                          style: TextStyle(fontSize: 12, color: _isSuccess ? Colors.green.shade900 : Colors.red.shade900, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // HQ Web Portal Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2)),
                  ],
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
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.language, color: Color(0xFF0284C7), size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Headquarters Web Dashboard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              SizedBox(height: 2),
                              Text('Connect phone or laptop browser over hotspot', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ),
                        if (_webPortalReachable != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _webPortalReachable! ? Colors.green.shade50 : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _webPortalReachable! ? 'Online' : 'Unreachable',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _webPortalReachable! ? Colors.green.shade700 : Colors.red.shade700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const Divider(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.public, size: 16, color: Color(0xFF64748B)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _netService.hqWebUrl,
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy, size: 16, color: Color(0xFF0284C7)),
                            onPressed: _copyWebLink,
                            tooltip: 'Copy Web Link',
                            constraints: const BoxConstraints(),
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Open this link in any browser (Chrome, Safari) on devices connected to the hotspot to view equipment manuals, manage AI models, and review technician incidents.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _testingWeb ? null : _testWebOnly,
                        icon: _testingWeb
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.check_circle_outline, size: 16),
                        label: Text(_testingWeb ? 'Checking Web Portal...' : 'Test Web Portal Reachability (Port 3000)'),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Bottom navigation button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const DeviceRegistrationScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Continue to Device Setup', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
