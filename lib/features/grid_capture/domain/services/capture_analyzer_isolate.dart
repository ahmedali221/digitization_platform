import 'dart:async';
import 'dart:isolate';

import '../entities/capture_quality.dart';
import 'capture_analyzer.dart';

/// Owns one long-lived worker isolate for [analyzeCellQuality], spawned once
/// on first use and reused for the rest of the app session — unlike
/// `compute()`, which spawns (and tears down) a fresh isolate for every
/// single call. A capture session triggers many calls in quick succession
/// (every shot, plus the one-level neighbour-rescore cascade in
/// `CaptureSessionCubit._analyzeCellQuality`), so that per-call spawn/teardown
/// cost adds up as its own CPU/battery drain on top of the SIFT work itself.
/// Register one instance per app (see injection_container.dart) and share it
/// across every `CaptureSessionCubit`.
///
/// Requests are processed one at a time — a Dart isolate's event loop is
/// single-threaded regardless — which also means a neighbour-rescore
/// cascade can no longer spin up several concurrent isolates all doing
/// OpenCV work at once; it queues instead.
class CaptureAnalyzerIsolate {
  Isolate? _isolate;
  SendPort? _toWorker;
  Completer<void>? _starting;
  final Map<int, Completer<CellQualityResult>> _pending = {};
  int _nextRequestId = 0;

  Future<void> _ensureStarted() {
    if (_toWorker != null) return Future.value();
    final alreadyStarting = _starting;
    if (alreadyStarting != null) return alreadyStarting.future;

    final starting = _starting = Completer<void>();
    final fromWorker = ReceivePort();
    fromWorker.listen((message) {
      if (message is SendPort) {
        _toWorker = message;
        starting.complete();
        return;
      }
      final response = message as _AnalyzeResponse;
      final completer = _pending.remove(response.id);
      if (completer == null) return;
      final error = response.error;
      if (error != null) {
        completer.completeError(StateError(error));
      } else {
        completer.complete(response.result);
      }
    });
    Isolate.spawn(_workerMain, fromWorker.sendPort).then((isolate) {
      _isolate = isolate;
    });
    return starting.future;
  }

  /// Scores [request] on the worker isolate, starting it first if this is
  /// the first call this app session.
  Future<CellQualityResult> analyze(CellQualityRequest request) async {
    await _ensureStarted();
    final id = _nextRequestId++;
    final completer = Completer<CellQualityResult>();
    _pending[id] = completer;
    _toWorker!.send(_AnalyzeRequest(id, request));
    return completer.future;
  }

  /// Kills the worker isolate. Not required for normal app lifetime (the
  /// isolate dies with the process); only needed for tests that spin up
  /// several instances.
  void dispose() {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _toWorker = null;
    _starting = null;
    for (final completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('CaptureAnalyzerIsolate disposed'));
      }
    }
    _pending.clear();
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

/// Entry point run once inside the worker isolate: hands back its receive
/// port, then scores every [_AnalyzeRequest] that arrives, one at a time,
/// for as long as the isolate lives.
void _workerMain(SendPort toMain) {
  final fromMain = ReceivePort();
  toMain.send(fromMain.sendPort);
  fromMain.listen((message) {
    final request = message as _AnalyzeRequest;
    try {
      final result = analyzeCellQuality(request.request);
      toMain.send(_AnalyzeResponse(request.id, result, null));
    } catch (error) {
      toMain.send(_AnalyzeResponse(request.id, null, error.toString()));
    }
  });
}
