import 'dart:async';

import '../../domain/entities/building.dart';
import '../../domain/entities/floor.dart';
import '../../domain/entities/site.dart';
import '../../domain/entities/wall.dart';
import '../../domain/repositories/site_repository.dart';
import '../../theme/wall_status.dart';

/// In-memory stand-in for the real Hive/Dio-backed repository. The demo data
/// follows the production hierarchy exactly: sites own buildings, buildings
/// own floors, and floors own walls.
class FakeSiteRepository implements SiteRepository {
  FakeSiteRepository() {
    _sites = _seed();
    _controller = StreamController<List<SiteEntity>>.broadcast();
  }

  late List<SiteEntity> _sites;
  late final StreamController<List<SiteEntity>> _controller;
  Timer? _downloadTimer;
  int _nextWallSuffix = 0;

  @override
  Stream<List<SiteEntity>> watchSites() async* {
    yield _sites;
    yield* _controller.stream;
  }

  @override
  SiteEntity? findSite(String siteId) {
    for (final site in _sites) {
      if (site.id == siteId) return site;
    }
    return null;
  }

  @override
  BuildingEntity? findBuilding(String buildingId) {
    for (final site in _sites) {
      for (final building in site.buildings) {
        if (building.id == buildingId) return building;
      }
    }
    return null;
  }

  @override
  FloorEntity? findFloor(String floorId) {
    for (final site in _sites) {
      for (final building in site.buildings) {
        for (final floor in building.floors) {
          if (floor.id == floorId) return floor;
        }
      }
    }
    return null;
  }

  @override
  WallEntity? findWall(String floorId, String wallId) {
    final floor = findFloor(floorId);
    if (floor == null) return null;
    for (final wall in floor.walls) {
      if (wall.id == wallId) return wall;
    }
    return null;
  }

  @override
  Future<void> startDownload(String siteId) async {
    _mutateSite(
      siteId,
      (s) => s.copyWith(
        availability: SiteAvailability.downloading,
        downloadProgress: 0,
      ),
    );

    _downloadTimer?.cancel();
    _downloadTimer = Timer.periodic(const Duration(milliseconds: 350), (timer) {
      final current = findSite(siteId);
      if (current == null ||
          current.availability != SiteAvailability.downloading) {
        timer.cancel();
        return;
      }
      final next = current.downloadProgress + 14;
      if (next >= 100) {
        _mutateSite(
          siteId,
          (s) => s.copyWith(
            availability: SiteAvailability.ready,
            downloadProgress: 100,
            lastSynced: 'just now',
            updateAvailable: false,
          ),
        );
        timer.cancel();
      } else {
        _mutateSite(siteId, (s) => s.copyWith(downloadProgress: next));
      }
    });
  }

