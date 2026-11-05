import 'dart:async';
import 'dart:isolate';

import '../entities/capture_quality.dart';
import 'capture_analyzer.dart';
import 'cell_quality_analyzer.dart';

/// How many images' features the worker keeps between analyses. One shot
/// rescores its cell and up to four neighbours, so a grid with several shots
/// per cell touches about this many images at once.
const int _featureCacheCapacity = 16;

/// Owns one long-lived worker isolate for [analyzeCellQuality], spawned on
/// first use and shared by every `CaptureSessionCubit`.
///
/// This must never run on the main isolate. Since Flutter 3.29 Dart shares the
/// Android main thread, so SIFT there blocks input as well as drawing, and
/// Android reports the app as not responding.
///
/// Long-lived rather than `compute()` so the worker can keep its
/// [ImageFeatureCache] between shots. Requests run one at a time.
class CaptureAnalyzerIsolate implements CellQualityAnalyzer {
  Isolate? _isolate;
  ReceivePort? _fromWorker;
  Completer<SendPort>? _worker;
  final Map<int, Completer<CellQualityResult>> _pending = {};
  int _nextRequestId = 0;

  Future<SendPort> _ensureStarted() {
    final existing = _worker;
    if (existing != null) return existing.future;

    final worker = _worker = Completer<SendPort>();
    final fromWorker = _fromWorker = ReceivePort();
    fromWorker.listen((message) {
      switch (message) {
        case SendPort toWorker:
          worker.complete(toWorker);
        case _AnalyzeResponse response:
          _complete(response);
        default:
          // onExit sends null and onError sends a [error, stack] list. Either
          // way the worker is gone and its queued requests will never finish.
          _reset('The analysis worker stopped: $message');
      }
    });
    Isolate.spawn(
      _workerMain,
      fromWorker.sendPort,
      onExit: fromWorker.sendPort,
      onError: fromWorker.sendPort,
    ).then((isolate) {
      // A reset can land before the spawn finishes.
      if (identical(_worker, worker)) {
        _isolate = isolate;
      } else {
        isolate.kill(priority: Isolate.immediate);
      }
    }, onError: (Object error) => _reset('Could not start the analysis worker: $error'));
    return worker.future;
  }

  void _complete(_AnalyzeResponse response) {
    final completer = _pending.remove(response.id);
    if (completer == null) return;
    final error = response.error;
    if (error != null) {
      completer.completeError(StateError(error));
    } else {
      completer.complete(response.result);
    }
  }

  /// Fails everything in flight and forgets the worker, so the next [analyze]
  /// starts a new one.
  void _reset(String reason) {
    final worker = _worker;
    _worker = null;
    _isolate = null;
    _fromWorker?.close();
    _fromWorker = null;

    final error = StateError(reason);
    if (worker != null && !worker.isCompleted) worker.completeError(error);
    final pending = _pending.values.toList();
    _pending.clear();
    for (final completer in pending) {
      completer.completeError(error);
    }
  }

  @override
  Future<CellQualityResult> analyze(CellQualityRequest request) async {
    final toWorker = await _ensureStarted();
    final id = _nextRequestId++;
    final completer = Completer<CellQualityResult>();
    _pending[id] = completer;
    toWorker.send(_AnalyzeRequest(id, request));
    return completer.future;
  }

  /// Not needed in normal use, since the isolate dies with the process. Only
  /// for tests that create several instances.
  void dispose() {
    _isolate?.kill(priority: Isolate.immediate);
    _reset('CaptureAnalyzerIsolate disposed');
  }
}

class _AnalyzeRequest {
  const _AnalyzeRequest(this.id, this.request);

  final int id;
  final CellQualityRequest request;
}

class _AnalyzeResponse {
  const _AnalyzeResponse(this.id, this.result, this.error);

  final int id;
  final CellQualityResult? result;
  final String? error;
}

void _workerMain(SendPort toMain) {
  final cache = ImageFeatureCache(capacity: _featureCacheCapacity);
  final fromMain = ReceivePort();
  toMain.send(fromMain.sendPort);
  fromMain.listen((message) {
    final request = message as _AnalyzeRequest;
    try {
      final result = analyzeCellQuality(request.request, cache: cache);
      toMain.send(_AnalyzeResponse(request.id, result, null));
    } catch (error) {
      toMain.send(_AnalyzeResponse(request.id, null, error.toString()));
    }
  });
}
