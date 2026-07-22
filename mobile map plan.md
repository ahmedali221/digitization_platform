# Real geometric floor-plan map for WallBase mobile

## Context

`d:\Nile Tech\digitization_platform` is the WallBase Flutter field-capture app. A prior build pass implemented 8 screens against a Claude Design handoff prototype (`design-system-documentation/project/WallBase Sites.dc.html`), including a `map_navigation` feature whose "Site Overview" screen shows zones as a flat, order-based 2-column grid of colored tiles (`ZoneTile`) — because that prototype never modeled real coordinates. `DESIGN_SYSTEM.md` already documents the real, unbuilt target for this: a "Floor canvas" screen using `CustomPainter`/`InteractiveViewer` with real `RoomShape` geometry, a `StatusLegend`, and a `RemainingFilterToggle` — and `FLUTTER_MOBILE_PLAN.md` describes the full intended drill-down: Site → Building → Floor canvas → Room sheet → Wall sheet.

This plan fills that gap: replacing the flat zone grid with a real, geometric, three-level map (Site map → Building map → Floor map), sourced from the exact JSON shape the web dashboard (`d:\Nile Tech\Digitization-Platform`) actually publishes (verified by reading the real `SitePackageBuilder.php` and Vue canvas code, not just the planning docs — see "Verified backend contract" below). The goal is a mobile screen an operator can actually navigate a real tomb/temple site with, not a placeholder.

**Confirmed with the user:** the new geometry model is **additive** — it does not touch `SiteEntity`/`ZoneEntity`/`WallEntity`/`SiteRepository`, which 5 already-shipped, analyzer-clean features depend on (`site_sync`, `map_navigation`, `grid_capture`, `sync_queue`, `unassigned_walls`). The new model cross-references the existing one purely by reusing the same `zoneId`/`wallId` strings, so capture status, `RoomSheet`, and `WallActionSheet` are reused completely unchanged.

## Verified backend contract (read from the actual Laravel/Vue source, not the planning docs)

