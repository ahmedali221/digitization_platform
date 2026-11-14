import 'package:flutter/material.dart';

import '../domain/entities/object_type.dart';

class ObjectTypeMeta {
  const ObjectTypeMeta({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

/// Single source of truth for how an [ObjectType] is named and drawn — the
/// labels match the dashboard's `ObjectType::label()`.
const Map<ObjectType, ObjectTypeMeta> kObjectTypeMeta = {
  ObjectType.wall: ObjectTypeMeta(label: 'Wall', icon: Icons.grid_view),
  ObjectType.painting: ObjectTypeMeta(
    label: 'Painting',
    icon: Icons.image_outlined,
  ),
  ObjectType.statue: ObjectTypeMeta(
    label: 'Statue',
    icon: Icons.accessibility_new,
  ),
  ObjectType.stela: ObjectTypeMeta(label: 'Stela', icon: Icons.crop_portrait),
  ObjectType.sarcophagus: ObjectTypeMeta(
    label: 'Sarcophagus / coffin',
    icon: Icons.inventory_2_outlined,
  ),
  ObjectType.other: ObjectTypeMeta(
    label: 'Other object',
    icon: Icons.category_outlined,
  ),
};

extension ObjectTypeX on ObjectType {
  ObjectTypeMeta get meta => kObjectTypeMeta[this]!;
}

extension ObjectSideX on ObjectSide {
  String get label => switch (this) {
    ObjectSide.front => 'Front',
    ObjectSide.back => 'Back',
    ObjectSide.left => 'Left',
    ObjectSide.right => 'Right',
    ObjectSide.top => 'Top',
    ObjectSide.bottom => 'Bottom',
  };
}

/// What a site calls its parts: a museum has halls and objects where an
/// archaeological site has chambers and walls.
class SiteWording {
  const SiteWording._({
    required this.item,
    required this.items,
    required this.hall,
    required this.defaultType,
  });

  factory SiteWording.of(SiteKind kind) =>
      kind == SiteKind.museum ? _museum : _site;

  static const _site = SiteWording._(
    item: 'wall',
    items: 'walls',
    hall: 'room',
    defaultType: ObjectType.wall,
  );

  static const _museum = SiteWording._(
    item: 'object',
    items: 'objects',
    hall: 'hall',
    defaultType: ObjectType.statue,
  );

  /// Lower case, for use mid-sentence ("Add wall", "No objects yet").
  final String item;
  final String items;
  final String hall;

  /// [hall] as a heading: "Room" or "Hall".
  String get hallHeading => '${hall[0].toUpperCase()}${hall.substring(1)}';

  /// The type an add form opens on.
  final ObjectType defaultType;
}
