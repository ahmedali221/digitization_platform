import 'package:equatable/equatable.dart';

/// Lifecycle of a single queued upload (FLUTTER_MOBILE_PLAN.md Phase 7).
enum SyncItemStatus { queued, uploading, confirmed, failed }

class SyncItem extends Equatable {
  const SyncItem({
    required this.id,
    required this.name,
    required this.status,
    this.progress = 0,
  });

  final String id;
  final String name;
  final SyncItemStatus status;

  /// 0-100. Only meaningful while [status] is [SyncItemStatus.uploading].
  final int progress;

  SyncItem copyWith({SyncItemStatus? status, int? progress}) {
    return SyncItem(
      id: id,
      name: name,
      status: status ?? this.status,
      progress: progress ?? this.progress,
    );
  }

  @override
  List<Object?> get props => [id, name, status, progress];
}
