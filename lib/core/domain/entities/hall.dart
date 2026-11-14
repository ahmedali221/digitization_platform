import 'package:equatable/equatable.dart';

/// A chamber of a site, or a hall of a museum: the group a wall or object
/// is filed under on its floor.
class HallEntity extends Equatable {
  const HallEntity({required this.name, this.id});

  /// The server's chamber id. Null for a hall an operator named on this
  /// phone that the server has not created yet.
  final String? id;
  final String name;

  @override
  List<Object?> get props => [id, name];
}
