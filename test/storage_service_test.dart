import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:excbz/services/storage_service.dart';
import 'package:excbz/models/reading_mode.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('StorageService saves and retrieves comic progress', () async {
    expect(await StorageService.getRecentComics(), isEmpty);

    await StorageService.saveProgress(
      filePath: '/path/to/manga.cbz',
      title: 'Manga Test',
      lastReadPage: 5,
      totalPages: 20,
      readingMode: ReadingMode.vertical,
      fileSizeBytes: 10240,
    );

    final recent = await StorageService.getRecentComics();
    expect(recent.length, 1);
    expect(recent[0].title, 'Manga Test');
    expect(recent[0].lastReadPage, 5);
    expect(recent[0].readingMode, ReadingMode.vertical);

    // Update progress
    await StorageService.saveProgress(
      filePath: '/path/to/manga.cbz',
      title: 'Manga Test',
      lastReadPage: 12,
      totalPages: 20,
      readingMode: ReadingMode.horizontalRTL,
      fileSizeBytes: 10240,
    );

    final updated = await StorageService.getRecentComics();
    expect(updated.length, 1);
    expect(updated[0].lastReadPage, 12);
    expect(updated[0].readingMode, ReadingMode.horizontalRTL);

    // Remove comic
    await StorageService.removeComic('/path/to/manga.cbz');
    expect(await StorageService.getRecentComics(), isEmpty);
  });
}