  List<BuildingEntity> _buildingsFor(String siteId) {
    return switch (siteId) {
      's1' => [
        _building('s1', 'b1', 'Mastaba A', [
          _floor('b1', 'f1', 'Ground Floor', [
            ('North face', WallStatus.done, 'Yesterday'),
            ('South face', WallStatus.done, 'Yesterday'),
            ('East face', WallStatus.captured, '2h ago'),
            ('West face', WallStatus.inProgress, '2h ago'),
          ]),
          _floor('b1', 'f27', 'Upper Level', [
            ('North parapet', WallStatus.notStarted, '—'),
            ('South parapet', WallStatus.notStarted, '—'),
          ]),
        ]),
        _building('s1', 'b2', 'Mastaba B', [
          _floor('b2', 'f2', 'Ground Floor', [
            ('North face', WallStatus.notStarted, '—'),
            ('South face', WallStatus.notStarted, '—'),
            ('East face', WallStatus.skipped, '3d ago'),
          ]),
        ]),
        _building('s1', 'b3', 'Causeway', [
          _floor('b3', 'f3', 'Processional Level', [
            ('Segment 1', WallStatus.done, '1w ago'),
            ('Segment 2', WallStatus.done, '1w ago'),
          ]),
        ]),
        _building('s1', 'b4', 'Pyramid Enclosure', [
          _floor('b4', 'f4', 'Ground Floor', [
            ('North wall', WallStatus.captured, '5h ago'),
            ('East wall', WallStatus.inProgress, '5h ago'),
            ('South wall', WallStatus.notStarted, '—'),
          ]),
        ]),
        _building('s1', 'b14', 'Serapeum', [
          _floor('b14', 'f14', 'Main Corridor', [
            ('Main gallery wall', WallStatus.done, '2w ago'),
            ('Side niche wall', WallStatus.skipped, '2w ago'),
          ]),
        ]),
      ],
      's2' => [
        _building('s2', 'b5', 'Hypostyle Hall', [
          _floor('b5', 'f5', 'Ground Floor', [
            ('Column row A', WallStatus.captured, '1d ago'),
            ('Column row B', WallStatus.inProgress, '1d ago'),
          ]),
          _floor('b5', 'f28', 'Roof Level', [
            ('Zodiac ceiling wall', WallStatus.notStarted, '—'),
            ('Roof kiosk wall', WallStatus.notStarted, '—'),
          ]),
        ]),
        _building('s2', 'b6', 'Sanctuary', [
          _floor('b6', 'f6', 'Ground Floor', [
            ('Inner wall', WallStatus.notStarted, '—'),
            ('Outer wall', WallStatus.notStarted, '—'),
          ]),
        ]),
        _building('s2', 'b12', 'Roof Chapels', [
          _floor('b12', 'f12', 'Upper Terrace', [
            ('Osiris chapel wall', WallStatus.done, '4d ago'),
            ('East kiosk wall', WallStatus.captured, '4d ago'),
          ]),
        ]),
        _building('s2', 'b13', 'Birth House', [
          _floor('b13', 'f13', 'Ground Floor', [
            ('Facade wall', WallStatus.skipped, '2w ago'),
            ('Rear wall', WallStatus.notStarted, '—'),
          ]),
        ]),
      ],
      's3' => [
        _building('s3', 'b7', 'Osireion Hall', [
          _floor('b7', 'f7', 'Lower Level', [
            ('North colonnade', WallStatus.notStarted, '—'),
            ('South colonnade', WallStatus.notStarted, '—'),
            ('Central island wall', WallStatus.notStarted, '—'),
          ]),
          _floor('b7', 'f29', 'Upper Gallery', [
            ('Gallery east wall', WallStatus.notStarted, '—'),
            ('Gallery west wall', WallStatus.notStarted, '—'),
          ]),
        ]),
        _building('s3', 'b8', 'Transverse Chamber', [
          _floor('b8', 'f8', 'Ground Floor', [
            ('East wall', WallStatus.notStarted, '—'),
            ('West wall', WallStatus.notStarted, '—'),
          ]),
        ]),
        _building('s3', 'b15', 'Osiris Cenotaph', [
          _floor('b15', 'f15', 'Cenotaph Level', [
            ('Island retaining wall', WallStatus.notStarted, '—'),
            ('Descending stair wall', WallStatus.notStarted, '—'),
          ]),
        ]),
      ],
      's4' => [
        _building('s4', 'b9', 'Tomb of Ramose', [
          _floor('b9', 'f9', 'Entrance Level', [
            ('Entrance wall', WallStatus.notStarted, '—'),
            ('Offering chapel wall', WallStatus.notStarted, '—'),
          ]),
          _floor('b9', 'f30', 'Burial Level', [
            ('Burial chamber wall', WallStatus.notStarted, '—'),
            ('Sarcophagus recess', WallStatus.notStarted, '—'),
          ]),
        ]),
        _building('s4', 'b10', 'Tomb of Userhat', [
          _floor('b10', 'f10', 'Main Level', [
            ('North wall', WallStatus.notStarted, '—'),
            ('South wall', WallStatus.notStarted, '—'),
          ]),
        ]),
        _building('s4', 'b11', 'Tomb of Khaemhat', [
          _floor('b11', 'f11', 'Main Level', [
            ('Pillared hall wall', WallStatus.notStarted, '—'),
            ('Inner shrine wall', WallStatus.notStarted, '—'),
          ]),
        ]),
        _building('s4', 'b16', 'Tomb of Sennedjem', [
          _floor('b16', 'f16', 'Burial Level', [
            ('Vaulted ceiling wall', WallStatus.notStarted, '—'),
            ('Rear shrine wall', WallStatus.notStarted, '—'),
          ]),
        ]),
      ],
      's5' => [
        _building('s5', 'b17', 'Great Hypostyle Hall', [
          _floor('b17', 'f17', 'Ground Floor', [
            ('North colonnade', WallStatus.done, '3h ago'),
            ('South colonnade', WallStatus.captured, '3h ago'),
            ('Clerestory wall', WallStatus.inProgress, '3h ago'),
          ]),
          _floor('b17', 'f31', 'Clerestory Level', [
            ('East clerestory', WallStatus.notStarted, '—'),
            ('West clerestory', WallStatus.notStarted, '—'),
          ]),
        ]),
        _building('s5', 'b18', 'Precinct of Amun-Re', [
          _floor('b18', 'f18', 'Ground Floor', [
            ('First pylon', WallStatus.done, '1d ago'),
            ('Second pylon', WallStatus.notStarted, '—'),
          ]),
        ]),
        _building('s5', 'b19', 'Sacred Lake Enclosure', [
          _floor('b19', 'f19', 'Lake Level', [
            ('Lake wall east', WallStatus.notStarted, '—'),
            ('Lake wall west', WallStatus.skipped, '5d ago'),
          ]),
        ]),
        _building('s5', 'b20', 'Temple of Khonsu', [
          _floor('b20', 'f20', 'Ground Floor', [
            ('Forecourt wall', WallStatus.captured, '6h ago'),
            ('Sanctuary wall', WallStatus.inProgress, '6h ago'),
          ]),
        ]),
      ],
      's6' => [
        _building('s6', 'b21', 'Tomb of Ramesses VI', [
          _floor('b21', 'f21', 'Corridor Level', [
            ('Entrance corridor', WallStatus.notStarted, '—'),
            ('Burial chamber ceiling', WallStatus.notStarted, '—'),
          ]),
        ]),
        _building('s6', 'b22', 'Tomb of Seti I', [
          _floor('b22', 'f22', 'Burial Level', [
            ('Well chamber wall', WallStatus.notStarted, '—'),
            ('Pillared hall wall', WallStatus.notStarted, '—'),
            ('Sarcophagus chamber', WallStatus.notStarted, '—'),
          ]),
        ]),
        _building('s6', 'b23', 'Tomb of Tutankhamun', [
          _floor('b23', 'f23', 'Burial Level', [
            ('Antechamber wall', WallStatus.notStarted, '—'),
            ('Burial chamber wall', WallStatus.notStarted, '—'),
          ]),
        ]),
      ],
      's7' => [
        _building('s7', 'b24', 'Great Pyramid Causeway', [
          _floor('b24', 'f24', 'Causeway Level', [
            ('North causeway wall', WallStatus.notStarted, '—'),
            ('South causeway wall', WallStatus.notStarted, '—'),
          ]),
        ]),
        _building('s7', 'b25', 'Queens\' Pyramids', [
          _floor('b25', 'f25', 'Plateau Level', [
            ('G1-a enclosure wall', WallStatus.notStarted, '—'),
            ('G1-b enclosure wall', WallStatus.notStarted, '—'),
            ('G1-c enclosure wall', WallStatus.notStarted, '—'),
          ]),
        ]),
        _building('s7', 'b26', 'Sphinx Temple', [
          _floor('b26', 'f26', 'Ground Floor', [
            ('North colonnade wall', WallStatus.notStarted, '—'),
            ('South colonnade wall', WallStatus.notStarted, '—'),
          ]),
        ]),
      ],
      _ => const [],
    };
  }

