import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:excbz/services/cbz_extractor.dart';

void main() {
  late Directory mockTempDir;

  setUp(() async {
    mockTempDir = await Directory.systemTemp.createTemp('cbz_extractor_test_');
    CbzExtractor.customCacheBaseDir = mockTempDir;
  });

  tearDown(() async {
    CbzExtractor.customCacheBaseDir = null;
    if (mockTempDir.existsSync()) {
      await mockTempDir.delete(recursive: true);
    }
  });

  test('Extracts CBZ in background isolate and sorts naturally', () async {
    final zipPath = '${mockTempDir.path}/manga_test.cbz';
    final encoder = ZipFileEncoder();
    encoder.create(zipPath);

    // Create unordered images
    final file10 = File('${mockTempDir.path}/10.png')..writeAsStringSync('page 10');
    final file1 = File('${mockTempDir.path}/1.jpg')..writeAsStringSync('page 1');
    final file2 = File('${mockTempDir.path}/2.jpeg')..writeAsStringSync('page 2');
    final nonImg = File('${mockTempDir.path}/info.txt')..writeAsStringSync('not an image');

    await encoder.addFile(file10);
    await encoder.addFile(file1);
    await encoder.addFile(file2);
    await encoder.addFile(nonImg);
    await encoder.close();

    // Run extraction
    final pages = await CbzExtractor.extractComic(zipPath);

    expect(pages.length, 3);
    expect(pages[0].endsWith('1.jpg'), isTrue);
    expect(pages[1].endsWith('2.jpeg'), isTrue);
    expect(pages[2].endsWith('10.png'), isTrue);

    // Verify disk content
    for (final page in pages) {
      expect(File(page).existsSync(), isTrue);
    }

    // Verify cache size calculation
    final cacheSize = await CbzExtractor.getCacheSizeBytes();
    expect(cacheSize, greaterThan(0));

    // Verify clear cache
    await CbzExtractor.clearAllCaches();
    final clearedSize = await CbzExtractor.getCacheSizeBytes();
    expect(clearedSize, 0);
  });
}
