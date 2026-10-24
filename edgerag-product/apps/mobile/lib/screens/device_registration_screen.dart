import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'login_screen.dart';

class DeviceRegistrationScreen extends StatefulWidget {
  const DeviceRegistrationScreen({super.key});

  @override
  State<DeviceRegistrationScreen> createState() => _DeviceRegistrationScreenState();
}

class _DeviceRegistrationScreenState extends State<DeviceRegistrationScreen> {
  final _deviceNameController = TextEditingController(text: 'Field Android Unit');
  final _deviceIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _deviceIdController.text = const Uuid().v4();
  }

  Future<void> _saveAndContinue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('device_id', _deviceIdController.text);
    await prefs.setString('device_name', _deviceNameController.text);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Device Identity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Register Device Identity',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 8),
              const Text(
                'This unique hardware identifier tracks your offline incident outbox and package installations.',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
              ),
              const SizedBox(height: 28),
              const Text('Device Label', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
              const SizedBox(height: 8),
              TextField(
                controller: _deviceNameController,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  prefixIcon: const Icon(Icons.smartphone, size: 20),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Hardware UUID (Auto-generated)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
              const SizedBox(height: 8),
              TextField(
                controller: _deviceIdController,
                readOnly: true,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.blueGrey.shade100,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  prefixIcon: const Icon(Icons.fingerprint, size: 20),
                ),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _saveAndContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Save & Continue to Login', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
