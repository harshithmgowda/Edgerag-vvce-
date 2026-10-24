import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/network_service.dart';
import 'provider_settings_screen.dart';
import 'hotspot_sync_screen.dart';
import 'hq_connection_screen.dart';
import 'onboarding_screen.dart';
import 'storage_management_screen.dart';
import 'hq_data_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _deviceId = 'Loading...';
  String _deviceName = 'Field Android Unit';

  @override
  void initState() {
    super.initState();
    _loadDevice();
  }

  Future<void> _loadDevice() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _deviceId = prefs.getString('device_id') ?? 'Unregistered';
      _deviceName = prefs.getString('device_name') ?? 'Field Android Unit';
    });
  }

  Future<void> _signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_name');
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      appBar: AppBar(
        title: const Text('Settings & Configuration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20.0),
          children: [
            _buildSettingTile(icon: Icons.storage_rounded, title: 'Storage & knowledge',
              subtitle: 'Delete packages, manuals, passages and models',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StorageManagementScreen()))),
            const SizedBox(height: 8),
            _buildSettingTile(icon: Icons.admin_panel_settings_outlined, title: 'Manage equipment & manuals',
              subtitle: 'Delete HQ equipment, manuals and packages (admin)',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HqDataScreen()))),
            const SizedBox(height: 16),
            // Device Identity Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.fingerprint, color: Theme.of(context).colorScheme.onSurface, size: 22),
                      const SizedBox(width: 10),
                      Text(_deviceName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('UUID: $_deviceId', style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('Network & Synchronization', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 10),
            _buildSettingTile(
              icon: Icons.wifi_tethering,
              title: 'HQ Connection Endpoint',
              subtitle: NetworkService().hqBaseUrl,
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const HqConnectionScreen()));
              },
            ),
            const SizedBox(height: 8),
            _buildSettingTile(
              icon: Icons.sync,
              title: 'Hotspot Synchronization Manager',
              subtitle: 'Check for package updates and sync incident outbox',
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const HotspotSyncScreen()));
              },
            ),
            const SizedBox(height: 20),
            Text('AI & Language Models', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 10),
            _buildSettingTile(
              icon: Icons.key,
              title: 'External AI Providers (BYOK)',
              subtitle: 'Configure personal Google Gemini key for online RAG',
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ProviderSettingsScreen()));
              },
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _signOut,
                icon: const Icon(Icons.logout, size: 18, color: Colors.red),
                label: const Text('Sign Out & Unpair Device', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.red.shade200),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.onSurface, size: 22),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