`site_package.json` (site + building + floor *metadata* — floors are metadata-only here, each floor's real geometry is a separate file):
```json
{
  "site": { "id": 1, "name": "Karnak", "version": 1, "published_at": "..." },
  "overview_canvas": { "width": 1200, "height": 800, "background_image_url": "https://.../xyz.jpg",
    "shapes": [ { "building_id": 3, "label": "Hypostyle Hall", "x": 20.0, "y": 20.0, "w": 220.0, "h": 180.0, "color": "#4F46E5" } ] },
  "buildings": [ { "id": 3, "name": "Hypostyle Hall", "type": "temple",
    "shape": { "x": 20.0, "y": 20.0, "w": 220.0, "h": 180.0, "color": "#4F46E5" },
    "building_canvas": { "width": 1200, "height": 800, "background_image_url": null,
      "shapes": [ { "floor_id": 7, "label": "Ground Floor", "x": 20, "y": 20, "w": 220, "h": 80 } ] },
    "floors": [ { "id": 7, "name": "Ground Floor", "level_index": 0, "file": "floor_7.json" } ] } ]
}
```
`floor_{id}.json` (fetched separately per floor, already how `site_sync`'s offline-download step works):
```json
{
  "floor": { "id": 7, "name": "Ground Floor", "level_index": 0 },
  "canvas": { "width": 1200, "height": 800, "background_image_url": "https://.../..." },
  "geometry_schema_version": 2, "geometry": [ /* raw CAD entities — deferred, see below */ ], "layers": [ /* deferred */ ],
  "rooms": [ { "id": 12, "chamber_id": 44, "label": "Offering Chamber", "x": 20.0, "y": 20.0, "w": 220.0, "h": 180.0,
    "walls": [ { "id": 55, "wall_id": 91, "edge": "north", "x1": 20.0, "y1": 20.0, "x2": 240.0, "y2": 20.0 } ] } ],
  "wall_status_index": { "91": { "status": "in_progress", "grid_rows": 2, "grid_cols": 2, "covered_cells": 3,
    "photo_count": 3, "last_capture_at": "...", "thumb_url": "captures/9f3c2e.jpg" } },
  "published_at": "..."
}
```
Key facts that shape the design: origin top-left, y down, plain canvas pixels (not meters). Only buildings have an explicit manual `color`; rooms/floor-zones have none — status coloring for rooms must be computed client-side via the *existing* `aggregateWallStatus()`. No `list_mode` flag and no `tap_action` field exist anywhere in the real backend — both are aspirational prose in the planning docs only; the backend always supplies *some* shape geometry (auto-laid-out when nothing was manually drawn), and tap-dispatch is entirely a client decision. Raw CAD `geometry`/`layers` arrays exist in the wire format but are **out of scope for this plan** — WallBase's own stated philosophy ("grid-based capture, not automatic stitching... the map can be wrong") means precise CAD linework matters far less for field navigation than for dashboard editing; background image + room/wall rectangles/lines is enough. `wall_status_index` is likewise **not modeled** as a new entity — it duplicates data the existing `SiteRepository`/local `wall_status` store already owns; a future real datasource should feed it into *that* existing system, not create a second source of truth here.

## Approach: hybrid `CustomPainter` (pixels) + real widgets (hit-testing)

Two full competing designs were produced and compared: a pure-`CustomPainter` approach (everything drawn as pixels, hit-testing done manually via a pure `Rect.contains()` function) and a hybrid approach (painter draws non-interactive pixels only — background image, wall lines, room fills/borders, labels — while each tappable shape is a real `Positioned` + `InkWell`/`Semantics` widget on top, both living inside the same `InteractiveViewer` so they scale/pan in lockstep).

**Recommendation: hybrid.** Reasons, weighed honestly against the pure-painter alternative:
- **Real accessibility for free** (screen-reader focus/labels, keyboard/hover on the `≥600px` wide layout DESIGN_SYSTEM.md already anticipates) — a pure painter is invisible to Flutter's semantics tree by default and would need a hand-built parallel `SemanticsNode` tree. This matters concretely here: DESIGN_SYSTEM.md's whole rationale for generous touch targets is gloved fingers and direct sun, i.e. exactly the context where you can't assume ideal touch input either.
- **A more rigorous fix for a real domain-specific risk**: tomb/temple floor plans are dense, wall-sharing layouts, not sparse map pins — padding every room's tap target out to 48dp naively causes neighboring small rooms' hit-boxes to overlap. The hybrid design resolves this once, at floor-load time, with padding clamped to half the gap to each neighbor (never overlapping by construction, with a deterministic area-sort tie-break only for genuine zero-gap edges). The pure-painter alternative's answer is materially weaker: an ad-hoc "last drawn wins" z-order tie-break on the overlap region.
- **Idiomatic Flutter testability** — real `InkWell`s are tappable via `tester.tap(find.byKey(...))`, no bespoke coordinate-math test harness needed.
- The pure-painter design's genuine advantage (a pure, widget-free `hitTest()` function, trivially unit-testable in isolation) is real but not decisive — and the hybrid design's own honest downside (drawn rect and hit rect are two code paths that must stay in sync) is well-mitigated by routing both through one shared `hitBoundsFor()` helper, treated as non-negotiable during implementation.
- Both designs independently converged on the same conclusions for: entity placement (feature-local `domain/`, not `core/domain`, since exactly one feature consumes geometry today — promote later if that changes), and using `InteractiveViewer` sized to the canvas's native pixel dimensions so **no manual scale/pan transform math is ever needed** in either the painter or the hit-testing code (Flutter's own hit-test pipeline and the painter's `Canvas` both already operate in canvas-space once inside `InteractiveViewer`'s transformed child).

Two universal implementation gotchas both designs flagged, applicable regardless of approach — build these in from the start, not as an afterthought:
1. `TextPainter`/`Paint` objects for labels must be constructed once per shape-list change, never inside `paint()` itself — `InteractiveViewer` repaints its child on every pointer-move frame during a drag, so per-frame construction visibly janks.
2. Background image decode is async; the painter must be wired to trigger a repaint once the `ui.Image` resolves, or the background silently never appears.

**Risk to de-risk early, not discover mid-build**: this codebase has zero prior `CustomPainter`/`InteractiveViewer` usage anywhere. Nesting a child `InkWell`'s tap recognizer inside `InteractiveViewer`'s own pan/scale gesture recognizers is a workable but historically finicky gesture-arena interaction. **Before building all three pages, spike a single throwaway screen** (one `InteractiveViewer` containing a `CustomPaint` background and 2-3 tappable `Positioned` rects) to confirm tap-vs-pan disambiguation behaves correctly, especially on a touch device/emulator, not just desktop-mouse testing.

## Terminology / level mapping (state this plainly so it isn't ambiguous mid-build)

Today's `ZoneEntity` (consumed by `RoomSheet`) is, conceptually, already "a room" — its `RoomSheet` lists walls exactly like `rooms[].walls` in `floor_{id}.json` does. So: the existing flat `SiteOverviewPage` **becomes Level 3 ("floor map")**, and two new screens are inserted above it:

```
Sites List → [NEW] Level 1 Site map (buildings) → [NEW] Level 2 Building map (floors)
           → [Level 3, was SiteOverviewPage] Floor map (rooms, real geometry)
           → RoomSheet (unchanged) → WallActionSheet (unchanged) → grid-init/grid-capture/camera/coverage-review (unchanged)
```

## Entity / repository design

New, feature-local, under `lib/features/map_navigation/domain/` and `data/` (not `core/domain/` — geometry has exactly one consumer today; promote to `core/` later if a second feature ever needs it, following the exact thin re-export pattern `features/site_sync/domain/repositories/site_repository.dart` already demonstrates).

```dart
// domain/entities/canvas_entity.dart
class CanvasEntity { width, height: double; backgroundImageUrl: String?; }

// domain/entities/site_map_entity.dart  (Level 1 — site_package.json)
class BuildingShapeEntity {
  buildingId, label: String; x, y, w, h: double; manualColor: Color?;   // from hex "#4F46E5" via a new core/utils/hex_color.dart
  Rect get rect => Rect.fromLTWH(x, y, w, h);
}
class SiteMapEntity { siteId: String; canvas: CanvasEntity; buildingShapes: List<BuildingShapeEntity>; }

// domain/entities/building_map_entity.dart  (Level 2 — one building's building_canvas + floors[])
class FloorShapeEntity { floorId, label: String; x, y, w, h: double; Rect get rect => ...; }   // no color field, matches JSON
class FloorSummaryEntity { id, name: String; levelIndex: int; }                                 // metadata only
class BuildingMapEntity {
  buildingId, siteId, name, type: String;   // type stays a raw String (temple/tomb/...) — not a closed enum, backend can extend it freely
  canvas: CanvasEntity; floorShapes: List<FloorShapeEntity>; floors: List<FloorSummaryEntity>;
}

// domain/entities/floor_map_entity.dart  (Level 3 — floor_{id}.json)
enum WallEdge { north, east, south, west }
class WallShapeEntity {
  id: String;             // fidelity only
  wallId: String;          // *** MUST equal an existing WallEntity.id (e.g. 'z1-w0') ***
  edge: WallEdge; x1, y1, x2, y2: double;
}
class RoomShapeEntity {
  id: String;              // fidelity only
  zoneId: String;           // *** MUST equal an existing ZoneEntity.id (e.g. 'z1') ***
  label: String; x, y, w, h: double; walls: List<WallShapeEntity>;
  Rect get rect => Rect.fromLTWH(x, y, w, h);
}
class FloorMapEntity {
  floorId, buildingId, name: String; levelIndex: int; canvas: CanvasEntity; rooms: List<RoomShapeEntity>;
}
```

Repository (`domain/repositories/site_map_repository.dart`) — deliberately `Future`-based, not `Stream`-based like `SiteRepository`: geometry is static per published bundle version, it never mutates during a capture session (unlike wall status, which does and already has its own stream):
```dart
abstract class SiteMapRepository {
  Future<SiteMapEntity?> loadSiteMap(String siteId);
  Future<FloorMapEntity?> loadFloorMap(String siteId, String floorId);
}
```
(Building-level data is embedded inline within `SiteMapEntity`/`site_package.json`, not a separate fetch — matches the real wire format, where only floors are separate files.)

`FakeSiteMapRepository` (`data/repositories/fake_site_map_repository.dart`) seeds geometry for the two "ready" fake sites only, **reusing the exact existing ids** from `lib/core/data/repositories/fake_site_repository.dart`:
- `s1` (Saqqara) → one building, two floors → floor A rooms `[z1, z2]`, floor B rooms `[z3, z4]` (deliberately two floors under one building, to exercise Level 2's floor selector).
- `s2` (Dendera) → one building, one floor → rooms `[z5, z6]` (deliberately single-floor, to exercise the "trivial floor list" case — Level 2 is still shown, not auto-skipped; skipping it would need conditional redirect-on-navigate logic and inconsistent back-button history for a one-tap savings that isn't worth the complexity).
- `s3`/`s4` (not downloaded / downloading) → `loadSiteMap` returns `null`, consistent with their empty `zones: []`.
- Each room's walls are auto-laid-out on its four edges in id order (e.g. room `z1` → wall shapes with `wallId: 'z1-w0'`, `'z1-w1'`, ...), mirroring the real backend's own auto-layout fallback shape.

## Widget / painter / hit-testing design

**One shared scaffold widget**, reused by all 3 levels (`presentation/widgets/geometric_canvas.dart`):
```
LayoutBuilder(builder: (context, constraints) {
  final fitScale = min(constraints.maxWidth / canvas.width, constraints.maxHeight / canvas.height);
  // fitScale seeds the TransformationController ONCE post-first-layout so the whole level is visible on open —
  // this satisfies "sized to available space via LayoutBuilder, never a hardcoded aspect ratio" without the
  // canvas itself changing size; all further zoom/pan is InteractiveViewer's own transform matrix.
  return InteractiveViewer(
    transformationController: _controller, constrained: false, boundaryMargin: const EdgeInsets.all(200),
    minScale: fitScale * 0.5, maxScale: fitScale * 6,
    child: SizedBox(width: canvas.width, height: canvas.height,   // native pixel size — 1:1 with raw JSON coordinates
      child: Stack(children: [
        Positioned.fill(child: CustomPaint(painter: ShapePainter(...))),   // background image + fills/borders + labels (+ wall lines at L3)
        for (final shape in orderedHotspots) ShapeHotspot(shape: shape, hitBounds: hitBoundsFor(shape, allShapes), onTap: ...),
      ]),
    ),
  );
})
```

**48dp tap target, computed once per floor load** (`presentation/widgets/shape_hotspot.dart`), padded outward from each shape's center and **clamped to never exceed half the gap to its nearest neighbor on that side**:
```dart
Rect hitBoundsFor(Rect shape, List<Rect> allOtherShapes) {
  double padL = 24, padT = 24, padR = 24, padB = 24;   // start at (48-min_dimension)/2, simplified to 24 here for illustration
  for (final other in allOtherShapes) {
    padL = min(padL, gapOnLeft(shape, other) / 2);
    padT = min(padT, gapOnTop(shape, other) / 2);
    padR = min(padR, gapOnRight(shape, other) / 2);
    padB = min(padB, gapOnBottom(shape, other) / 2);
  }
  return Rect.fromLTRB(shape.left - padL, shape.top - padT, shape.right + padR, shape.bottom + padB);
}
```
Where true zero-gap (shared wall, touching rects) collapses padding to 0 on that side, the tap target legitimately stays below 48dp on that edge — an accepted, explicit fallback for the pathological case, not a silent bug. The `Positioned` children list is sorted by ascending shape area (smallest last / topmost), so on any residual overlap a small room's padding deterministically wins over a larger neighbor's.

Each hotspot is a real widget, giving accessibility and hit-testing for free:
```dart
Positioned(left: hitBounds.left, top: hitBounds.top, width: hitBounds.width, height: hitBounds.height,
  child: Semantics(button: true, label: '${shape.label}, ${status.meta.label}',
    child: InkWell(onTap: () => onTap(shape), splashColor: Colors.transparent, highlightColor: Colors.transparent,
      child: const SizedBox.expand())));   // no visible child — all pixels come from the painter underneath
```

**`RemainingFilterToggle`** (Level 3 only, per DESIGN_SYSTEM.md's component table) is **dim, never remove**: a room whose aggregate status is `done` gets a desaturated fill from the painter and a matching `AnimatedOpacity` (150-200ms, matching DESIGN_SYSTEM's motion guidance) on its hotspot — no widget is added/removed from the `Stack` when the toggle flips, and the room stays fully tappable throughout (capture actions are never disabled anywhere else in this app either — `WallActionSheet` already encodes that rule, this stays consistent with it).

**Tap dispatch** (invented client-side, since no `tap_action` field exists anywhere in the real backend): Level 1 building tap → push Level 2. Level 2 floor tap → push Level 3. Level 3 room tap → resolve `RoomShapeEntity.zoneId` via the *existing* `SiteRepository.findZone()` → open the *existing*, unmodified `RoomSheet`.

## Routing changes (verified safe against the real, current `app_router.dart`)

```
/sites/:siteId/overview                                    → SiteMapPage      (Level 1)  [same path, new page — was SiteOverviewPage]
/sites/:siteId/overview/:buildingId                         → BuildingMapPage  (Level 2)  [NEW]
/sites/:siteId/overview/:buildingId/:floorId                → FloorMapPage     (Level 3)  [NEW, absorbs old SiteOverviewPage's role]
/sites/:siteId/overview/:zoneId/:wallId/grid-init            → GridInitPage                [UNCHANGED — verified below]
/sites/:siteId/overview/:zoneId/:wallId/grid-capture         → GridCapturePage             [UNCHANGED]
/sites/:siteId/overview/:zoneId/:wallId/camera               → CameraCapturePage           [UNCHANGED]
/sites/:siteId/overview/:zoneId/:wallId/coverage-review      → CoverageReviewPage          [UNCHANGED]
```
**Why the 4 wall-capture routes need zero edits, confirmed by reading the actual current files:** `app_router.dart` is a *flat* `GoRoute` list (no nested `routes:`), matched purely on literal-segment shape + segment count. The new Level 2/3 routes are 1- and 2-dynamic-segment paths with no trailing literal; the wall-capture routes are 3-dynamic-segment paths *with* a trailing literal (`grid-init`/`grid-capture`/`camera`/`coverage-review`) — different shapes, no possible collision regardless of the new params' names. `WallActionSheet._onCapture` (confirmed by direct read) builds its route from raw interpolated strings, not a named-route lookup, and that string's shape is untouched — so **`wall_action_sheet.dart` requires zero edits**, and `SitesListPage`'s existing `context.push('/sites/${site.id}/overview')` also requires **zero edits** (it still means "go start the map," now Level 1 instead of the old flat grid).

## Cubit / data-orchestration design

`FloorMapCubit` is the one that joins two repositories: on construction it `await`s `SiteMapRepository.loadFloorMap()` once (geometry is cached for the cubit's lifetime), then subscribes to the *existing* `SiteRepository.watchSites()` stream; on every emission it re-resolves each room/wall's live status via `findZone`/`findWall` and re-emits a merged view-model. This is what makes "mark a wall skipped and watch colors propagate up all three levels instantly" (an existing Phase 2 acceptance criterion) actually work. `SiteMapCubit`/`BuildingMapCubit` do the shallower version: computing a building's or floor's *aggregate* status requires walking every floor under it — which sounds like an N+1 fan-out, but isn't a real latency concern here, because `site_sync`'s existing offline-download step already fetches **every** `floor_{id}.json` to local storage before a site is marked "ready" (per `FLUTTER_MOBILE_PLAN.md`: "Batch download of ALL `floor_{id}.json` files... in one operation") — so by the time these cubits run, every floor package is already a local read, not a network fetch.

## File-level plan

**New — `features/map_navigation/domain/entities/`**: `canvas_entity.dart`, `site_map_entity.dart` (+`BuildingShapeEntity`), `building_map_entity.dart` (+`FloorShapeEntity`, `FloorSummaryEntity`), `floor_map_entity.dart` (+`RoomShapeEntity`, `WallShapeEntity`, `WallEdge`).

**New — `features/map_navigation/domain/repositories/`**: `site_map_repository.dart`.

**New — `features/map_navigation/data/repositories/`**: `fake_site_map_repository.dart`.

**New — `features/map_navigation/presentation/cubit/`**: `site_map_cubit.dart`/`_state.dart` (Level 1), `building_map_cubit.dart`/`_state.dart` (Level 2), `floor_map_cubit.dart`/`_state.dart` (Level 3, the `SiteMapRepository`↔`SiteRepository` join + `showRemainingOnly` filter state).

**New — `features/map_navigation/presentation/pages/`**: `site_map_page.dart`, `building_map_page.dart`, `floor_map_page.dart`.

**New — `features/map_navigation/presentation/widgets/`**: `geometric_canvas.dart` (shared `InteractiveViewer`+`Stack` scaffold), `shape_painter.dart` (background/fills/borders/labels/wall-lines `CustomPainter`), `shape_hotspot.dart` (the ≥48dp neighbor-aware hit target), `remaining_filter_toggle.dart`.

**New — `core/`**: `core/utils/hex_color.dart` (parses `"#4F46E5"` → `Color`, generic/cross-cutting), `core/widgets/status_legend.dart` (extracted from the inline `Wrap` in the old `site_overview_page.dart`, reused at all 3 levels).

**Deleted** (superseded, no remaining callers — CLAUDE.md forbids dead code): `presentation/pages/site_overview_page.dart`, `presentation/cubit/site_overview_cubit.dart`, `presentation/cubit/site_overview_state.dart`, `presentation/widgets/zone_tile.dart`.

**Unchanged, reused exactly as-is**: `room_sheet.dart`, `wall_action_sheet.dart`, `wall_row.dart`, `overview_metrics.dart`, `core/theme/wall_status.dart` (status colors/aggregation — the single source of truth this whole feature reads from), `core/domain/entities/{site,zone,wall}.dart`, `core/domain/repositories/site_repository.dart`, `core/data/repositories/fake_site_repository.dart`.

**Modified**: `core/router/app_router.dart` (swap `/overview` builder to `SiteMapPage`, add the 2 new Level 2/3 routes — wall-capture routes untouched), `core/di/injection_container.dart` (register `SiteMapRepository → FakeSiteMapRepository()`, one new line).

## Build sequencing

1. **Spike first**: a throwaway screen — one `InteractiveViewer` + a `CustomPaint` background + 2-3 tappable `Positioned` rects — to confirm tap-vs-pan gesture disambiguation actually behaves before committing to the full build (zero prior `InteractiveViewer` usage in this codebase).
2. Entities + `SiteMapRepository`/`FakeSiteMapRepository`, no UI — manually verify the fake seed's `zoneId`/`wallId` cross-refs actually resolve against `FakeSiteRepository`.
3. `shape_hotspot.dart` + `hitBoundsFor()` in isolation — the riskiest geometry logic, worth getting right before wiring painters.
4. `geometric_canvas.dart` + `shape_painter.dart`, proved out first on Level 1 (simplest: no wall lines, no filter toggle).
5. `SiteMapPage`/`SiteMapCubit` wired into the existing `/overview` route — site list → Level 1 works end-to-end.
6. `BuildingMapPage`/`Cubit`, then `FloorMapPage`/`Cubit` (reintroduces `RoomSheet` unchanged, adds wall-line drawing + `RemainingFilterToggle`).
7. Delete `site_overview_page.dart`, `site_overview_cubit/state.dart`, `zone_tile.dart` once Level 3 fully replaces their behavior.
8. `flutter analyze` clean, then visual verification (Flutter web, per the pattern already used for the rest of this app) walking all 3 levels + a full room→wall→capture round trip.

## Explicitly deferred (state why, don't silently drop)

- **Raw CAD `geometry`/`layers` rendering** — out of scope; WallBase's own design philosophy (coverage over precision, "the map can be wrong") makes this low-value for field navigation specifically, versus the dashboard's editing use case where it matters more.
- **`wall_status_index` as a modeled entity** — deliberately not built; it would be a second, driftable source of truth for data the existing `SiteRepository`/local wall-status store already owns. A future real datasource should feed *that* system, not this one.
- **Quick-start / `mode: none` sites (Phase 6)** — those sites explicitly get a flat list UI per `FLUTTER_MOBILE_PLAN.md`, not a canvas; this plan doesn't touch that (unbuilt, separate phase), and the flat-grid pattern being retired here isn't fully dead — it's the *right* pattern there, just not for mapped sites.
- **Label decluttering at extreme zoom-out** (many small rooms, fully zoomed out) — needs an explicit hide/truncate-below-threshold policy eventually; not blocking a first working version.
- **Real datasource swap** (Dio-backed `SiteMapRepository` parsing actual downloaded `site_package.json`/`floor_{id}.json`) — out of scope for this plan (still fake-data, matching how the rest of the app was built); the entity shapes above are already field-matched to the real JSON specifically so that swap is straightforward later. Note for whoever does it: real backend ids are integers, every entity here uses `String` — convert at the parsing boundary.

## Verification

- `flutter analyze` clean (0 issues) — same bar the rest of the app already meets.
- Visual walkthrough on Flutter web (`flutter run -d web-server`, as already used earlier in this project): Sites list → tap a ready site → Level 1 (buildings) → tap a building → Level 2 (floors) → tap a floor → Level 3 (real room rectangles, correctly status-colored, wall lines visible) → tap a room → `RoomSheet` opens with the correct walls → tap a wall → `WallActionSheet` → capture button → existing grid-init/grid-capture flow still works unchanged.
- Confirm pinch-zoom/pan works at all 3 levels, and that a deliberately tiny room (seed data should include at least one) still has a comfortably tappable hit area with no visible overlap-stealing from its neighbor.
- Confirm `RemainingFilterToggle` dims but never removes/disables a `done` room's tap target.
- Confirm the two-floor building (`s1`) and one-floor building (`s2`) fake sites both render Level 2 correctly.
