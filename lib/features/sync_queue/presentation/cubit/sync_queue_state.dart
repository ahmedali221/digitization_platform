import 'package:equatable/equatable.dart';

import '../../domain/entities/sync_item.dart';

abstract class SyncQueueState extends Equatable {
  const SyncQueueState();

  @override
  List<Object?> get props => [];
}

class SyncQueueLoading extends SyncQueueState {
  const SyncQueueLoading();
}

class SyncQueueLoaded extends SyncQueueState {
  const SyncQueueLoaded(this.items);

  final List<SyncItem> items;

  @override
  List<Object?> get props => [items];
}

class SyncQueueError extends SyncQueueState {
  const SyncQueueError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
