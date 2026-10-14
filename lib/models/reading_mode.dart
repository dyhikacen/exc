/// Reading mode options for the comic reader.
enum ReadingMode {
  horizontalLTR,
  horizontalRTL,
  vertical;

  String get label {
    switch (this) {
      case ReadingMode.horizontalLTR:
        return 'Horizontal (LTR)';
      case ReadingMode.horizontalRTL:
        return 'Manga (RTL)';
      case ReadingMode.vertical:
        return 'Webtoon (Vertical)';
    }
  }

  bool get isHorizontal =>
      this == ReadingMode.horizontalLTR || this == ReadingMode.horizontalRTL;

  static ReadingMode fromString(String? value) {
    if (value == null) return ReadingMode.horizontalLTR;
    for (final mode in ReadingMode.values) {
      if (mode.name == value) return mode;
    }
    return ReadingMode.horizontalLTR;
  }
}
