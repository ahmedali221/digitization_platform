import '../entities/capture_quality.dart';
import 'capture_quality_config.dart';

/// One grid-adjacent cell that already has a captured photo, scored alongside
/// the cell a [CellQualityRequest] is for.
class NeighbourImageInput {
  const NeighbourImageInput({
    required this.direction,
    required this.cellIndex,
    required this.imagePath,
  });

  final NeighbourDirection direction;
  final int cellIndex;
  final String imagePath;
}

/// Plain data: must stay free of any native handle (Mat, VecKeyPoint, ...) so
/// it can cross an isolate boundary. [relevantEdges] is read from the grid, not
/// guessed: a corner cell only needs 2 of its 4 edges scored.
class CellQualityRequest {
  const CellQualityRequest({
    required this.cellIndex,
    required this.imagePaths,
    required this.relevantEdges,
    this.neighbours = const [],
    this.config = const CaptureQualityConfig(),
  });

  final int cellIndex;

  /// Every shot captured for this cell so far, never empty. Each is scored
  /// independently against [neighbours] and the highest-scoring one wins, so a
  /// cell with a bad first attempt and a good retake isn't penalized for
  /// keeping both.
  final List<String> imagePaths;
  final Set<EdgeSide> relevantEdges;
  final List<NeighbourImageInput> neighbours;
  final CaptureQualityConfig config;
}

/// Scores a cell without holding up the caller. This file deliberately doesn't
/// import OpenCV: `CaptureSessionCubit` depends on this interface alone, which
/// keeps native code out of its import graph and lets tests supply a fake.
abstract interface class CellQualityAnalyzer {
  Future<CellQualityResult> analyze(CellQualityRequest request);
}
