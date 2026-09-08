import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/services/site_backup_service.dart';
import 'site_backup_state.dart';

/// Drives the "back up this site's photos" action: zips every captured shot
/// into one file the operator can then hand off via the share sheet.
/// [SiteBackupReady] only reports where the zip landed — actually sharing it
/// is the UI's job (needs a `BuildContext`), not this cubit's.
class SiteBackupCubit extends Cubit<SiteBackupState> {
  SiteBackupCubit(this._service) : super(const SiteBackupIdle());

  final SiteBackupService _service;

  Future<void> backup(String siteId) async {
    emit(const SiteBackupInProgress(done: 0, total: 0));
    try {
      final zipPath = await _service.backupSite(
        siteId,
        onProgress: (done, total) =>
            emit(SiteBackupInProgress(done: done, total: total)),
      );
      emit(SiteBackupReady(zipPath));
    } catch (e) {
      emit(SiteBackupFailed(e.toString()));
    }
  }
}
