import 'package:equatable/equatable.dart';

import '../../../../core/domain/entities/wall.dart';
import '../../domain/entities/object_capture.dart';
import '../../domain/entities/object_scan.dart';

/// States for the object capture screens: the object being photographed and
/// the photographs this phone holds of it.
sealed class ObjectCaptureState extends Equatable {
  const ObjectCaptureState();

  @override
  List<Object?> get props => [];
}

class ObjectCaptureLoading extends ObjectCaptureState {
  const ObjectCaptureLoading();
}

/// The route's wall no longer resolves in the repository.
class ObjectCaptureNotFound extends ObjectCaptureState {
  const ObjectCaptureNotFound();
}

class ObjectCaptureLoaded extends ObjectCaptureState {
  const ObjectCaptureLoaded({
    required this.wall,
    required this.capture,
    this.scan,
    this.failure,
  });

  final WallEntity wall;
  final ObjectCapture capture;

  /// The 3D scan of the object on this phone, or null when it has none.
  final ObjectScan? scan;

  /// Why the last action did not go through, to be shown once. Null after
  /// any action that did.
  final String? failure;

  ObjectCaptureLoaded copyWith({
    ObjectCapture? capture,
    ObjectScan? scan,
    String? failure,
  }) {
    return ObjectCaptureLoaded(
      wall: wall,
      capture: capture ?? this.capture,
      scan: scan ?? this.scan,
      failure: failure,
    );
  }

  @override
  List<Object?> get props => [wall, capture, scan, failure];
}
