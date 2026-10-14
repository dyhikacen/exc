import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:excbz/main.dart';
import 'package:excbz/services/cbz_extractor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory mockTempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    mockTempDir = await Directory.systemTemp.createTemp('widget_test_');
    CbzExtractor.customCacheBaseDir = mockTempDir;
  });

  tearDown(() async {
    CbzExtractor.customCacheBaseDir = null;
    if (mockTempDir.existsSync()) {
      await mockTempDir.delete(recursive: true);
    }
  });

  testWidgets('App smoke test loads HomeScreen', (WidgetTester tester) async {
    await tester.pumpWidget(const CbzReaderApp());
    // Pump frames to allow async refreshData to complete
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('CBZ Reader'), findsOneWidget);
    expect(find.text('Open CBZ / ZIP File'), findsOneWidget);
    expect(find.text('100% Offline'), findsOneWidget);
  });
}
