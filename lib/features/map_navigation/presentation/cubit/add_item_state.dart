import 'package:equatable/equatable.dart';

import '../../../../core/domain/entities/hall.dart';
import '../../../../core/domain/entities/object_type.dart';

/// Where the add-item form stands. The text the operator types lives in the
/// page's own controllers; this holds what the form is built from, what was
/// picked, and what came of submitting.
class AddItemState extends Equatable {
  const AddItemState({
    required this.siteName,
    required this.buildingName,
    required this.floorName,
    required this.siteKind,
    required this.halls,
    required this.objectType,
    this.hall,
    this.nameError,
    this.isSaving = false,
    this.failure,
    this.savedItemId,
  });

  final String siteName;
  final String buildingName;
  final String floorName;
  final SiteKind siteKind;

  /// The halls of this floor an item can be filed under.
  final List<HallEntity> halls;
  final ObjectType objectType;
  final HallEntity? hall;
  final String? nameError;
  final bool isSaving;

  /// Why the item could not be stored. Null unless the last save failed.
  final String? failure;

  /// Set once the item is stored: the page moves on to capturing it.
  final String? savedItemId;

  AddItemState copyWith({
    ObjectType? objectType,
    HallEntity? hall,
    bool clearHall = false,
    String? nameError,
    bool clearNameError = false,
    bool? isSaving,
    String? failure,
    String? savedItemId,
  }) {
    return AddItemState(
      siteName: siteName,
      buildingName: buildingName,
      floorName: floorName,
      siteKind: siteKind,
      halls: halls,
      objectType: objectType ?? this.objectType,
      hall: clearHall ? null : (hall ?? this.hall),
      nameError: clearNameError ? null : (nameError ?? this.nameError),
      isSaving: isSaving ?? this.isSaving,
      failure: failure,
      savedItemId: savedItemId ?? this.savedItemId,
    );
  }

  @override
  List<Object?> get props => [
    siteName,
    buildingName,
    floorName,
    siteKind,
    halls,
    objectType,
    hall,
    nameError,
    isSaving,
    failure,
    savedItemId,
  ];
}
