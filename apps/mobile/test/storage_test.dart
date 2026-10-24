import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:edgerag_mobile/services/database_service.dart';

class TestPaths extends PathProviderPlatform {
  final String root;
  TestPaths(this.root);
  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Deleted chunks/manuals stay excluded across reopen; package removal removes file', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final temp = await Directory.systemTemp.createTemp('edgerag_storage_test_');
    PathProviderPlatform.instance = TestPaths(temp.path);
    final file = File('${temp.path}/knowledge_test-equipment.db');
    final source = await openDatabase(file.path);
    await source.execute('CREATE TABLE manuals(id TEXT PRIMARY KEY, title TEXT)');
    await source.execute('CREATE TABLE chunks(id TEXT PRIMARY KEY, manual_id TEXT, page_number INTEGER, chunk_text TEXT)');
    await source.insert('manuals', {'id': 'manual-a', 'title': 'Pump Manual'});
    for (final id in ['a', 'b']) {
      await source.insert('chunks', {'id': id, 'manual_id': 'manual-a',
        'page_number': 1, 'chunk_text': 'Pump pressure check $id'});
    }
    await source.close();
    final service = DatabaseService();
    final app = await service.appDb;
    await app.insert('installed_packages', {'equipment_id': 'test-equipment',
      'package_id': 'package-a', 'version': '1', 'chunk_count': 2, 'installed_at': '2026-10-20T00:00:00Z'});
    expect(await service.searchKnowledgeChunks('test-equipment', 'pump pressure'), hasLength(2));
    await service.excludeKnowledge('test-equipment', 'chunk', 'a');
    expect((await service.searchKnowledgeChunks('test-equipment', 'pump pressure')).map((c) => c.id), ['b']);
    await service.closeKnowledgeDb('test-equipment');
    final reopened = await service.getKnowledgeDb('test-equipment');
    expect((await reopened!.query('chunks')).map((c) => c['id']), ['b']);
    // Package bytes remain immutable; the filtered view enforces deletion.
    expect(await reopened.rawQuery('SELECT * FROM main.chunks'), hasLength(2));
    await service.excludeKnowledge('test-equipment', 'manual', 'manual-a');
    expect(await service.searchKnowledgeChunks('test-equipment', 'pump pressure'), isEmpty);
    await service.removePackage('test-equipment');
    expect(await file.exists(), isFalse);
    expect(await service.getKnowledgeDb('test-equipment'), isNull);
    await app.close();
    await temp.delete(recursive: true);
  });
}
