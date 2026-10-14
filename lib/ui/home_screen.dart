import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../models/comic_book.dart';
import '../models/reading_mode.dart';
import '../services/cbz_extractor.dart';
import '../services/storage_service.dart';
import '../utils/formatters.dart';
import 'reader_screen.dart';

/// Main screen displaying recent comics, cache management, and file picker.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<ComicBook> _recentComics = [];
  bool _isLoading = true;
  int _cacheSizeBytes = 0;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    final comics = await StorageService.getRecentComics();
    final cacheSize = await CbzExtractor.getCacheSizeBytes();

    if (mounted) {
      setState(() {
        _recentComics = comics;
        _cacheSizeBytes = cacheSize;
        _isLoading = false;
      });
    }
  }

  Future<void> _pickCbzFile() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['cbz', 'zip'],
      );

      if (files.isEmpty) return;

      final path = files.first.path;
      if (path == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not obtain file path')),
          );
        }
        return;
      }

      final file = File(path);
      if (!file.existsSync()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File does not exist')),
          );
        }
        return;
      }

      final title = p.basenameWithoutExtension(path);
      final size = file.lengthSync();

      // Check if already in recent history
      final existing = _recentComics.where((c) => c.filePath == path).firstOrNull;

      final comic = ComicBook(
        filePath: path,
        title: title,
        totalPages: existing?.totalPages ?? 0,
        lastReadPage: existing?.lastReadPage ?? 0,
        readingMode: existing?.readingMode ?? ReadingMode.horizontalLTR,
        lastOpened: DateTime.now(),
        fileSizeBytes: size,
      );

      _openReader(comic);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open file: $e')),
        );
      }
    }
  }

  void _openReader(ComicBook comic) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ReaderScreen(comic: comic)),
    );
    _refreshData();
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: const Text('Clear Temporary Cache?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will delete all extracted page caches from disk. Your reading progress and bookmarked files will remain saved.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await CbzExtractor.clearAllCaches();
      await _refreshData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cache cleared successfully')),
        );
      }
    }
  }

  Future<void> _deleteComicFromHistory(ComicBook comic) async {
    await StorageService.removeComic(comic.filePath);
    await _refreshData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF12121A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A26),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.auto_stories,
                color: Color(0xFF6C63FF),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'CBZ Reader',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 19,
                color: Colors.white,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_off, size: 14, color: Colors.greenAccent),
                  SizedBox(width: 4),
                  Text(
                    '100% Offline',
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: const Color(0xFF6C63FF),
        backgroundColor: const Color(0xFF1A1A26),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            // Top action banner / hero card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildOpenComicCard(),
                    const SizedBox(height: 12),
                    _buildCacheInfoCard(),
                  ],
                ),
              ),
            ),

            // Section Header: Recent Comics
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Recently Read',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                    if (_recentComics.isNotEmpty)
                      Text(
                        '${_recentComics.length} comic${_recentComics.length > 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Recent Comics List or Empty Placeholder
            if (_isLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
                ),
              )
            else if (_recentComics.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState(),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final comic = _recentComics[index];
                      return _buildRecentComicTile(comic);
                    },
                    childCount: _recentComics.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOpenComicCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF4834DF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _pickCbzFile,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.folder_open,
                    size: 32,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Open CBZ / ZIP File',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Select comic archive from device storage',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white70,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCacheInfoCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          const Icon(Icons.storage, size: 20, color: Colors.white54),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Disk Cache: ${Formatters.formatBytes(_cacheSizeBytes)}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (_cacheSizeBytes > 0)
            TextButton(
              onPressed: _clearCache,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Clear Cache',
                style: TextStyle(
                  color: Colors.amberAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRecentComicTile(ComicBook comic) {
    final hasFile = comic.fileExists;
    final progressFraction = comic.totalPages > 0
        ? ((comic.lastReadPage + 1) / comic.totalPages).clamp(0.0, 1.0)
        : 0.0;
    final percent = (progressFraction * 100).toInt();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasFile ? Colors.white10 : Colors.redAccent.withValues(alpha: 0.3),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            if (!hasFile) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('File not found. It may have been moved or deleted.'),
                ),
              );
              return;
            }
            _openReader(comic);
          },
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon Box
                    Container(
                      width: 44,
                      height: 52,
                      decoration: BoxDecoration(
                        color: hasFile
                            ? const Color(0xFF2B2B3E)
                            : Colors.red.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        hasFile ? Icons.menu_book : Icons.file_present_outlined,
                        color: hasFile ? const Color(0xFF6C63FF) : Colors.redAccent,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            comic.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            hasFile
                                ? '${comic.totalPages > 0 ? "Page ${comic.lastReadPage + 1} of ${comic.totalPages} ($percent%)" : "Not yet opened"} • ${comic.readingMode.label}'
                                : 'File missing from storage',
                            style: TextStyle(
                              color: hasFile
                                  ? Colors.white60
                                  : Colors.redAccent.withValues(alpha: 0.8),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Opened ${Formatters.formatRelativeTime(comic.lastOpened)}${comic.fileSizeBytes > 0 ? " • ${Formatters.formatBytes(comic.fileSizeBytes)}" : ""}',
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Options menu
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert,
                          color: Colors.white54, size: 20),
                      color: const Color(0xFF2B2B3E),
                      onSelected: (val) {
                        if (val == 'delete') {
                          _deleteComicFromHistory(comic);
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline,
                                  color: Colors.redAccent, size: 18),
                              SizedBox(width: 8),
                              Text('Remove from list',
                                  style: TextStyle(color: Colors.redAccent)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Progress Bar
                if (comic.totalPages > 0) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progressFraction,
                      minHeight: 4,
                      backgroundColor: Colors.white10,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF6C63FF),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.book_outlined,
                size: 64,
                color: Colors.white.withValues(alpha: 0.3),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Comics Read Yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap "Open CBZ / ZIP File" above to pick a comic from your device and start reading.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
