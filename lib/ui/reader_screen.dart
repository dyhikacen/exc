import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/comic_book.dart';
import '../models/reading_mode.dart';
import '../services/cbz_extractor.dart';
import '../services/storage_service.dart';
import 'widgets/horizontal_reader.dart';
import 'widgets/reader_overlay.dart';
import 'widgets/vertical_reader.dart';

/// Immersive Comic Reader Screen.
/// Supports both Horizontal (LTR/RTL) and Vertical (Webtoon) reading modes.
class ReaderScreen extends StatefulWidget {
  final ComicBook comic;

  const ReaderScreen({
    super.key,
    required this.comic,
  });

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<String> _pagePaths = [];

  late int _currentPage;
  late ReadingMode _readingMode;

  PageController? _pageController;
  ScrollController? _scrollController;

  bool _showOverlay = false;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.comic.lastReadPage;
    _readingMode = widget.comic.readingMode;

    // Enable sticky immersive mode initially
    _setImmersiveMode(true);

    _loadComicPages();
  }

  void _setImmersiveMode(bool immersive) {
    if (immersive) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  Future<void> _loadComicPages() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Clean caches of other comics to preserve disk space
      await CbzExtractor.cleanOtherComicCaches(widget.comic.filePath);

      // Extract in background Isolate
      final pages = await CbzExtractor.extractComic(widget.comic.filePath);

      if (!mounted) return;

      if (pages.isEmpty) {
        setState(() {
          _errorMessage = 'No image pages found in this comic.';
          _isLoading = false;
        });
        return;
      }

      // Clamp initial page to valid bounds
      final validPage = _currentPage.clamp(0, pages.length - 1);

      setState(() {
        _pagePaths = pages;
        _currentPage = validPage;
        _pageController = PageController(initialPage: validPage);
        _scrollController = ScrollController();
        _isLoading = false;
      });

      _saveCurrentProgress();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to extract comic: $e';
        _isLoading = false;
      });
    }
  }

  void _toggleOverlay() {
    setState(() {
      _showOverlay = !_showOverlay;
    });
    // If overlay is hidden, ensure sticky immersive mode is refreshed
    if (!_showOverlay) {
      _setImmersiveMode(true);
    }
  }

  void _onPageChanged(int pageIndex) {
    if (_currentPage == pageIndex) return;

    setState(() {
      _currentPage = pageIndex;
    });

    _saveCurrentProgress();
  }

  void _jumpToPage(int targetPage) {
    if (targetPage < 0 || targetPage >= _pagePaths.length) return;

    setState(() {
      _currentPage = targetPage;
    });

    if (_readingMode.isHorizontal) {
      if (_pageController != null && _pageController!.hasClients) {
        _pageController!.jumpToPage(targetPage);
      }
    } else {
      // In vertical mode, scroll to estimated position
      if (_scrollController != null && _scrollController!.hasClients) {
        final maxScroll = _scrollController!.position.maxScrollExtent;
        final targetOffset = (targetPage / _pagePaths.length) * maxScroll;
        _scrollController!.jumpTo(targetOffset);
      }
    }

    _saveCurrentProgress();
  }

  void _changeReadingMode(ReadingMode newMode) {
    if (_readingMode == newMode) return;

    setState(() {
      _readingMode = newMode;
      // Recreate controllers for the new mode with current page preserved
      _pageController?.dispose();
      _scrollController?.dispose();

      _pageController = PageController(initialPage: _currentPage);
      _scrollController = ScrollController();
    });

    _saveCurrentProgress();
  }

  void _saveCurrentProgress() {
    StorageService.saveProgress(
      filePath: widget.comic.filePath,
      title: widget.comic.title,
      lastReadPage: _currentPage,
      totalPages: _pagePaths.isNotEmpty ? _pagePaths.length : widget.comic.totalPages,
      readingMode: _readingMode,
      fileSizeBytes: widget.comic.fileSizeBytes > 0
          ? widget.comic.fileSizeBytes
          : (File(widget.comic.filePath).existsSync()
              ? File(widget.comic.filePath).lengthSync()
              : 0),
    );
  }

  @override
  void dispose() {
    // Restore system UI on exit
    _setImmersiveMode(false);
    _pageController?.dispose();
    _scrollController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Content Area
          Positioned.fill(
            child: _buildBody(),
          ),

          // Floating Controls Overlay
          if (!_isLoading && _errorMessage == null)
            ReaderOverlay(
              isVisible: _showOverlay,
              title: widget.comic.title,
              currentPage: _currentPage,
              totalPages: _pagePaths.length,
              readingMode: _readingMode,
              onBack: () => Navigator.pop(context),
              onModeChanged: _changeReadingMode,
              onPageSelected: _jumpToPage,
              onNextPage: () => _jumpToPage(_currentPage + 1),
              onPreviousPage: () => _jumpToPage(_currentPage - 1),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              color: Color(0xFF6C63FF),
              strokeWidth: 3,
            ),
            const SizedBox(height: 20),
            const Text(
              'Unpacking comic pages...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Running in background isolate',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    if (_readingMode.isHorizontal) {
      return HorizontalReader(
        pagePaths: _pagePaths,
        initialPage: _currentPage,
        readingMode: _readingMode,
        pageController: _pageController!,
        onPageChanged: _onPageChanged,
        onTap: _toggleOverlay,
      );
    } else {
      return VerticalReader(
        pagePaths: _pagePaths,
        initialPage: _currentPage,
        scrollController: _scrollController!,
        onPageChanged: _onPageChanged,
        onTap: _toggleOverlay,
      );
    }
  }
}
