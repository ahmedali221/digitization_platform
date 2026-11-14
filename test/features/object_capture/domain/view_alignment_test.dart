import 'package:digitization_platform/features/object_capture/domain/entities/scan_plan.dart';
import 'package:digitization_platform/features/object_capture/domain/services/view_alignment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Photographs of the level ring, as the phone knows them (the middle of
  /// their slice) and as a server counting from [serverZero] degrees, the
  /// same way round or the other, would report them.
  List<({double phone, double server})> views({
    required double serverZero,
    bool sameWayRound = true,
    Iterable<int> sectors = const [0, 3, 6, 9, 12, 15, 18, 21],
  }) {
    return [
      for (final sector in sectors)
        (
          phone: ScanPlan.centreOf(ScanCell(0, sector)),
          server: ScanPlan.normalise(
            (sameWayRound ? 1 : -1) *
                (ScanPlan.centreOf(ScanCell(0, sector)) - serverZero),
          ),
        ),
    ];
  }

  test('the server\'s angles are turned into the phone\'s', () {
    final alignment = ViewAlignment.fit(views(serverZero: 97.5))!;

    expect(alignment.toPhone(0), closeTo(97.5, 0.01));
    expect(alignment.toPhone(300), closeTo(37.5, 0.01));
  });

  test('a server counting the other way round is followed too', () {
    final alignment = ViewAlignment.fit(
      views(serverZero: 40, sameWayRound: false),
    )!;

    expect(alignment.toPhone(0), closeTo(40, 0.01));
    expect(alignment.toPhone(30), closeTo(10, 0.01));
  });

  test('a few photographs on one side are enough to line up by', () {
    final alignment = ViewAlignment.fit(
      views(serverZero: 200, sectors: const [4, 5, 6, 7]),
    )!;

    expect(alignment.toPhone(10), closeTo(210, 0.01));
  });

  test('photographs that disagree line nothing up', () {
    final scattered = [
      for (final (index, view) in views(serverZero: 0).indexed)
        (phone: view.phone, server: view.server + index * 80.0),
    ];

    expect(ViewAlignment.fit(scattered), isNull);
    expect(
      ViewAlignment.fit(views(serverZero: 0, sectors: const [1, 2])),
      isNull,
      reason: 'two photographs could agree by chance',
    );
  });

  test('a missing side is faced from its own height and from above', () {
    final alignment = ViewAlignment.fit(views(serverZero: 0))!;

    expect(alignment.cellsFacing(azimuth: 100, elevation: 5), {
      const ScanCell(0, 6),
      const ScanCell(1, 4),
    });
    expect(
      alignment.cellsFacing(azimuth: 100, elevation: 60),
      {const ScanCell(1, 4)},
      reason: 'nothing is above the top ring',
    );
  });
}
