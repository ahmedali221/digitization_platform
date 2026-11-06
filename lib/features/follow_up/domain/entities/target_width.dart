import '../../data/models/follow_up_upload_record.dart';
import 'follow_up_package.dart';

/// How wide a target really is on the wall. Thoth Guide AI gives this to its
/// image tracker, so it has to describe what the target image shows, edge to edge.
class TargetWidth {
  const TargetWidth(this.meters, this.source);

  static const String sourceAr = 'ar';
  static const String sourceManual = 'manual';

  /// A width already known for this target, kept rather than measured again.
  static const String sourceExisting = 'existing';

  /// Thoth's own limits: it silently drops a width outside them.
  static const double minMeters = 0.01;
  static const double maxMeters = 100;

  final double meters;

  /// [sourceAr], [sourceManual] or [sourceExisting].
  final String source;

  static bool isValid(double meters) => meters >= minMeters && meters <= maxMeters;

  /// Reads what someone typed, in metres. Null when it isn't a usable width.
  /// Allows a decimal comma and Arabic digits, since either is what a phone's
  /// keyboard may offer.
  static double? parseMeters(String text) {
    final buffer = StringBuffer();
    for (final unit in text.trim().runes) {
      if (unit >= _arabicZero && unit < _arabicZero + 10) {
        buffer.write(unit - _arabicZero);
      } else if (unit >= _persianZero && unit < _persianZero + 10) {
        buffer.write(unit - _persianZero);
      } else if (unit == _comma || unit == _arabicDecimal) {
        buffer.write('.');
      } else {
        buffer.writeCharCode(unit);
      }
    }
    final meters = double.tryParse(buffer.toString());
    return meters != null && isValid(meters) ? meters : null;
  }

  static String format(double meters) => '${meters.toStringAsFixed(2)} m';

  static const int _arabicZero = 0x0660;
  static const int _persianZero = 0x06F0;
  static const int _comma = 0x002C;
  static const int _arabicDecimal = 0x066B;
}

const _widthNotInForce = {'rejected', 'superseded', 'refused', 'studio_rejected', 'held', 'kept'};

/// The width this phone knows for [target], or null when it's missing.
///
/// [uploads] is newest first. A width that was sent or is waiting to be counts,
/// so a target stops being labelled as soon as it's measured, with no signal
/// needed. One that was refused doesn't, nor one the studio didn't take. A package
/// built after an upload is newer than it: the reviewer may have corrected the
/// value since.
double? currentTargetWidth(
  FollowUpTarget target,
  Iterable<FollowUpUploadRecord> uploads, {
  DateTime? packageCreatedAt,
}) {
  for (final upload in uploads) {
    if (upload.itemKey != target.arKey || upload.physicalWidthM == null) continue;
    if (upload.family == FollowUpUploadRecord.kindAnnotation) continue;
    if (upload.status == FollowUpUploadRecord.statusFailed) continue;
    if (_widthNotInForce.contains(upload.serverStatus)) continue;
    if (target.physicalWidthM != null &&
        packageCreatedAt != null &&
        upload.createdAt.isBefore(packageCreatedAt)) {
      break;
    }
    return upload.physicalWidthM;
  }
  return target.physicalWidthM;
}
