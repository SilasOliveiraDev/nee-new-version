import 'package:flutter_test/flutter_test.dart';
import 'package:nee/domain/review_criteria.dart';

void main() {
  test('review is incomplete until every criterion has stars', () {
    expect(ReviewScores.empty.isComplete, isFalse);
    final partial = ReviewScores.empty.withValue('quality', 5);
    expect(partial.isComplete, isFalse);
  });

  test('overall is the mean of the five surgical scores', () {
    const scores = ReviewScores(
      quality: 5,
      conduct: 4,
      ethics: 5,
      courtesy: 4,
      punctuality: 3,
    );
    expect(scores.isComplete, isTrue);
    expect(scores.overall, closeTo(4.2, 0.01));
  });
}
