import 'dart:io';
import 'dart:isolate';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../utils/natural_sort.dart';

/// Parameters passed to the background Isolate for decoding and extraction.
class _ExtractionParams {
  final String cbzFilePath;
  final String targetDirectoryPath;

  const _ExtractionParams({
    required this.cbzFilePath,
    required this.targetDirectoryPath,
  });
}

/// Service responsible for extracting CBZ/ZIP files in a background Isolate
/// directly to disk storage, strictly adhering to anti-OOM and disk-cache rules.
class CbzExtractor {
  static const Set<String> _supportedImageExtensions = {
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.gif',
    '.bmp',
  };

  static Directory? customCacheBaseDir;

  /// Returns the root directory used for comic disk caches.
  static Future<Directory> getCacheBaseDirectory() async {
    if (customCacheBaseDir != null) {
      final cacheDir = Directory(p.join(customCacheBaseDir!.path, 'cbz_cache'));
      if (!cacheDir.existsSync()) {
        await cacheDir.create(recursive: true);
      }
      return cacheDir;
    }
    final tempDir = await getTemporaryDirectory();
    final cacheDir = Directory(p.join(tempDir.path, 'cbz_cache'));
    if (!cacheDir.existsSync()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  /// Generates a deterministic directory name for a specific comic file.
  static String getComicCacheFolderName(String cbzFilePath) {
    final baseName = p.basenameWithoutExtension(cbzFilePath)
        .replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    final hash = cbzFilePath.hashCode.toUnsigned(32).toRadixString(16);
    return '${baseName}_$hash';
  }

  /// Extracts the comic file in a background Isolate and returns a naturally
  /// sorted list of local image file paths.
  ///
  /// If the comic was previously extracted and the cache is valid, it reuses
  /// the extracted pages instantly without re-extracting.
  static Future<List<String>> extractComic(
    String cbzFilePath, {
    bool forceReextract = false,
  }) async {
    final baseCacheDir = await getCacheBaseDirectory();
    final comicFolderName = getComicCacheFolderName(cbzFilePath);
    final targetDir = Directory(p.join(baseCacheDir.path, comicFolderName));
    final completeMarker = File(p.join(targetDir.path, '.complete'));

    // Check if valid cache already exists
    if (!forceReextract && targetDir.existsSync() && completeMarker.existsSync()) {
      final existingPages = _getSortedImagesInDirectory(targetDir.path);
      if (existingPages.isNotEmpty) {
        return existingPages;
      }
    }

    // Clean target directory if re-extracting
    if (targetDir.existsSync()) {
      await targetDir.delete(recursive: true);
    }
    await targetDir.create(recursive: true);

    // Run extraction entirely in a background Isolate
    final params = _ExtractionParams(
      cbzFilePath: cbzFilePath,
      targetDirectoryPath: targetDir.path,
    );

    final extractedPages = await Isolate.run(() => _isolateExtract(params));

    return extractedPages;
  }

  /// Background Isolate worker function.
  ///
  /// CRITICAL ANTI-OOM DIRECTIVES:
  /// - Uses [InputFileStream] to read the archive in chunks from disk.
  /// - Uses [OutputFileStream] to stream extracted uncompressed bytes directly to disk.
  /// - Never retains full image bytes in RAM.
  static Future<List<String>> _isolateExtract(_ExtractionParams params) async {
    final inputFile = File(params.cbzFilePath);
    if (!inputFile.existsSync()) {
      throw FileSystemException('Comic file not found', params.cbzFilePath);
    }

    final inputStream = InputFileStream(params.cbzFilePath);
    final archive = ZipDecoder().decodeStream(inputStream);

    final targetDir = Directory(params.targetDirectoryPath);
    if (!targetDir.existsSync()) {
      targetDir.createSync(recursive: true);
    }

    final extractedPaths = <String>[];

    try {
      for (final file in archive.files) {
        if (!file.isFile) continue;

        // Skip macOS metadata and hidden files
        final normalizedName = file.name.replaceAll('\\', '/');
        if (normalizedName.startsWith('__MACOSX/') ||
            p.basename(normalizedName).startsWith('.')) {
          continue;
        }

        final ext = p.extension(normalizedName).toLowerCase();
        if (!_supportedImageExtensions.contains(ext)) {
          continue;
        }

        // Prevent directory traversal attacks and ensure safe relative paths
        final safeRelativePath = normalizedName.replaceAll(RegExp(r'\.\.[/\\]'), '');
        final outFilePath = p.join(params.targetDirectoryPath, safeRelativePath);
        final outFile = File(outFilePath);

        outFile.createSync(recursive: true);

        // Stream uncompressed content directly to disk
        final outStream = OutputFileStream(outFile.path);
        file.writeContent(outStream);
        await outStream.close();

        extractedPaths.add(outFile.path);
      }
    } finally {
      await inputStream.close();
    }

    if (extractedPaths.isEmpty) {
      throw const FormatException('No valid image pages found inside this CBZ file');
    }

    // Natural sort: 1.jpg, 2.jpg, ..., 10.jpg
    extractedPaths.sort((a, b) => naturalCompare(p.basename(a), p.basename(b)));

    // Write completion marker file
    final completeMarker = File(p.join(params.targetDirectoryPath, '.complete'));
    completeMarker.writeAsStringSync(DateTime.now().toIso8601String());

    return extractedPaths;
  }

  /// Scans a directory and returns all images sorted with natural sort.
  static List<String> _getSortedImagesInDirectory(String dirPath) {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) return [];

    final imagePaths = <String>[];
    final entities = dir.listSync(recursive: true);

    for (final entity in entities) {
      if (entity is File) {
        final ext = p.extension(entity.path).toLowerCase();
        if (_supportedImageExtensions.contains(ext) &&
            !p.basename(entity.path).startsWith('.')) {
          imagePaths.add(entity.path);
        }
      }
    }

    imagePaths.sort((a, b) => naturalCompare(p.basename(a), p.basename(b)));
    return imagePaths;
  }

  /// Cleans up cache of all comics EXCEPT the currently active comic.
  /// Call this when switching comics or closing to conserve disk space.
  static Future<void> cleanOtherComicCaches(String currentCbzFilePath) async {
    try {
      final baseCacheDir = await getCacheBaseDirectory();
      final activeFolder = getComicCacheFolderName(currentCbzFilePath);

      if (!baseCacheDir.existsSync()) return;

      final entities = baseCacheDir.listSync();
      for (final entity in entities) {
        if (entity is Directory && p.basename(entity.path) != activeFolder) {
          try {
            await entity.delete(recursive: true);
          } catch (_) {
            // Ignore in-use locks
          }
        }
      }
    } catch (_) {
      // Ignore background cleanup errors
    }
  }

  /// Cleans up all comic caches completely.
  static Future<void> clearAllCaches() async {
    try {
      final baseCacheDir = await getCacheBaseDirectory();
      if (baseCacheDir.existsSync()) {
        await baseCacheDir.delete(recursive: true);
        await baseCacheDir.create(recursive: true);
      }
    } catch (_) {
      // Ignore errors
    }
  }

  /// Calculates total bytes used by the CBZ temporary cache.
  static Future<int> getCacheSizeBytes() async {
    try {
      final baseCacheDir = await getCacheBaseDirectory();
      if (!baseCacheDir.existsSync()) return 0;

      int totalBytes = 0;
      final entities = baseCacheDir.listSync(recursive: true);
      for (final entity in entities) {
        if (entity is File) {
          totalBytes += await entity.length();
        }
      }
      return totalBytes;
    } catch (_) {
      return 0;
    }
  }
}
