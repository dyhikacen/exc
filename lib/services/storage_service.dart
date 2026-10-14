import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/comic_book.dart';
import '../models/reading_mode.dart';

/// Offline-only storage service using SharedPreferences to record:
/// - File path
/// - Last read page
/// - Active reading mode
/// - Reading history
class StorageService {
  static const String _keyRecentComics = 'cbz_recent_comics';
  static const String _keyDefaultMode = 'cbz_default_reading_mode';

  static SharedPreferences? _prefs;

  static Future<SharedPreferences> get _instance async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Retrieves list of recent comics, sorted by last opened descending.
  static Future<List<ComicBook>> getRecentComics() async {
    final prefs = await _instance;
    final jsonString = prefs.getString(_keyRecentComics);
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> list = jsonDecode(jsonString) as List<dynamic>;
      final comics = list
          .map((item) => ComicBook.fromJson(item as Map<String, dynamic>))
          .toList();

      comics.sort((a, b) => b.lastOpened.compareTo(a.lastOpened));
      return comics;
    } catch (_) {
      return [];
    }
  }

  /// Saves or updates the reading progress for a comic.
  static Future<void> saveProgress({
    required String filePath,
    required String title,
    required int lastReadPage,
    required int totalPages,
    required ReadingMode readingMode,
    required int fileSizeBytes,
  }) async {
    final prefs = await _instance;
    final currentList = await getRecentComics();

    final updatedComic = ComicBook(
      filePath: filePath,
      title: title,
      lastReadPage: lastReadPage,
      totalPages: totalPages,
      readingMode: readingMode,
      lastOpened: DateTime.now(),
      fileSizeBytes: fileSizeBytes,
    );

    // Replace if exists, or prepend
    currentList.removeWhere((c) => c.filePath == filePath);
    currentList.insert(0, updatedComic);

    // Keep max 30 recent items to stay lightweight
    if (currentList.length > 30) {
      currentList.removeRange(30, currentList.length);
    }

    final encoded = jsonEncode(currentList.map((c) => c.toJson()).toList());
    await prefs.setString(_keyRecentComics, encoded);
  }

  /// Removes a single comic entry from recent history.
  static Future<void> removeComic(String filePath) async {
    final prefs = await _instance;
    final currentList = await getRecentComics();
    currentList.removeWhere((c) => c.filePath == filePath);
    final encoded = jsonEncode(currentList.map((c) => c.toJson()).toList());
    await prefs.setString(_keyRecentComics, encoded);
  }

  /// Clears all recent comics history.
  static Future<void> clearAllHistory() async {
    final prefs = await _instance;
    await prefs.remove(_keyRecentComics);
  }

  /// Gets the user's preferred default reading mode.
  static Future<ReadingMode> getDefaultReadingMode() async {
    final prefs = await _instance;
    final value = prefs.getString(_keyDefaultMode);
    return ReadingMode.fromString(value);
  }

  /// Saves the user's preferred default reading mode.
  static Future<void> setDefaultReadingMode(ReadingMode mode) async {
    final prefs = await _instance;
    await prefs.setString(_keyDefaultMode, mode.name);
  }
}
