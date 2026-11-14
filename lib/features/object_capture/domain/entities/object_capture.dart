import 'package:equatable/equatable.dart';

import '../../../../core/domain/entities/object_type.dart';

/// One photograph of an object held on this phone.
class ObjectPhoto extends Equatable {
  const ObjectPhoto({
    required this.path,
    required this.capturedAt,
    this.side,
    this.comment = '',
    this.isUploaded = false,
  });

  final String path;
  final DateTime capturedAt;

  /// The side this shows, or null for a free photograph.
  final ObjectSide? side;

  /// What the operator wrote about a free photograph.
  final String comment;
  final bool isUploaded;

  bool get isFree => side == null;

  @override
  List<Object?> get props => [path, capturedAt, side, comment, isUploaded];
}

/// Every photograph this phone holds of one object, and what they add up to.
class ObjectCapture extends Equatable {
  const ObjectCapture({this.photos = const []});

  static const empty = ObjectCapture();

  final List<ObjectPhoto> photos;

  bool get isEmpty => photos.isEmpty;

  /// The side photographs, one per side at most.
  Map<ObjectSide, ObjectPhoto> get sidePhotos {
    final bySide = <ObjectSide, ObjectPhoto>{};
    for (final photo in photos) {
      final side = photo.side;
      if (side != null) bySide[side] = photo;
    }
    return bySide;
  }

  List<ObjectPhoto> get freePhotos =>
      photos.where((photo) => photo.isFree).toList();

  int get sidesCaptured => sidePhotos.length;

  bool get hasEverySide => sidesCaptured == ObjectSide.values.length;

  /// A free photograph is only worth sending with its description.
  bool get hasUncommentedFreePhoto =>
      freePhotos.any((photo) => photo.comment.trim().isEmpty);

  /// The same rule the server applies when it is told the upload is
  /// complete (`ObjectPhotoService` on the dashboard): an organised set is
  /// finished at six sides, and a set with no sides at all is free capture,
  /// finished whenever the operator saves it. A part-shot organised set is
  /// still in progress however many free photographs sit beside it.
  bool get isComplete =>
      hasEverySide || (sidePhotos.isEmpty && freePhotos.isNotEmpty);

  @override
  List<Object?> get props => [photos];
}
