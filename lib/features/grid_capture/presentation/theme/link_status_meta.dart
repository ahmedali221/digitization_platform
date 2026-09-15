import 'package:flutter/material.dart';

import '../../domain/entities/capture_quality.dart';

/// Minimum RANSAC-filtered inlier count (spec's real stitchability signal —
/// see [NeighbourMatchMetrics.ransacInliers]'s doc comment) below which two
/// adjacent cells are shown as not reliably linkable on the coverage-review
/// grid. Display-only: unlike [CaptureQualityConfig]'s thresholds, this never
/// feeds back into [CellQualityResult.cellScore]/`tier` — it's a separate,
/// purely visual "can these two photos actually be merged?" read for the
/// operator, layered on top of a score that already accounts for match
/// quality in its own way.
const int kMinLinkKeypoints = 12;

enum LinkStatus { linked, weak }

class LinkStatusMeta {
  const LinkStatusMeta({required this.color, required this.label});

  final Color color;
  final String label;
}

const Map<LinkStatus, LinkStatusMeta> kLinkStatusMeta = {
  LinkStatus.linked: LinkStatusMeta(
    color: Color(0xFF43A047),
    label: 'Linked',
  ),
  LinkStatus.weak: LinkStatusMeta(
    color: Color(0xFFE53935),
    label: 'Not enough overlap',
  ),
};

extension NeighbourMatchMetricsLinkX on NeighbourMatchMetrics {
  LinkStatus get linkStatus =>
      ransacInliers >= kMinLinkKeypoints ? LinkStatus.linked : LinkStatus.weak;

  LinkStatusMeta get linkMeta => kLinkStatusMeta[linkStatus]!;
}
