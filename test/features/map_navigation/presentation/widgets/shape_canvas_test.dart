import 'package:digitization_platform/core/domain/entities/canvas_shape.dart';
import 'package:digitization_platform/features/map_navigation/presentation/widgets/shape_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const canvasSize = CanvasSize(width: 200, height: 200);
  const shapes = [
    CanvasRect(
      id: 'building-1',
      color: Colors.blue,
      label: 'Building 1',
      rect: RectShape(x: 0, y: 0, w: 200, h: 200),
    ),
  ];

  testWidgets('opens a full screen map with accessible zoom controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            height: 240,
            child: ShapeCanvas(
              canvasSize: canvasSize,
              shapes: shapes,
              fullscreenTitle: 'Buildings map',
              onShapeTap: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('shape-map-expand-button')));
    await tester.pumpAndSettle();

    expect(find.text('Buildings map'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('shape-map-zoom-out-button')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('shape-map-fit-button')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('shape-map-zoom-in-button')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('shape-map-zoom-in-button')));
    await tester.tap(find.byKey(const ValueKey('shape-map-zoom-out-button')));
    await tester.tap(find.byKey(const ValueKey('shape-map-fit-button')));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('returns the selected shape from the full screen map', (
    tester,
  ) async {
    String? selectedShapeId;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            height: 240,
            child: ShapeCanvas(
              canvasSize: canvasSize,
              shapes: shapes,
              onShapeTap: (id) => selectedShapeId = id,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('shape-map-expand-button')));
    await tester.pumpAndSettle();

    final fullScreenCanvas = find.byKey(const ValueKey('shape-map-content'));
    await tester.tapAt(tester.getCenter(fullScreenCanvas));
    await tester.pumpAndSettle();

    expect(selectedShapeId, 'building-1');
    expect(find.text('Map'), findsNothing);
  });
}
