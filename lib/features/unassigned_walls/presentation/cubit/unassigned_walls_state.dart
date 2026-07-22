import 'package:equatable/equatable.dart';

import '../../domain/entities/unassigned_wall.dart';

abstract class UnassignedWallsState extends Equatable {
  const UnassignedWallsState();

  @override
  List<Object?> get props => [];
}

class UnassignedWallsLoading extends UnassignedWallsState {
  const UnassignedWallsLoading();
}

class UnassignedWallsLoaded extends UnassignedWallsState {
  const UnassignedWallsLoaded(this.items);

  final List<UnassignedWall> items;

  @override
  List<Object?> get props => [items];
}

class UnassignedWallsError extends UnassignedWallsState {
  const UnassignedWallsError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
