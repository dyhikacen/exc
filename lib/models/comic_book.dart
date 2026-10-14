import 'dart:io';
import 'reading_mode.dart';

/// Represents a comic file and its read state.
class ComicBook {
  final String filePath;
  final String title;
  final String? extractedDirPath;
  final List<String> pagePaths;
  final int totalPages;
  final int lastReadPage;
  final ReadingMode readingMode;
  final DateTime lastOpened;
  final int fileSizeBytes;

  const ComicBook({
    required this.filePath,
    required this.title,
    this.extractedDirPath,
    this.pagePaths = const [],
    required this.totalPages,
    this.lastReadPage = 0,
    this.readingMode = ReadingMode.horizontalLTR,
    required this.lastOpened,
    this.fileSizeBytes = 0,
  });

  /// Check if the original comic file still exists on disk
  bool get fileExists => File(filePath).existsSync();

  ComicBook copyWith({
    String? filePath,
    String? title,
    String? extractedDirPath,
    List<String>? pagePaths,
    int? totalPages,
    int? lastReadPage,
    ReadingMode? readingMode,
    DateTime? lastOpened,
    int? fileSizeBytes,
  }) {
    return ComicBook(
      filePath: filePath ?? this.filePath,
      title: title ?? this.title,
      extractedDirPath: extractedDirPath ?? this.extractedDirPath,
      pagePaths: pagePaths ?? this.pagePaths,
      totalPages: totalPages ?? this.totalPages,
      lastReadPage: lastReadPage ?? this.lastReadPage,
      readingMode: readingMode ?? this.readingMode,
      lastOpened: lastOpened ?? this.lastOpened,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'filePath': filePath,
      'title': title,
      'totalPages': totalPages,
      'lastReadPage': lastReadPage,
      'readingMode': readingMode.name,
      'lastOpened': lastOpened.toIso8601String(),
      'fileSizeBytes': fileSizeBytes,
    };
  }

  factory ComicBook.fromJson(Map<String, dynamic> json) {
    return ComicBook(
      filePath: json['filePath'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled Comic',
      totalPages: json['totalPages'] as int? ?? 0,
      lastReadPage: json['lastReadPage'] as int? ?? 0,
      readingMode: ReadingMode.fromString(json['readingMode'] as String?),
      lastOpened: json['lastOpened'] != null
          ? DateTime.tryParse(json['lastOpened'] as String) ?? DateTime.now()
          : DateTime.now(),
      fileSizeBytes: json['fileSizeBytes'] as int? ?? 0,
    );
  }
}
