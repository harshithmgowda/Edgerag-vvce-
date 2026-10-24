import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/network_service.dart';

/// Admin credentials are exchanged for a short-lived in-memory bearer token.
class HqDataScreen extends StatefulWidget {
  final String initialCategory;
  final http.Client? client;
  const HqDataScreen({super.key, this.initialCategory = 'equipment', this.client})
      : assert(initialCategory == 'equipment' || initialCategory == 'manuals' || initialCategory == 'packages');
  @override
  State<HqDataScreen> createState() => _HqDataScreenState();
}

class _HqDataScreenState extends State<HqDataScreen> {
  final username = TextEditingController();
  final password = TextEditingController();
  String? token;
  String category = 'equipment';
  String? error;
  bool busy = false;
  List<dynamic> records = [];
  String get base => NetworkService().hqBaseUrl;
  late final http.Client client;
  @override
  void initState() {
    super.initState();
    category = widget.initialCategory;
    client = widget.client ?? http.Client();
  }
  @override
  void dispose() { if (widget.client == null) client.close(); username.dispose(); password.dispose(); super.dispose(); }

  void checkResponse(http.Response response, String action) {
    if (response.statusCode == 200) return;
    if (response.statusCode == 401 || response.statusCode == 403) {
      if (mounted) setState(() { token = null; records = []; });
      throw StateError('Your administrator session expired or lacks permission. Sign in again to continue.');
    }
    var detail = response.body;
    try { detail = jsonDecode(response.body)['detail'].toString(); } catch (_) {}
    throw StateError('$action (${response.statusCode}): $detail');
  }

  Future<void> login() async {
    setState(() { busy = true; error = null; });
    try {
      final response = await client.post(Uri.parse('$base/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username.text.trim(), 'password': password.text}))
        .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) throw StateError('Sign-in failed. Check your HQ account.');
      final data = jsonDecode(response.body);
      if (data['user']['role'] != 'ADMIN') throw StateError('An administrator account is required.');
      token = data['access_token'];
      password.clear();
      await load();
    } catch (e) { if (mounted) setState(() => error = '$e'); }
    finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> load() async {
    if (mounted) setState(() { busy = true; error = null; });
    try {
      final response = await client.get(Uri.parse('$base/$category'),
        headers: {'Authorization': 'Bearer $token'}).timeout(const Duration(seconds: 15));
      checkResponse(response, 'Unable to load HQ records');
      final rows = jsonDecode(response.body) as List;
      if (mounted) setState(() => records = rows);
    } catch (e) { if (mounted) setState(() => error = '$e'); }
    finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> remove(Map<String, dynamic> row) async {
    if (busy) return;
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text('Delete ${row['name'] ?? row['title'] ?? row['package_file_name']}?'),
      content: Text(category == 'equipment'
        ? 'Permanently delete the HQ equipment, manuals, packages and incidents. Devices already offline retain their downloads until removed locally.'
        : category == 'manuals'
          ? 'Permanently delete the HQ PDF and invalidate every package for this equipment. Publish a fresh package for remaining manuals.'
          : 'Permanently delete this published package and its ZIP file.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete from HQ')),
      ]));
    if (confirmed != true || !mounted) return;
    setState(() => busy = true);
    try {
      final response = await client.delete(Uri.parse('$base/$category/${row['id']}'),
        headers: {'Authorization': 'Bearer $token'}).timeout(const Duration(seconds: 30));
      checkResponse(response, 'Deletion failed');
      final data = jsonDecode(response.body);
      if (data['deleted'] != true) throw StateError('Deletion was not confirmed. Refresh and try again.');
      if (mounted) setState(() => records.removeWhere((item) => item['id'] == row['id']));
      // Keep the offline equipment picker from resurrecting a deleted HQ record.
      if (category == 'equipment') {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString('cached_equipment');
        if (cached != null) {
          final rows = (jsonDecode(cached) as List)
              .where((item) => item['id'] != row['id']).toList();
          await prefs.setString('cached_equipment', jsonEncode(rows));
        }
        if (prefs.getString('active_equipment_id') == row['id']) {
          for (final key in ['active_equipment_id', 'active_equipment_name', 'active_equipment_model']) {
            await prefs.remove(key);
          }
        }
      }
      await load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted from Headquarters')));
      }
      if (mounted && (data['cleanup_pending'] ?? 0) > 0) {
        setState(() => error = 'Record deleted. HQ filesystem cleanup needs administrator attention.');
      }
    } catch (e) { if (mounted) setState(() => error = '$e'); }
    finally { if (mounted) setState(() => busy = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Manage equipment & manuals')),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      if (error != null) Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      if (busy) const LinearProgressIndicator(),
      if (token == null) ...[
        const Text('Delete equipment and manuals from Headquarters. Connect to HQ and sign in with an administrator account. Offline downloads are managed separately in Storage & knowledge.'),
        const SizedBox(height: 16),
        TextField(controller: username, decoration: const InputDecoration(labelText: 'Username')),
        const SizedBox(height: 12),
        TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
        FilledButton(onPressed: busy ? null : login, child: const Text('Sign in')),
      ] else ...[
        DropdownButton<String>(value: category, isExpanded: true,
          items: ['equipment', 'manuals', 'packages'].map((s) =>
            DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: busy ? null : (value) { setState(() { category = value!; records = []; }); load(); }),
        if (records.isEmpty && !busy) const ListTile(title: Text('No records found')),
        ...records.map((row) => Card(child: ListTile(
          title: Text('${row['name'] ?? row['title'] ?? row['package_file_name']}'),
          subtitle: Text('${row['id']}'),
          trailing: IconButton(tooltip: 'Delete from HQ', color: Theme.of(context).colorScheme.error, icon: const Icon(Icons.delete_outline),
            onPressed: busy ? null : () => remove(Map<String, dynamic>.from(row))),
        ))),
      ],
    ]),
  );
}
