import 'package:equatable/equatable.dart';

import '../../domain/entities/unassigned_wall.dart';

sealed class UnassignedWallDetailState extends Equatable {
  const UnassignedWallDetailState();

  @override
  List<Object?> get props => [];
}

class UnassignedWallDetailLoading extends UnassignedWallDetailState {
  const UnassignedWallDetailLoading();
}

class UnassignedWallDetailNotFound extends UnassignedWallDetailState {
  const UnassignedWallDetailNotFound();
}

class UnassignedWallDetailError extends UnassignedWallDetailState {
  const UnassignedWallDetailError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class UnassignedWallDetailLoaded extends UnassignedWallDetailState {
  const UnassignedWallDetailLoaded(this.wall, {this.syncing = false});

  final UnassignedWall wall;
  final bool syncing;

  UnassignedWallDetailLoaded copyWith({UnassignedWall? wall, bool? syncing}) {
    return UnassignedWallDetailLoaded(
      wall ?? this.wall,
      syncing: syncing ?? this.syncing,
    );
  }

  @override
  List<Object?> get props => [wall, syncing];
}
