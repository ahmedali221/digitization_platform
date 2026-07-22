import 'package:equatable/equatable.dart';

import 'building.dart';
import 'wall.dart';

/// Whether a site's bundle is on-device yet (FLUTTER_MOBILE_PLAN.md §Phase 1).
enum SiteAvailability { notDownloaded, downloading, ready }

class SiteEntity extends Equatable {
  const SiteEntity({
    required this.id,
    required this.name,
    required this.location,
    required this.availability,
    required this.buildings,
    this.wallsTotalOverride,
    this.downloadProgress = 0,
    this.lastSynced = '—',
    this.updateAvailable = false,
  });

  final String id;
  final String name;
  final String location;
  final SiteAvailability availability;
  final List<BuildingEntity> buildings;

  /// Published wall count shown before a site is ready. The fake repository
  /// still carries the site's nested buildings, floors, and walls in memory
  /// so the domain hierarchy is complete, but this value mirrors the package
  /// summary until the simulated download finishes.
  final int? wallsTotalOverride;

  /// 0-100.
  final int downloadProgress;
  final String lastSynced;
  final bool updateAvailable;

  bool get isReady => availability == SiteAvailability.ready;
  bool get isDownloading => availability == SiteAvailability.downloading;
  bool get isNotDownloaded => availability == SiteAvailability.notDownloaded;

  int get wallsTotal => !isReady && wallsTotalOverride != null
      ? wallsTotalOverride!
      : buildings.fold(0, (count, building) => count + building.wallCount);

  int get wallsCaptured => isReady
      ? buildings.fold(0, (count, building) => count + building.doneCount)
      : 0;

  List<WallEntity> get allWalls => buildings
      .expand((building) => building.floors)
      .expand((floor) => floor.walls)
      .toList();

  SiteEntity copyWith({
    SiteAvailability? availability,
    List<BuildingEntity>? buildings,
    int? downloadProgress,
    String? lastSynced,
    bool? updateAvailable,
  }) {
    return SiteEntity(
      id: id,
      name: name,
      location: location,
      availability: availability ?? this.availability,
      buildings: buildings ?? this.buildings,
      wallsTotalOverride: wallsTotalOverride,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      lastSynced: lastSynced ?? this.lastSynced,
      updateAvailable: updateAvailable ?? this.updateAvailable,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    location,
    availability,
    buildings,
    wallsTotalOverride,
    downloadProgress,
    lastSynced,
    updateAvailable,
  ];
}
