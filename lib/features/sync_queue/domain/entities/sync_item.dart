import 'package:equatable/equatable.dart';

/// Lifecycle of a single queued upload (FLUTTER_MOBILE_PLAN.md Phase 7).
enum SyncItemStatus { queued, uploading, confirmed, failed }

class SyncItem extends Equatable {
  const SyncItem({
    required this.id,
    required this.name,
    required this.status,
    this.progress = 0,
    this.reason,
  });

  final String id;
  final String name;
  final SyncItemStatus status;

  /// 0-100. Only meaningful while [status] is [SyncItemStatus.uploading].
  final int progress;

  /// Why [status] is [SyncItemStatus.failed], shown to the user. Null for
  /// every other status.
  final String? reason;

  SyncItem copyWith({SyncItemStatus? status, int? progress, String? reason}) {
    return SyncItem(
      id: id,
      name: name,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      reason: reason ?? this.reason,
    );
  }

  @override
  List<Object?> get props => [id, name, status, progress, reason];
}
