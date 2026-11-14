import 'package:equatable/equatable.dart';

import 'hall.dart';
import 'object_metadata.dart';
import 'object_type.dart';

/// What an operator fills in to add a wall or object on site.
class NewItemDraft extends Equatable {
  const NewItemDraft({
    required this.name,
    required this.objectType,
    this.notes = '',
    this.hall,
    this.metadata = ObjectMetadata.empty,
  });

  final String name;
  final ObjectType objectType;
  final String notes;

  /// Null files the item under the floor's unsorted hall.
  final HallEntity? hall;
  final ObjectMetadata metadata;

  @override
  List<Object?> get props => [name, objectType, notes, hall, metadata];
}
