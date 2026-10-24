import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import '../models/models.dart';
import '../services/network_service.dart';


class ManualPagePreview extends StatefulWidget {
  final ChunkModel chunk;
  const ManualPagePreview({super.key, required this.chunk});
  @override
  State<ManualPagePreview> createState() => _ManualPagePreviewState();
}
class _ManualPagePreviewState extends State<ManualPagePreview> {
  Uint8List? bytes;
  String? error;
  bool busy = false;
  Future<File> cacheFile() async {
    final docs = await getApplicationDocumentsDirectory();
    final key = sha256.convert(utf8.encode('${widget.chunk.manualId}:${widget.chunk.manualRevision}:${widget.chunk.pageNumber}')).toString();
    return File('${docs.path}/source_pages/$key.png');
  }
  Future<void> open() async {
    setState(() { busy = true; error = null; });
    try {
      final file = await cacheFile();
      if (await file.exists()) {
        final saved = await file.readAsBytes();
        if (mounted) setState(() => bytes = saved);
        return;
      }
      if (!mounted) return;
      final user = TextEditingController(), password = TextEditingController();
      final login = await showDialog<Map<String,String>>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Sign in to view original page'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('The page is saved on this device for offline viewing.'),
          TextField(controller: user, decoration: const InputDecoration(labelText: 'Administrator username')),
          TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
        ]), actions: [TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: ()=>Navigator.pop(ctx, {'username': user.text, 'password': password.text}), child: const Text('Open page'))]));
      // Dialog route may still be animating; controllers are disposed after the frame.
      Future.delayed(const Duration(seconds: 1), () { user.dispose(); password.dispose(); });
      if (login == null) return;
      final base = NetworkService().hqBaseUrl;
      final auth = await http.post(Uri.parse('$base/auth/login'), headers: {'Content-Type':'application/json'}, body: jsonEncode(login)).timeout(const Duration(seconds: 15));
      if (auth.statusCode != 200) throw StateError('Sign-in failed');
      final token = jsonDecode(auth.body)['access_token'];
      final uri = Uri.parse('$base/manuals/${Uri.encodeComponent(widget.chunk.manualId)}/pages/${widget.chunk.pageNumber}').replace(queryParameters: {'excerpt': widget.chunk.chunkText.substring(0, widget.chunk.chunkText.length.clamp(0,180))});
      final response = await http.get(uri, headers: {'Authorization':'Bearer $token'}).timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) throw StateError('Original page unavailable (${response.statusCode})');
      await file.parent.create(recursive:true);
      await file.writeAsBytes(response.bodyBytes, flush:true);
      if (mounted) setState(() => bytes = response.bodyBytes);
    } catch (e) { if (mounted) setState(() => error = '$e'); }
    finally { if (mounted) setState(() => busy = false); }
  }
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    OutlinedButton.icon(onPressed: busy ? null : open, icon: const Icon(Icons.description_outlined), label: Text(busy ? 'Opening…' : 'Open original page')),
    if (error != null) Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
    if (bytes != null) ...[const Text('Original page · saved offline. Exact matches highlighted when available.'),
      SizedBox(height: 420, child: InteractiveViewer(child: Image.memory(bytes!, fit: BoxFit.contain)))],
  ]);
}
