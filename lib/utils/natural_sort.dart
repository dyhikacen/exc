/// Pure Dart implementation of Natural Sort (Alphanumeric sorting).
///
/// Ensures filenames like '1.jpg', '2.jpg', ..., '10.jpg' are sorted in natural
/// human order rather than lexicographical string order ('1.jpg', '10.jpg', '2.jpg').
int naturalCompare(String a, String b) {
  final regExp = RegExp(r'(\d+)|(\D+)');
  final matchesA = regExp.allMatches(a).toList();
  final matchesB = regExp.allMatches(b).toList();

  final minLength =
      matchesA.length < matchesB.length ? matchesA.length : matchesB.length;

  for (int i = 0; i < minLength; i++) {
    final strA = matchesA[i].group(0)!;
    final strB = matchesB[i].group(0)!;

    final isNumA = int.tryParse(strA) != null;
    final isNumB = int.tryParse(strB) != null;

    if (isNumA && isNumB) {
      final numA = BigInt.tryParse(strA);
      final numB = BigInt.tryParse(strB);

      if (numA != null && numB != null) {
        final cmp = numA.compareTo(numB);
        if (cmp != 0) return cmp;

        // If numeric values are identical (e.g., '01' vs '1'),
        // compare lengths to ensure deterministic order.
        final lenCmp = strA.length.compareTo(strB.length);
        if (lenCmp != 0) return lenCmp;
      }
    }

    final cmp = strA.toLowerCase().compareTo(strB.toLowerCase());
    if (cmp != 0) return cmp;
  }

  return matchesA.length.compareTo(matchesB.length);
}