  BuildingEntity _building(
    String siteId,
    String buildingId,
    String name,
    List<FloorEntity> floors,
  ) {
    return BuildingEntity(
      id: buildingId,
      siteId: siteId,
      name: name,
      floors: floors,
    );
  }

  FloorEntity _floor(
    String buildingId,
    String floorId,
    String name,
    List<(String name, WallStatus status, String lastCapture)> walls,
  ) {
    return FloorEntity(
      id: floorId,
      buildingId: buildingId,
      name: name,
      walls: _makeWalls(floorId, walls),
    );
  }

  @override
  void updateWall(
    String floorId,
    String wallId,
    WallEntity Function(WallEntity current) update,
  ) {
    _sites = _sites.map((site) {
      final buildings = site.buildings.map((building) {
        final floors = building.floors.map((floor) {
          if (floor.id != floorId) return floor;
          final walls = floor.walls.map((wall) {
            if (wall.id != wallId) return wall;
            return update(wall);
          }).toList();
          return floor.copyWithWalls(walls);
        }).toList();
        return building.copyWithFloors(floors);
      }).toList();
      return site.copyWith(buildings: buildings);
    }).toList();
    _controller.add(_sites);
  }

  @override
  void addWall(String floorId, {required String title, String notes = ''}) {
    _sites = _sites.map((site) {
      final buildings = site.buildings.map((building) {
        final floors = building.floors.map((floor) {
          if (floor.id != floorId) return floor;
          final wall = WallEntity(
            id: '$floorId-w${_nextWallSuffix++}',
            floorId: floorId,
            name: title,
            notes: notes,
            status: WallStatus.notStarted,
            lastCapture: '—',
          );
          return floor.copyWithWalls([...floor.walls, wall]);
        }).toList();
        return building.copyWithFloors(floors);
      }).toList();
      return site.copyWith(buildings: buildings);
    }).toList();
    _controller.add(_sites);
  }

