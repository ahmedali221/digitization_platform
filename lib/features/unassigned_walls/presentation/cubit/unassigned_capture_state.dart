import 'package:equatable/equatable.dart';

sealed class UnassignedCaptureState extends Equatable {
  const UnassignedCaptureState();

  @override
  List<Object?> get props => [];
}

class UnassignedCaptureLoading extends UnassignedCaptureState {
  const UnassignedCaptureLoading();
}

class UnassignedCaptureLoaded extends UnassignedCaptureState {
  const UnassignedCaptureLoaded({
    required this.localId,
    required this.shotPaths,
  });

  final String localId;
  final List<String> shotPaths;

  @override
  List<Object?> get props => [localId, shotPaths];
}

class UnassignedCaptureError extends UnassignedCaptureState {
  const UnassignedCaptureError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
