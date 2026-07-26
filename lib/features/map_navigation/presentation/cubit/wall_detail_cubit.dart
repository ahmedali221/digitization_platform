import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/domain/entities/site.dart';
import '../../../../core/domain/repositories/site_repository.dart';
import '../../../grid_capture/domain/repositories/grid_capture_repository.dart';
import '../../../sync_queue/domain/entities/sync_item.dart';
import '../../../sync_queue/domain/repositories/sync_queue_repository.dart';
import 'wall_detail_state.dart';

/// Watches the repository's site tree and derives the [siteId] building,
/// [floorId] floor's name, and the [wallId] wall itself, so [WallDetailPage]
/// reflects status/grid changes live once a capture session writes back.
class WallDetailCubit extends Cubit<WallDetailState> {
  WallDetailCubit(
    this._repository,
    this._gridCaptureRepository,
    this._syncQueueRepository,
    this._siteId,
    this._buildingId,
    this._floorId,
    this._wallId,
  ) : super(const WallDetailLoading()) {
    _subscription = _repository.watchSites().listen(
      _onSitesChanged,
      onError: (Object error) => emit(WallDetailError(error.toString())),
    );
  }

  final SiteRepository _repository;
  final GridCaptureRepository _gridCaptureRepository;
  final SyncQueueRepository _syncQueueRepository;
  final String _siteId;
  final String _buildingId;
  final String _floorId;
  final String _wallId;
  late final StreamSubscription<List<SiteEntity>> _subscription;

  /// Pushes this wall's already-captured photos straight to the dashboard —
  /// the same finalize path `savePartial` already uses from the capture
  /// screens (writes the manifest, updates wall status, enqueues + attempts
  /// the upload) — then watches the sync queue for *this* wall until it
  /// actually reaches a terminal state, so the caller can show a genuine
  /// success/failure result instead of just "we asked it to start."
  Future<bool> uploadToDashboard() async {
    _gridCaptureRepository.savePartial(_floorId, _wallId);

    var sawUploading = false;
    final completer = Completer<bool>();
    // The queue stream always replays its current snapshot to a new
    // listener first — that snapshot could be a *stale* confirmed/failed
    // status left over from a previous upload of this same wall, so it must
    // be ignored; only state changes that happen after this call count.
    final subscription = _syncQueueRepository.watchQueue().skip(1).listen((
      items,
    ) {
      if (completer.isCompleted) return;
      SyncItem? item;
      for (final candidate in items) {
        if (candidate.id == _wallId) {
          item = candidate;
          break;
        }
      }
      if (item == null) return;
      switch (item.status) {
        case SyncItemStatus.uploading:
          sawUploading = true;
        case SyncItemStatus.confirmed:
          completer.complete(true);
        case SyncItemStatus.failed:
          completer.complete(false);
        case SyncItemStatus.queued:
          // Bounced back to queued after actually starting means a
          // retryable network/server error ended this attempt.
          if (sawUploading) completer.complete(false);
      }
    });

    try {
      return await completer.future.timeout(
        const Duration(minutes: 3),
        onTimeout: () => false,
      );
    } finally {
      await subscription.cancel();
    }
  }

  void _onSitesChanged(List<SiteEntity> sites) {
    for (final site in sites) {
      if (site.id != _siteId) continue;
      for (final building in site.buildings) {
        if (building.id != _buildingId) continue;
        for (final floor in building.floors) {
          if (floor.id != _floorId) continue;
          for (final wall in floor.walls) {
            if (wall.id == _wallId) {
              // `wall` here came straight from SiteRepository, whose mapper
              // never fills in real local photo paths (by design — see
              // SiteMapper._mapGrid). GridCaptureRepository.getWall()
              // overlays this device's actual capture session on top, which
              // is what the "has local photos to upload" check needs.
              final overlaidWall =
                  _gridCaptureRepository.getWall(_floorId, _wallId) ?? wall;
              emit(
                WallDetailLoaded(site, building.name, floor.name, overlaidWall),
              );
              return;
            }
          }
        }
      }
      break;
    }
    emit(const WallDetailNotFound());
  }

  @override
  Future<void> close() {
    _subscription.cancel();
    return super.close();
  }
}
