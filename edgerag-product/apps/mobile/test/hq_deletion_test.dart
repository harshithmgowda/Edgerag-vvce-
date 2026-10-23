import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edgerag_mobile/screens/hq_data_screen.dart';

void main() {
  for (final category in ['equipment', 'manuals']) {
    testWidgets('$category deletion confirms, handles failure and refreshes', (tester) async {
      SharedPreferences.setMockInitialValues({
        'cached_equipment': jsonEncode([{'id': 'asset-1', 'name': 'Pump'}]),
        'active_equipment_id': 'asset-1',
      });
      var deletions = 0;
      var deleted = false;
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/auth/login')) {
          return http.Response(jsonEncode({'access_token': 'test-token', 'user': {'role': 'ADMIN'}}), 200);
        }
        expect(request.headers['Authorization'], 'Bearer test-token');
        if (request.method == 'DELETE') {
          expect(request.url.path, '/api/v1/$category/asset-1');
          deletions++;
          if (deletions == 1) return http.Response('Processing job active', 409);
          deleted = true;
          return http.Response('{"deleted":true,"cleanup_pending":0}', 200);
        }
        expect(request.url.path, '/api/v1/$category');
        return http.Response(jsonEncode(deleted ? [] : [{'id': 'asset-1', 'name': 'Pump', 'title': 'Pump manual'}]), 200);
      });
      await tester.pumpWidget(MaterialApp(home: HqDataScreen(initialCategory: category, client: client)));
      await tester.enterText(find.byType(TextField).first, 'admin');
      await tester.enterText(find.byType(TextField).last, 'password');
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Delete from HQ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(deletions, 0);
      for (var attempt = 0; attempt < 2; attempt++) {
        await tester.tap(find.byTooltip('Delete from HQ'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Delete from HQ'));
        await tester.pumpAndSettle();
        if (attempt == 0) {
          expect(find.textContaining('Deletion failed (409)'), findsOneWidget);
          expect(find.byTooltip('Delete from HQ'), findsOneWidget);
        }
      }
      expect(deletions, 2);
      expect(find.text('No records found'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('active_equipment_id'), category == 'equipment' ? isNull : 'asset-1');
      expect(jsonDecode(prefs.getString('cached_equipment')!) as List,
          category == 'equipment' ? isEmpty : hasLength(1));
      expect(tester.takeException(), isNull);
    });
  }
}
