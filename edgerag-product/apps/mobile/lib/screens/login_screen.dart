import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'equipment_selection_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController(text: 'engineer');
  final _passwordController = TextEditingController(text: '');
  bool _loading = false;

  Future<void> _handleLogin() async {
    setState(() => _loading = true);
    // Offline / Online engineer authentication
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', _usernameController.text);
    await prefs.setString('user_role', 'FIELD_ENGINEER');

    await Future.delayed(const Duration(milliseconds: 300));

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const EquipmentSelectionScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Text('⚡', style: TextStyle(fontSize: 24)),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Field Engineer\nAuthentication',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), height: 1.2),
              ),
              const SizedBox(height: 8),
              const Text(
                'Sign in to access authorized equipment knowledge packages.',
                style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: 'Username',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  prefixIcon: const Icon(Icons.person, size: 20),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  prefixIcon: const Icon(Icons.lock, size: 20),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Sign In', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
