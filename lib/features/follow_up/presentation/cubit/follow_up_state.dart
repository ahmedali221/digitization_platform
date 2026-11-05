import 'package:equatable/equatable.dart';

import '../../data/models/follow_up_upload_record.dart';
import '../../domain/entities/follow_up_package.dart';

class FollowUpState extends Equatable {
  const FollowUpState({
    this.loading = true,
    this.package,
    this.available,
    this.offline = false,
    this.downloading = false,
    this.progress = 0,
    this.error,
    this.uploads = const [],
    this.revision = 0,
  });

  final bool loading;

  /// The package on this phone.
  final FollowUpPackage? package;

  /// A package on the server that isn't on this phone yet.
  final FollowUpPackage? available;
  final bool offline;
  final bool downloading;
  final double progress;
  final String? error;
  final List<FollowUpUploadRecord> uploads;

  /// Upload records change in place, so equal lists can still mean new content.
  final int revision;

  FollowUpState copyWith({
    bool? loading,
    FollowUpPackage? package,
    FollowUpPackage? available,
    bool clearAvailable = false,
    bool? offline,
    bool? downloading,
    double? progress,
    String? error,
    bool clearError = false,
    List<FollowUpUploadRecord>? uploads,
  }) => FollowUpState(
    loading: loading ?? this.loading,
    package: package ?? this.package,
    available: clearAvailable ? null : (available ?? this.available),
    offline: offline ?? this.offline,
    downloading: downloading ?? this.downloading,
    progress: progress ?? this.progress,
    error: clearError ? null : (error ?? this.error),
    uploads: uploads ?? this.uploads,
    revision: uploads != null ? revision + 1 : revision,
  );

  @override
  List<Object?> get props => [
    loading,
    package?.id,
    available?.id,
    offline,
    downloading,
    progress,
    error,
    revision,
  ];
}
