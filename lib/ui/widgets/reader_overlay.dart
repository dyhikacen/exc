import 'package:flutter/material.dart';
import '../../models/reading_mode.dart';

/// Top and bottom navigation overlays for the comic reader.
class ReaderOverlay extends StatelessWidget {
  final bool isVisible;
  final String title;
  final int currentPage;
  final int totalPages;
  final ReadingMode readingMode;
  final VoidCallback onBack;
  final ValueChanged<ReadingMode> onModeChanged;
  final ValueChanged<int> onPageSelected;
  final VoidCallback onNextPage;
  final VoidCallback onPreviousPage;

  const ReaderOverlay({
    super.key,
    required this.isVisible,
    required this.title,
    required this.currentPage,
    required this.totalPages,
    required this.readingMode,
    required this.onBack,
    required this.onModeChanged,
    required this.onPageSelected,
    required this.onNextPage,
    required this.onPreviousPage,
  });

  void _showJumpDialog(BuildContext context) {
    final controller = TextEditingController(text: '${currentPage + 1}');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: const Text('Go to Page', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: '1 - $totalPages',
            hintStyle: const TextStyle(color: Colors.white38),
            enabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Colors.white24),
              borderRadius: BorderRadius.circular(8),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Color(0xFF6C63FF)),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final pageNum = int.tryParse(controller.text);
              if (pageNum != null && pageNum >= 1 && pageNum <= totalPages) {
                Navigator.pop(ctx);
                onPageSelected(pageNum - 1);
              }
            },
            child: const Text('Jump'),
          ),
        ],
      ),
    );
  }

  void _showModePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  'Reading Mode',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(color: Colors.white12),
              ListTile(
                leading: const Icon(Icons.swap_horiz, color: Colors.blueAccent),
                title: const Text('Horizontal (LTR)',
                    style: TextStyle(color: Colors.white)),
                subtitle: const Text('Standard left-to-right swipe',
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
                trailing: readingMode == ReadingMode.horizontalLTR
                    ? const Icon(Icons.check_circle, color: Color(0xFF6C63FF))
                    : null,
                onTap: () {
                  Navigator.pop(ctx);
                  onModeChanged(ReadingMode.horizontalLTR);
                },
              ),
              ListTile(
                leading: const Icon(Icons.menu_book, color: Colors.purpleAccent),
                title: const Text('Manga (RTL)',
                    style: TextStyle(color: Colors.white)),
                subtitle: const Text('Right-to-left swipe for Japanese manga',
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
                trailing: readingMode == ReadingMode.horizontalRTL
                    ? const Icon(Icons.check_circle, color: Color(0xFF6C63FF))
                    : null,
                onTap: () {
                  Navigator.pop(ctx);
                  onModeChanged(ReadingMode.horizontalRTL);
                },
              ),
              ListTile(
                leading: const Icon(Icons.swap_vert, color: Colors.amberAccent),
                title: const Text('Webtoon / Manhwa (Vertical)',
                    style: TextStyle(color: Colors.white)),
                subtitle: const Text('Continuous seamless vertical scroll',
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
                trailing: readingMode == ReadingMode.vertical
                    ? const Icon(Icons.check_circle, color: Color(0xFF6C63FF))
                    : null,
                onTap: () {
                  Navigator.pop(ctx);
                  onModeChanged(ReadingMode.vertical);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progressPercent = totalPages > 0
        ? (((currentPage + 1) / totalPages) * 100).toInt()
        : 0;

    return IgnorePointer(
      ignoring: !isVisible,
      child: AnimatedOpacity(
        opacity: isVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: Stack(
          children: [
            // Top App Bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black87, Colors.transparent],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 4,
                  bottom: 16,
                  left: 8,
                  right: 8,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: onBack,
                      tooltip: 'Back',
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        readingMode == ReadingMode.vertical
                            ? Icons.swap_vert
                            : (readingMode == ReadingMode.horizontalRTL
                                ? Icons.menu_book
                                : Icons.swap_horiz),
                        color: Colors.white,
                      ),
                      onPressed: () => _showModePicker(context),
                      tooltip: 'Change Reading Mode (${readingMode.label})',
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Navigation & Page Slider
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black87],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom + 8,
                  top: 16,
                  left: 16,
                  right: 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Info Row: Page counter + Jump button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton.icon(
                          onPressed: () => _showJumpDialog(context),
                          icon: const Icon(Icons.format_list_numbered,
                              size: 18, color: Colors.white70),
                          label: Text(
                            'Page ${currentPage + 1} / $totalPages ($progressPercent%)',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white12,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            readingMode.label,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Slider Row
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.skip_previous,
                              color: Colors.white70),
                          onPressed: currentPage > 0 ? onPreviousPage : null,
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: const Color(0xFF6C63FF),
                              inactiveTrackColor: Colors.white24,
                              thumbColor: const Color(0xFF6C63FF),
                              overlayColor: const Color(0x336C63FF),
                              thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 7),
                              trackHeight: 3,
                            ),
                            child: Slider(
                              value: totalPages > 1
                                  ? currentPage.clamp(0, totalPages - 1).toDouble()
                                  : 0.0,
                              min: 0,
                              max: totalPages > 1
                                  ? (totalPages - 1).toDouble()
                                  : 1.0,
                              divisions:
                                  totalPages > 1 ? (totalPages - 1) : 1,
                              onChanged: (val) {
                                onPageSelected(val.toInt());
                              },
                            ),
                          ),
                        ),
                        IconButton(
                          icon:
                              const Icon(Icons.skip_next, color: Colors.white70),
                          onPressed: currentPage < totalPages - 1
                              ? onNextPage
                              : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
