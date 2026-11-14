import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/domain/repositories/site_repository.dart';
import '../../domain/entities/object_scan.dart';
import '../../domain/repositories/object_scan_repository.dart';

/// What the scan status screen shows.
class ScanStatusState extends Equatable {
  const ScanStatusState({
    this.objectName = '',
    this.scan,
    this.isReopened = false,
  });

  final String objectName;

  /// Null when this phone holds no scan of the object.
  final ObjectScan? scan;

  /// The scan was opened for more photographs: the screen goes to capture.
  final bool isReopened;

  @override
  List<Object?> get props => [objectName, scan, isReopened];
}

/// Follows a scan after the operator has finished shooting: its upload, then
/// what the server made of it. Asks the server again every few seconds for
/// as long as the answer can still change by itself.
class ScanStatusCubit extends Cubit<ScanStatusState> {
  ScanStatusCubit(
    this._repository,
    SiteRepository siteRepository, {
    required String floorId,
    required this.wallId,
  }) : super(
         ScanStatusState(
           objectName: siteRepository.findWall(floorId, wallId)?.name ?? '',
           scan: _repository.getScan(wallId),
         ),
       ) {
    _scans = _repository
        .watchScan(wallId)
        .listen(
          (scan) =>
              emit(ScanStatusState(objectName: state.objectName, scan: scan)),
        );
    _poll = Timer.periodic(_pollInterval, (_) => _refresh());
    // Asked once on opening whatever the scan's state: the server may have
    // gone on since this phone last heard, with a rough model or the model.
    _refresh(evenIfSettled: true);
  }

  static const _pollInterval = Duration(seconds: 4);

  final ObjectScanRepository _repository;
  final String wallId;

  late final StreamSubscription<ObjectScan?> _scans;
  late final Timer _poll;
  bool _refreshing = false;

  /// Opens the scan for the photographs the server asked for, or, with
  /// [fromTheStart], for all of them again.
  Future<void> captureMore({bool fromTheStart = false}) async {
    await _repository.reopen(wallId, fromTheStart: fromTheStart);
    emit(
      ScanStatusState(
        objectName: state.objectName,
        scan: _repository.getScan(wallId),
        isReopened: true,
      ),
    );
  }

  Future<void> _refresh({bool evenIfSettled = false}) async {
    final settled = state.scan?.isSettled ?? true;
    if (_refreshing || (settled && !evenIfSettled)) return;
    _refreshing = true;
    try {
      await _repository.refreshStatus(wallId);
    } on Object {
      // Out of signal: the last known state stays, and the next tick asks again.
    } finally {
      _refreshing = false;
    }
  }

  @override
  Future<void> close() {
    _poll.cancel();
    _scans.cancel();
    return super.close();
  }
}
