import 'package:flutter/material.dart';
import '../../models/reading_mode.dart';
import 'zoomable_page.dart';

/// Horizontal comic reader implementing [PageView.builder] with LTR/RTL support.
class HorizontalReader extends StatefulWidget {
  final List<String> pagePaths;
  final int initialPage;
  final ReadingMode readingMode;
  final PageController pageController;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onTap;

  const HorizontalReader({
    super.key,
    required this.pagePaths,
    required this.initialPage,
    required this.readingMode,
    required this.pageController,
    required this.onPageChanged,
    required this.onTap,
  });

  @override
  State<HorizontalReader> createState() => _HorizontalReaderState();
}

class _HorizontalReaderState extends State<HorizontalReader> {
  bool _isCurrentPageZoomed = false;

  @override
  Widget build(BuildContext context) {
    final isRTL = widget.readingMode == ReadingMode.horizontalRTL;

    return PageView.builder(
      controller: widget.pageController,
      reverse: isRTL,
      physics: _isCurrentPageZoomed
          ? const NeverScrollableScrollPhysics()
          : const BouncingScrollPhysics(),
      itemCount: widget.pagePaths.length,
      onPageChanged: (pageIndex) {
        setState(() {
          _isCurrentPageZoomed = false;
        });
        widget.onPageChanged(pageIndex);
      },
      itemBuilder: (context, index) {
        return ZoomablePage(
          imagePath: widget.pagePaths[index],
          onTap: widget.onTap,
          onZoomChanged: (isZoomed) {
            setState(() {
              _isCurrentPageZoomed = isZoomed;
            });
          },
        );
      },
    );
  }
}
