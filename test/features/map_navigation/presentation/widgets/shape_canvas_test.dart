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

  testWidgets('paints CAD primitives beneath selectable navigation shapes', (
    tester,
  ) async {
    String? selectedShapeId;
    const cadShapes = [
      CanvasPath(
        id: 'cad-path',
        color: Colors.black,
        points: [Offset(10, 10), Offset(190, 10), Offset(190, 190)],
        strokeWidth: 2,
      ),
      CanvasCircle(
        id: 'cad-circle',
        color: Colors.blue,
        center: Offset(100, 100),
        radius: 30,
        strokeWidth: 2,
      ),
      CanvasPoint(id: 'cad-point', color: Colors.red, point: Offset(30, 30)),
      CanvasText(
        id: 'cad-text',
        color: Colors.black,
        point: Offset(40, 40),
        text: 'Room A',
        fontSize: 12,
      ),
      CanvasRect(
        id: 'room',
        color: Colors.green,
        rect: RectShape(x: 0, y: 0, w: 200, h: 200),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            height: 200,
            child: ShapeCanvas(
              canvasSize: canvasSize,
              shapes: cadShapes,
              interactive: false,
              allowFullscreen: false,
              onShapeTap: (id) => selectedShapeId = id,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tapAt(
      tester.getCenter(find.byKey(const ValueKey('shape-map-content'))),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(selectedShapeId, 'room');
  });
}
