import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/domain/entities/hall.dart';
import '../../../../core/domain/entities/new_item_draft.dart';
import '../../../../core/domain/entities/object_metadata.dart';
import '../../../../core/domain/entities/object_type.dart';
import '../../../../core/domain/repositories/site_repository.dart';
import '../../../../core/theme/object_type_meta.dart';
import 'add_item_state.dart';

/// Backs the form for adding a wall or object on site: what it offers, what
/// was picked, and storing the result.
class AddItemCubit extends Cubit<AddItemState> {
  AddItemCubit(
    this._repository, {
    required String siteId,
    required String buildingId,
    required this.floorId,
    String? initialHallName,
  }) : super(
         _initialState(
           _repository,
           siteId,
           buildingId,
           floorId,
           initialHallName,
         ),
       );

  static const _nameRequiredMessage = 'A name is required';
  static const _saveFailedMessage =
      'This could not be saved on the phone. Check its free space and try '
      'again.';

  final SiteRepository _repository;
  final String floorId;

  static AddItemState _initialState(
    SiteRepository repository,
    String siteId,
    String buildingId,
    String floorId,
    String? initialHallName,
  ) {
    final site = repository.findSite(siteId);
    final floor = repository.findFloor(floorId);
    final siteKind = site?.kind ?? SiteKind.site;
    final halls = floor?.halls ?? const <HallEntity>[];

    return AddItemState(
      siteName: site?.name ?? '',
      buildingName: repository.findBuilding(buildingId)?.name ?? '',
      floorName: floor?.name ?? '',
      siteKind: siteKind,
      halls: halls,
      objectType: SiteWording.of(siteKind).defaultType,
      hall: halls.where((hall) => hall.name == initialHallName).firstOrNull,
    );
  }

  void selectType(ObjectType type) => emit(state.copyWith(objectType: type));

  /// A null [hall] files the item under the floor's unsorted hall.
  void selectHall(HallEntity? hall) =>
      emit(state.copyWith(hall: hall, clearHall: hall == null));

  void nameEdited() {
    if (state.nameError != null) emit(state.copyWith(clearNameError: true));
  }

  Future<void> submit({
    required String name,
    required String notes,
    required ObjectMetadata metadata,
  }) async {
    if (state.isSaving) return;

    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      emit(state.copyWith(nameError: _nameRequiredMessage));
      return;
    }

    emit(state.copyWith(isSaving: true));
    try {
      final itemId = await _repository.addItem(
        floorId,
        NewItemDraft(
          name: trimmedName,
          objectType: state.objectType,
          notes: notes.trim(),
          hall: state.hall,
          // A wall has none of an object's descriptive fields; whatever was
          // typed before the type was switched to wall is not its metadata.
          metadata: state.objectType == ObjectType.wall
              ? ObjectMetadata.empty
              : metadata,
        ),
      );
      emit(state.copyWith(isSaving: false, savedItemId: itemId));
    } on Object {
      emit(state.copyWith(isSaving: false, failure: _saveFailedMessage));
    }
  }
}
