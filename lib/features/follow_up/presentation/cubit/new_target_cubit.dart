import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/follow_up_package.dart';
import '../../domain/entities/target_width.dart';
import '../../domain/repositories/follow_up_repository.dart';
import '../../domain/repositories/new_target_repository.dart';
import 'new_target_state.dart';

/// Adding a target the site had no profile for: its photograph, code and
/// description, then its width, which saves it to send when there's a signal.
class NewTargetCubit extends Cubit<NewTargetState> {
  NewTargetCubit({
    required NewTargetRepository newTargets,
    required FollowUpRepository followUp,
    required this.package,
  }) : _newTargets = newTargets,
       _followUp = followUp,
       super(const NewTargetState());

  final NewTargetRepository _newTargets;
  final FollowUpRepository _followUp;
  final FollowUpPackage package;

  Future<String>? _shotsFolder;

  /// Where this target's shots go: one folder however often it's retaken, gone
  /// when the page closes, by which time a saved photograph has been copied out.
  Future<String> shotsFolder() => _shotsFolder ??= _followUp.newShotsFolder(package.siteId);

  void setPhoto(String path) => emit(state.copyWith(photoPath: path));

  void setCode(String code) {
    final conflict = _newTargets.codeConflict(package, code);
    emit(state.copyWith(code: code, conflict: conflict, clearConflict: conflict == null));
  }

  void setDescription(String description) => emit(state.copyWith(description: description));

  /// Throws if it couldn't be saved, so the width page can offer to try again
  /// with the measurement it already has.
  Future<void> save(TargetWidth width) => _newTargets.queueNewTarget(
    package: package,
    details: state.details,
    photoPath: state.photoPath!,
    width: width,
  );

  @override
  Future<void> close() async {
    final folder = _shotsFolder;
    if (folder != null) await _followUp.deleteShotsFolder(await folder);
    return super.close();
  }
}
