import 'package:digitization_platform/features/follow_up/domain/entities/new_target_details.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a code and a description are both needed, ignoring spaces', () {
    const blank = NewTargetDetails(code: '  ', description: ' \n');

    expect(blank.codeError, isNotNull);
    expect(blank.descriptionError, isNotNull);
    expect(blank.isValid, isFalse);
  });

  test('what the studio allows is valid, and the values are trimmed', () {
    const details = NewTargetDetails(code: ' W-12-A ', description: ' A procession. ');

    expect(details.isValid, isTrue);
    expect(details.trimmedCode, 'W-12-A');
    expect(details.trimmedDescription, 'A procession.');
  });

  test("past the studio's limits it says so", () {
    final long = NewTargetDetails(
      code: 'x' * (NewTargetDetails.maxCodeLength + 1),
      description: 'y' * (NewTargetDetails.maxDescriptionLength + 1),
    );

    expect(long.codeError, contains('${NewTargetDetails.maxCodeLength}'));
    expect(long.descriptionError, contains('${NewTargetDetails.maxDescriptionLength}'));
  });

  test('codes are compared as the dashboard compares them', () {
    expect(NewTargetDetails.normalized(' W-12-a '), NewTargetDetails.normalized('w-12-A'));
  });
}
