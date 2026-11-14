import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/domain/entities/object_type.dart';
import '../../../../core/domain/entities/site.dart';
import '../../../../core/domain/entities/wall.dart';
import '../../../../core/domain/repositories/site_repository.dart';
import '../../../grid_capture/domain/repositories/grid_capture_repository.dart';
import '../../../object_capture/domain/repositories/object_capture_repository.dart';
import '../../../sync_queue/domain/entities/sync_item.dart';
import '../../../sync_queue/domain/repositories/sync_queue_repository.dart';
import 'wall_detail_state.dart';

/// Watches the repository's site tree and derives the [siteId] building,
/// [floorId] floor's name, and the [wallId] wall itself, so [WallDetailPage]
/// reflects status and capture changes live once a capture writes back.
///
/// A wall is captured one of two ways ([CaptureMode]), each with its own
/// repository; the two places that differ — what this phone holds, and how
/// it is handed to the upload queue — are the two `switch`es below.
class WallDetailCubit extends Cubit<WallDetailState> {
  WallDetailCubit(
    this._repository,
    this._gridCaptureRepository,
    this._objectCaptureRepository,
    this._syncQueueRepository,
    this._siteId,
    this._buildingId,
    this._floorId,
    this._wallId,
  ) : super(const WallDetailLoading()) {
    _sitesSubscription = _repository.watchSites().listen(
      _onSitesChanged,
      onError: (Object error) => emit(WallDetailError(error.toString())),
    );
    // Photographs can be added and left unsaved, which changes nothing the
    // site tree knows about; the capture's own stream is what reports it.
    _captureSubscription = _objectCaptureRepository
        .watchCapture(_wallId)
        .listen((_) {
          final sites = _latestSites;
          if (sites != null) _onSitesChanged(sites);
        });
  }

  static const _uploadTimeout = Duration(minutes: 3);

  final SiteRepository _repository;
  final GridCaptureRepository _gridCaptureRepository;
  final ObjectCaptureRepository _objectCaptureRepository;
  final SyncQueueRepository _syncQueueRepository;
  final String _siteId;
  final String _buildingId;
  final String _floorId;
  final String _wallId;
  late final StreamSubscription<List<SiteEntity>> _sitesSubscription;
  late final StreamSubscription<void> _captureSubscription;

  /// Null until the site tree has been read once.
  List<SiteEntity>? _latestSites;

  /// Pushes this wall's already-captured photos straight to the dashboard —
  /// the same save the capture screens use (updates wall status, enqueues +
  /// attempts the upload) — then watches the sync queue for *this* wall
  /// until it actually reaches a terminal state, so the caller can show a
  /// genuine success/failure result instead of just "we asked it to start."
  Future<bool> uploadToDashboard() async {
    final current = state;
    if (current is! WallDetailLoaded) return false;

    // Subscribed before the save: the queue stream replays its current
    // snapshot to a new listener first — possibly a *stale* confirmed/failed
    // status left by an earlier upload of this same wall — and `skip(1)`
    // drops exactly that one event. Only changes after this call count.
    var sawUploading = false;
    final completer = Completer<bool>();
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
      await _saveCapture(current.wall.captureMode);
      return await completer.future.timeout(
        _uploadTimeout,
        onTimeout: () => false,
      );
    } finally {
      await subscription.cancel();
    }
  }

  Future<void> _saveCapture(CaptureMode captureMode) async {
    switch (captureMode) {
      case CaptureMode.grid:
        _gridCaptureRepository.savePartial(_floorId, _wallId);
      case CaptureMode.loose:
        await _objectCaptureRepository.save(floorId: _floorId, wallId: _wallId);
    }
  }

  bool _hasLocalPhotos(WallEntity wall) {
    return switch (wall.captureMode) {
      CaptureMode.grid => (wall.grid?.filledCount ?? 0) > 0,
      CaptureMode.loose =>
        !_objectCaptureRepository.getCapture(_wallId).isEmpty,
    };
  }

  void _onSitesChanged(List<SiteEntity> sites) {
    _latestSites = sites;
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
                WallDetailLoaded(
                  site: site,
                  buildingName: building.name,
                  floorName: floor.name,
                  wall: overlaidWall,
                  hasLocalPhotos: _hasLocalPhotos(overlaidWall),
                ),
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
    _sitesSubscription.cancel();
    _captureSubscription.cancel();
    return super.close();
  }
}
