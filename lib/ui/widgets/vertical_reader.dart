import 'dart:io';
import 'package:flutter/material.dart';

/// Continuous vertical scrolling reader designed for Webtoons and Manhwa.
/// Uses [ListView.builder] with zero inter-image spacing and memory-safe caching.
class VerticalReader extends StatefulWidget {
  final List<String> pagePaths;
  final int initialPage;
  final ScrollController scrollController;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onTap;

  const VerticalReader({
    super.key,
    required this.pagePaths,
    required this.initialPage,
    required this.scrollController,
    required this.onPageChanged,
    required this.onTap,
  });

  @override
  State<VerticalReader> createState() => _VerticalReaderState();
}

class _VerticalReaderState extends State<VerticalReader> {
  final Map<int, double> _pageHeights = {};
  int _lastReportedPage = 0;
  bool _initialJumpDone = false;

  @override
  void initState() {
    super.initState();
    _lastReportedPage = widget.initialPage;
    widget.scrollController.addListener(_onScroll);

    if (widget.initialPage > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _attemptInitialJump();
      });
    }
  }

  void _attemptInitialJump() {
    if (_initialJumpDone || widget.initialPage <= 0) return;
    if (!widget.scrollController.hasClients) return;

    // Use average height or default if not yet measured
    final avgHeight = _pageHeights.isNotEmpty
        ? _pageHeights.values.reduce((a, b) => a + b) / _pageHeights.length
        : MediaQuery.of(context).size.height * 1.2;

    double targetOffset = 0;
    for (int i = 0; i < widget.initialPage; i++) {
      targetOffset += _pageHeights[i] ?? avgHeight;
    }

    final maxScroll = widget.scrollController.position.maxScrollExtent;
    final clampedOffset = targetOffset.clamp(0.0, maxScroll);
    widget.scrollController.jumpTo(clampedOffset);
    _initialJumpDone = true;
  }

  void _onScroll() {
    if (!widget.scrollController.hasClients) return;
    final offset = widget.scrollController.offset;

    if (_pageHeights.isEmpty) return;

    double accumulated = 0;
    int currentPage = 0;

    for (int i = 0; i < widget.pagePaths.length; i++) {
      final h = _pageHeights[i] ??
          (_pageHeights.values.reduce((a, b) => a + b) / _pageHeights.length);

      if (offset >= accumulated && offset < accumulated + h) {
        currentPage = i;
        break;
      }
      accumulated += h;
    }

    if (offset >= accumulated) {
      currentPage = widget.pagePaths.length - 1;
    }

    if (currentPage != _lastReportedPage) {
      _lastReportedPage = currentPage;
      widget.onPageChanged(currentPage);
    }
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: widget.onTap,
      child: ListView.builder(
        controller: widget.scrollController,
        padding: EdgeInsets.zero,
        physics: const BouncingScrollPhysics(),
        itemCount: widget.pagePaths.length,
        itemBuilder: (context, index) {
          final pagePath = widget.pagePaths[index];

          return _MeasuredImagePage(
            key: ValueKey(pagePath),
            pagePath: pagePath,
            index: index,
            onHeightMeasured: (height) {
              _pageHeights[index] = height;
              if (!_initialJumpDone && widget.initialPage > 0) {
                _attemptInitialJump();
              }
            },
            onTap: widget.onTap,
          );
        },
      ),
    );
  }
}

class _MeasuredImagePage extends StatelessWidget {
  final String pagePath;
  final int index;
  final ValueChanged<double> onHeightMeasured;
  final VoidCallback onTap;

  const _MeasuredImagePage({
    super.key,
    required this.pagePath,
    required this.index,
    required this.onHeightMeasured,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Image.file(
        File(pagePath),
        fit: BoxFit.fitWidth,
        width: double.infinity,
        gaplessPlayback: true,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          return child;
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: 300,
            color: Colors.black12,
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.broken_image, size: 40, color: Colors.grey),
                const SizedBox(height: 8),
                Text(
                  'Page ${index + 1} failed to load',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
