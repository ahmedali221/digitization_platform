import 'package:equatable/equatable.dart';

sealed class SiteBackupState extends Equatable {
  const SiteBackupState();

  @override
  List<Object?> get props => [];
}

class SiteBackupIdle extends SiteBackupState {
  const SiteBackupIdle();
}

class SiteBackupInProgress extends SiteBackupState {
  const SiteBackupInProgress({required this.done, required this.total});

  final int done;
  final int total;

  @override
  List<Object?> get props => [done, total];
}

class SiteBackupReady extends SiteBackupState {
  const SiteBackupReady(this.zipPath);

  final String zipPath;

  @override
  List<Object?> get props => [zipPath];
}

class SiteBackupFailed extends SiteBackupState {
  const SiteBackupFailed(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
