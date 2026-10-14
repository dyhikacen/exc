import 'package:flutter_test/flutter_test.dart';
import 'package:excbz/utils/natural_sort.dart';

void main() {
  group('Natural Sort Comparator', () {
    test('sorts numeric page filenames properly', () {
      final input = ['10.jpg', '1.jpg', '2.jpg', '20.jpg', '3.jpg', '11.jpg'];
      input.sort(naturalCompare);
      expect(input, ['1.jpg', '2.jpg', '3.jpg', '10.jpg', '11.jpg', '20.jpg']);
    });

    test('handles leading zeros properly', () {
      final input = ['002.jpg', '001.jpg', '010.jpg', '003.jpg'];
      input.sort(naturalCompare);
      expect(input, ['001.jpg', '002.jpg', '003.jpg', '010.jpg']);
    });

    test('handles mixed chapter and page naming formats', () {
      final input = [
        'ch_1_p_10.png',
        'ch_1_p_2.png',
        'ch_1_p_1.png',
        'cover.jpg',
        'ch_2_p_1.png',
      ];
      input.sort(naturalCompare);
      expect(input, [
        'ch_1_p_1.png',
        'ch_1_p_2.png',
        'ch_1_p_10.png',
        'ch_2_p_1.png',
        'cover.jpg',
      ]);
    });
  });
}