  void _mutateSite(String siteId, SiteEntity Function(SiteEntity) update) {
    _sites = _sites.map((s) => s.id == siteId ? update(s) : s).toList();
    _controller.add(_sites);
  }

  List<WallEntity> _makeWalls(
    String floorId,
    List<(String name, WallStatus status, String lastCapture)> defs,
  ) {
    return defs.asMap().entries.map((entry) {
      final index = entry.key;
      final (name, status, lastCapture) = entry.value;
      GridState? grid;
      if (status == WallStatus.done || status == WallStatus.captured) {
        grid = GridState(
          rows: 2,
          cols: 2,
          cells: List.generate(
            4,
            (i) => GridCell(shotPaths: ['seed/$floorId/w$index/c$i/S1.jpg']),
          ),
        );
      } else if (status == WallStatus.inProgress) {
        grid = GridState(
          rows: 2,
          cols: 2,
          cells: [
            GridCell(
              shotPaths: [
                'seed/$floorId/w$index/c0/S1.jpg',
                'seed/$floorId/w$index/c0/S2.jpg',
              ],
            ),
            const GridCell(),
            GridCell(shotPaths: ['seed/$floorId/w$index/c2/S1.jpg']),
            const GridCell(),
          ],
        );
      }
      return WallEntity(
        id: '$floorId-w$index',
        floorId: floorId,
        name: name,
        status: status,
        lastCapture: lastCapture,
        grid: grid,
      );
    }).toList();
  }

  List<SiteEntity> _seed() {
    return [
      SiteEntity(
        id: 's1',
        name: 'Saqqara North Necropolis',
        location: 'Saqqara, Egypt',
        availability: SiteAvailability.ready,
        lastSynced: '2h ago',
        buildings: _buildingsFor('s1'),
      ),
      SiteEntity(
        id: 's2',
        name: 'Dendera Temple Complex',
        location: 'Dendera, Egypt',
        availability: SiteAvailability.ready,
        lastSynced: '1d ago',
        updateAvailable: true,
        buildings: _buildingsFor('s2'),
      ),
      SiteEntity(
        id: 's3',
        name: 'Abydos Osireion',
        location: 'Abydos, Egypt',
        availability: SiteAvailability.downloading,
        downloadProgress: 35,
        wallsTotalOverride: 40,
        buildings: _buildingsFor('s3'),
      ),
      SiteEntity(
        id: 's4',
        name: 'Luxor West Bank Tombs',
        location: 'Luxor, Egypt',
        availability: SiteAvailability.notDownloaded,
        wallsTotalOverride: 80,
        buildings: _buildingsFor('s4'),
      ),
      SiteEntity(
        id: 's5',
        name: 'Karnak Temple Complex',
        location: 'Luxor, Egypt',
        availability: SiteAvailability.ready,
        lastSynced: '3h ago',
        buildings: _buildingsFor('s5'),
      ),
      SiteEntity(
        id: 's6',
        name: 'Valley of the Kings',
        location: 'Luxor, Egypt',
        availability: SiteAvailability.downloading,
        downloadProgress: 62,
        wallsTotalOverride: 55,
        buildings: _buildingsFor('s6'),
      ),
      SiteEntity(
        id: 's7',
        name: 'Giza Plateau',
        location: 'Giza, Egypt',
        availability: SiteAvailability.notDownloaded,
        wallsTotalOverride: 45,
        buildings: _buildingsFor('s7'),
      ),
    ];
  }
}
