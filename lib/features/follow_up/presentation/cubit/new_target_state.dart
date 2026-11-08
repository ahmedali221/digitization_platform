import 'package:equatable/equatable.dart';

import '../../domain/entities/new_target_details.dart';

class NewTargetState extends Equatable {
  const NewTargetState({
    this.photoPath,
    this.code = '',
    this.description = '',
    this.conflict,
  });

  /// The chosen shot, still in its shots folder until the target is saved.
  final String? photoPath;
  final String code;
  final String description;

  /// Why [code] can't be used here, or null when it can.
  final String? conflict;

  NewTargetDetails get details => NewTargetDetails(code: code, description: description);

  /// Everything but the width, which is measured last so a retake never costs one.
  bool get readyToMeasure => photoPath != null && details.isValid && conflict == null;

  NewTargetState copyWith({
    String? photoPath,
    String? code,
    String? description,
    String? conflict,
    bool clearConflict = false,
  }) => NewTargetState(
    photoPath: photoPath ?? this.photoPath,
    code: code ?? this.code,
    description: description ?? this.description,
    conflict: clearConflict ? null : (conflict ?? this.conflict),
  );

  @override
  List<Object?> get props => [photoPath, code, description, conflict];
}
