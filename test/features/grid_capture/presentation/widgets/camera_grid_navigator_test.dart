import 'package:digitization_platform/core/domain/entities/wall.dart';
import 'package:digitization_platform/features/grid_capture/presentation/widgets/camera_grid_navigator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const grid = GridState(
    rows: 2,
    cols: 2,
    cells: [
      GridCell(shotPaths: ['r1c1.jpg']),
      GridCell(),
      GridCell(shotPaths: ['r2c1-1.jpg', 'r2c1-2.jpg']),
      GridCell(),
    ],
  );

  testWidgets('shows every grid cell and its capture progress', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CameraGridNavigator(
            grid: grid,
            activeCellIndex: 0,
            onCellSelected: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Grid cells'), findsOneWidget);
    expect(find.text('2/4 covered'), findsOneWidget);
    expect(find.text('R1C1'), findsOneWidget);
    expect(find.text('R1C2'), findsOneWidget);
    expect(find.text('R2C1'), findsOneWidget);
    expect(find.text('R2C2'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('selects another cell without leaving the camera', (
    tester,
  ) async {
    int? selectedCell;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CameraGridNavigator(
            grid: grid,
            activeCellIndex: 0,
            onCellSelected: (index) => selectedCell = index,
          ),
        ),
      ),
    );

    await tester.tap(find.text('R1C2'));

    expect(selectedCell, 1);
  });

  testWidgets('disables cell changes while a photo is being captured', (
    tester,
  ) async {
    int? selectedCell;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CameraGridNavigator(
            grid: grid,
            activeCellIndex: 0,
            enabled: false,
            onCellSelected: (index) => selectedCell = index,
          ),
        ),
      ),
    );

    await tester.tap(find.text('R1C2'));

    expect(selectedCell, isNull);
  });
}
