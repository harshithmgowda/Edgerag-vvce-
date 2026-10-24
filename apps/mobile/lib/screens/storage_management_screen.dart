import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/model_registry_service.dart';

class StorageManagementScreen extends StatefulWidget {
  const StorageManagementScreen({super.key});
  @override
  State<StorageManagementScreen> createState() => _StorageManagementScreenState();
}

class _StorageManagementScreenState extends State<StorageManagementScreen> {
  final db = DatabaseService();
  final models = ModelRegistryService();
  List<Map<String, Object?>> packages = [];
  bool busy = true;
  String? error;
  @override
  void initState() { super.initState(); load(); }
  Future<void> load() async {
    try {
      final rows = await (await db.appDb).query('installed_packages');
      await models.scanInstalledModels();
      if (mounted) setState(() { packages = rows; error = null; });
    } catch (e) { if (mounted) setState(() => error = '$e'); }
    finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> remove(String title, String explanation, Future<void> Function() action) async {
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(title), content: Text(explanation), actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
      ]));
    if (confirmed != true || !mounted) return;
    setState(() => busy = true);
    try {
      await action();
      await load();
    } catch (e) { if (mounted) setState(() { error = '$e'; busy = false; }); }
  }

  Future<void> inspect(String equipmentId) async {
    try {
      final knowledge = await db.getKnowledgeDb(equipmentId);
      if (knowledge == null) throw StateError('Package unavailable');
      final manuals = await knowledge.query('manuals');
      if (!mounted) return;
      await showModalBottomSheet(context: context, isScrollControlled: true,
        showDragHandle: true, builder: (ctx) => SizedBox(
          height: MediaQuery.sizeOf(ctx).height * .75,
          child: ListView(children: [
            const ListTile(title: Text('Downloaded manuals'),
              subtitle: Text('Deletions persist across package updates on this device.')),
            ...manuals.map((manual) => ListTile(
              title: Text('${manual['title']}'),
              subtitle: const Text('Tap to manage individual passages'),
              onTap: () { Navigator.pop(ctx); inspectChunks(equipmentId, '${manual['id']}'); },
              trailing: IconButton(tooltip: 'Delete manual', icon: const Icon(Icons.delete_outline),
                onPressed: () {
                  Navigator.pop(ctx);
                  remove('Delete this manual?', 'Remove all its passages from AI retrieval on this device. To reclaim the immutable package file, delete the package.',
                    () => db.excludeKnowledge(equipmentId, 'manual', '${manual['id']}'));
                }),
            )),
          ]),
        ));
    } catch (e) { if (mounted) setState(() => error = '$e'); }
  }

  Future<void> inspectChunks(String equipmentId, String manualId) async {
    final knowledge = await db.getKnowledgeDb(equipmentId);
    final chunks = await knowledge?.query('chunks', where: 'manual_id = ?', whereArgs: [manualId],
      orderBy: 'page_number') ?? [];
    if (!mounted) return;
    await showModalBottomSheet(context: context, isScrollControlled: true, showDragHandle: true,
      builder: (ctx) => SizedBox(height: MediaQuery.sizeOf(ctx).height * .75,
        child: ListView.builder(itemCount: chunks.length, itemBuilder: (_, index) {
          final chunk = chunks[index];
          return ListTile(title: Text('Page ${chunk['page_number']}'),
            subtitle: Text('${chunk['chunk_text']}', maxLines: 5, overflow: TextOverflow.ellipsis),
            trailing: IconButton(tooltip: 'Delete passage', icon: const Icon(Icons.delete_outline),
              onPressed: () {
                Navigator.pop(ctx);
                remove('Delete this passage?', 'It will no longer be available for AI retrieval on this device.',
                  () => db.excludeKnowledge(equipmentId, 'chunk', '${chunk['id']}'));
              }));
        })));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Storage & knowledge')),
    body: busy ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(
      onRefresh: load, child: ListView(padding: const EdgeInsets.all(20), children: [
        if (error != null) Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        Text('Your offline library', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text('Manage this device’s downloads. Headquarters records are managed separately.'),
        if (packages.isEmpty) const Padding(padding: EdgeInsets.all(24),
          child: Text('No packages downloaded. Sync a package from Headquarters to begin.')),
        ...packages.map((package) {
          final id = '${package['equipment_id']}';
          return Card(child: Column(children: [
            ListTile(title: Text('Equipment $id'), subtitle: Text('Version ${package['version']}'),
              onTap: () => inspect(id), trailing: const Icon(Icons.chevron_right)),
            Wrap(children: [
              TextButton.icon(icon: const Icon(Icons.folder_delete_outlined), label: const Text('Delete package'),
                onPressed: () => remove('Delete downloaded package?', 'Remove its local knowledge database. You can download it again.',
                  () => db.removePackage(id))),
              TextButton.icon(icon: const Icon(Icons.delete_outline), label: const Text('Remove equipment locally'),
                onPressed: () => remove('Remove equipment data?', 'Delete this package, cached equipment, conversations and incidents, including unsynced incidents, from this device.',
                  () => db.removeEquipmentLocally(id))),
            ]),
          ]));
        }),
        const SizedBox(height: 24),
        Text('Installed models', style: Theme.of(context).textTheme.titleLarge),
        ...models.allModels.where((m) => m.installedPath != null).map((model) => ListTile(
          title: Text(model.displayName), subtitle: Text(model.installedPath!),
          trailing: IconButton(tooltip: 'Delete model', icon: const Icon(Icons.delete_outline),
            onPressed: () => remove('Delete ${model.displayName}?', 'Offline tasks using this model will require reinstalling it.',
              () async { if (!await models.deleteModel(model.id)) throw StateError('Model deletion failed.'); })),
        )),
      ])),
  );
}
