import 'package:equatable/equatable.dart';

import '../../../../core/domain/entities/object_type.dart';

/// The server's answer to "here is a wall or object I created offline".
class FieldItemRegistration extends Equatable {
  const FieldItemRegistration({
    required this.serverWallId,
    required this.createdAt,
    this.hallId,
    this.hallName,
    this.intakeStatus = IntakeStatus.accepted,
    this.isArchived = false,
  });

  final String serverWallId;

  /// When the server created the wall, by the server's clock.
  final DateTime createdAt;
  final String? hallId;
  final String? hallName;
  final IntakeStatus intakeStatus;

  /// Rejected or removed on the dashboard: its photos are no longer wanted.
  final bool isArchived;

  @override
  List<Object?> get props => [
    serverWallId,
    createdAt,
    hallId,
    hallName,
    intakeStatus,
    isArchived,
  ];
}
