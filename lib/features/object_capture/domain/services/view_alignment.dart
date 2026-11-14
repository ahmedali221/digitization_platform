import 'dart:math' as math;

import '../entities/scan_plan.dart';

/// Lines the server's angles round the object up with this phone's.
///
/// The two count from different places: the phone from wherever it pointed
/// when the scan began, the server from the first photograph it could
/// place. Each photograph both know gives one reading of the difference;
/// the alignment is the reading they agree on.
class ViewAlignment {
  const ViewAlignment._(this._sense, this._offset);

  /// A photograph is known to the phone by the slice it was taken for, so
  /// each reading is off by up to half a slice. Readings scattered wider
  /// than this agree on nothing.
  static const _minAgreement = 0.8;
  static const _minViews = 4;
  static const _radiansPerDegree = math.pi / 180;

  /// 1 when both count the same way round the object, -1 when opposite.
  final int _sense;
  final double _offset;

  /// Null when the photographs do not agree on how the two line up: too few
  /// of them were placed, or the phone's sense of direction drifted.
  static ViewAlignment? fit(Iterable<({double phone, double server})> views) {
    if (views.length < _minViews) return null;

    ViewAlignment? best;
    var bestAgreement = _minAgreement;
    for (final sense in const [1, -1]) {
      var east = 0.0;
      var north = 0.0;
      for (final view in views) {
        final difference =
            (view.phone - sense * view.server) * _radiansPerDegree;
        east += math.cos(difference);
        north += math.sin(difference);
      }
      final agreement = math.sqrt(east * east + north * north) / views.length;
      if (agreement >= bestAgreement) {
        bestAgreement = agreement;
        best = ViewAlignment._(
          sense,
          math.atan2(north, east) / _radiansPerDegree,
        );
      }
    }
    return best;
  }

  /// Where the phone would have to point to stand at [serverAzimuth].
  double toPhone(double serverAzimuth) =>
      ScanPlan.normalise(_sense * serverAzimuth + _offset);

  /// The photographs of the plan that face a part of the object seen from
  /// [azimuth] and [elevation] in the server's angles: the slice level with
  /// it, and the same slice of the ring above, since a side one height did
  /// not show is often shown by another.
  Set<ScanCell> cellsFacing({
    required double azimuth,
    required double elevation,
  }) {
    final phoneAzimuth = toPhone(azimuth);
    final ring = ScanPlan.ringAt(elevation);
    return {
      for (var r = ring; r < ScanPlan.rings.length && r <= ring + 1; r++)
        ScanPlan.cellAt(r, phoneAzimuth),
    };
  }
}
