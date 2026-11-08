import 'package:digitization_platform/core/camera/capture_camera_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _viewfinder = Key('viewfinder');
const _shutter = Key('shutter');
const _map = Key('map');
const _finish = Key('finish');
const _shots = Key('shots');

void main() {
  final orientationCalls = <String>[];

  setUp(() {
    orientationCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('nilelens/screen_orientation'),
      (call) async => orientationCalls.add(call.method),
    );
  });

  Axis? shotsAxis;

  Future<void> pump(WidgetTester tester, Size size, {bool withMap = true, bool withShots = true}) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    shotsAxis = null;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CaptureCameraLayout(
            // Fills its space, as CameraViewfinder does.
            viewfinder: const SizedBox.expand(key: _viewfinder, child: ColoredBox(color: Colors.black)),
            topStart: const Text('back'),
            topEnd: const Text('flash'),
            gridMap: withMap ? const SizedBox(key: _map, height: 64) : null,
            shots: withShots
                ? (axis) {
                    shotsAxis = axis;
                    return const SizedBox(key: _shots, width: 64, height: 64);
                  }
                : null,
            shutter: const SizedBox(key: _shutter, width: 72, height: 72),
            finish: const SizedBox(key: _finish, width: 96, height: 40),
          ),
        ),
      ),
    );
  }

  Rect rectOf(WidgetTester tester, Key key) => tester.getRect(find.byKey(key));

  testWidgets('held upright, the controls sit under the viewfinder', (tester) async {
    await pump(tester, const Size(400, 800));

    final viewfinder = rectOf(tester, _viewfinder);
    expect(rectOf(tester, _map).top, greaterThanOrEqualTo(viewfinder.bottom));
    expect(rectOf(tester, _shutter).top, greaterThanOrEqualTo(rectOf(tester, _map).bottom));
    expect(rectOf(tester, _shutter).center.dx, closeTo(200, 1));
    expect(rectOf(tester, _shots).right, lessThan(rectOf(tester, _shutter).left));
    expect(rectOf(tester, _finish).left, greaterThan(rectOf(tester, _shutter).right));
    expect(shotsAxis, Axis.horizontal);
  });

  testWidgets('held sideways, they move into a rail beside it, top to bottom', (tester) async {
    await pump(tester, const Size(800, 400));

    final viewfinder = rectOf(tester, _viewfinder);
    expect(viewfinder.height, 400);
    for (final key in [_map, _shots, _shutter, _finish]) {
      expect(rectOf(tester, key).left, greaterThanOrEqualTo(viewfinder.right), reason: '$key is in the rail');
    }
    expect(rectOf(tester, _shots).top, greaterThanOrEqualTo(rectOf(tester, _map).bottom));
    expect(rectOf(tester, _shutter).top, greaterThanOrEqualTo(rectOf(tester, _shots).bottom));
    expect(rectOf(tester, _finish).top, greaterThanOrEqualTo(rectOf(tester, _shutter).bottom));
    expect(shotsAxis, Axis.vertical);
  });

  testWidgets('the rail keeps to its bounds on a very wide screen', (tester) async {
    await pump(tester, const Size(2000, 400));

    expect(rectOf(tester, _viewfinder).width, 2000 - 320);
  });

  testWidgets('without a grid map or shots there is nothing in their place', (tester) async {
    await pump(tester, const Size(400, 800), withMap: false, withShots: false);

    expect(find.byKey(_map), findsNothing);
    expect(find.byKey(_shots), findsNothing);
    expect(rectOf(tester, _shutter).top, closeTo(rectOf(tester, _viewfinder).bottom + 16, 1));
  });

  testWidgets('the screen follows the phone while the camera is open, and lets go after', (tester) async {
    // A tree left by an earlier test is only torn down by the next pump.
    await tester.pumpWidget(const SizedBox());
    orientationCalls.clear();

    await pump(tester, const Size(400, 800));
    expect(orientationCalls, ['followSensor']);

    await tester.pumpWidget(const SizedBox());
    expect(orientationCalls, ['followSensor', 'release']);
  });
}
