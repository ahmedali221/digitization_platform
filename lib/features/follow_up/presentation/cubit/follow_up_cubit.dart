import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/failure.dart';
import '../../data/models/follow_up_upload_record.dart';
import '../../domain/entities/follow_up_package.dart';
import '../../domain/repositories/follow_up_repository.dart';
import 'follow_up_state.dart';

class FollowUpCubit extends Cubit<FollowUpState> {
  FollowUpCubit(this._repository, this._siteId) : super(const FollowUpState()) {
    _repository.onUploadsChanged = refreshUploads;
    load();
  }

  final FollowUpRepository _repository;
  final String _siteId;

  /// The package on the phone comes first and works with no signal; asking the
  /// server what's newer can't get in its way.
  Future<void> load() async {
    final package = await _repository.localPackage(_siteId);
    _emit(state.copyWith(
      loading: false,
      package: package,
      uploads: _repository.uploads(_siteId),
    ));
    await _checkServer();
    await _repository.sync();
  }

  Future<void> _checkServer() async {
    try {
      final remote = await _repository.remotePackage(_siteId);
      final isNewer = remote != null && remote.id != state.package?.id;
      _emit(state.copyWith(available: isNewer ? remote : null, clearAvailable: !isNewer, offline: false));
    } on AppException catch (e) {
      _emit(state.copyWith(offline: e.failure is NetworkFailure));
    }
  }

  Future<void> download() async {
    final package = state.available;
    if (package == null || state.downloading) return;

    _emit(state.copyWith(downloading: true, progress: 0, clearError: true));
    try {
      await _repository.download(
        package,
        onProgress: (fraction) => _emit(state.copyWith(progress: fraction)),
      );
      _emit(state.copyWith(
        downloading: false,
        package: await _repository.localPackage(_siteId),
        clearAvailable: true,
      ));
    } on AppException catch (e) {
      _emit(state.copyWith(downloading: false, error: e.failure.message));
    } catch (e) {
      _emit(state.copyWith(downloading: false, error: 'The download stopped: $e'));
    }
  }

  void refreshUploads() {
    _emit(state.copyWith(uploads: _repository.uploads(_siteId)));
  }

  Future<void> syncNow() => _repository.sync();

  void _emit(FollowUpState next) {
    if (!isClosed) emit(next);
  }

  FollowUpUploadRecord? latestFor(String kind, String itemKey) {
    for (final upload in state.uploads) {
      if (upload.kind == kind && upload.itemKey == itemKey) return upload;
    }
    return null;
  }

  FollowUpPackage? get package => state.package;

  @override
  Future<void> close() {
    _repository.onUploadsChanged = null;
    return super.close();
  }
}
