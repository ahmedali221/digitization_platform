# Capture Quality Indicator — Implementation Report

Real-time, heat-colored feedback telling the operator whether the photo they
just took will actually stitch with its neighbours. Full spec:
`../Stitch/capture-quality-feature-spec.pdf`. Reference implementation for
the scoring math: `../Stitch/stitch.py` (the batch CLI the backend runs).

Status: **implemented, wired into the real capture flow, and validated
against real sample photos on both Windows desktop and an Android
emulator.** `flutter analyze` is clean project-wide.

---

## 1. What it does

While the operator captures a wall/mural cell by cell, each shot gets a
0–100 score and a color the instant it's useful:

| Score | Color | Meaning |
|---|---|---|
| 0–39 | 🔴 Red | Bad — retake |
| 40–59 | 🟠 Orange | Weak — usable as a last resort |
| 60–79 | 🟡 Yellow | Acceptable — will probably work |
| 80–100 | 🟢 Green | Good — move on |

Scoring runs in three depth tiers, each reusing logic ported directly from
`stitch.py`'s `Stitcher` class:

- **Tier 1 — per-image SIFT score.** Runs the instant a photo is saved,
  before any neighbour exists. Keypoint density (per megapixel), spatial
  distribution (occupied cells in a 4×4 grid), edge-strip keypoint density
  on whichever sides this cell's grid position actually has a neighbour on,
  sharpness (Laplacian variance), contrast (grayscale std dev).
- **Tier 2/3 — neighbour matching + RANSAC.** Runs once both this cell and
  a grid-adjacent cell have a photo. Lowe-ratio-tested SIFT matches
  (`BFMatcher.knnMatch`), RANSAC-filtered inliers
  (`findHomography`/`estimateAffine2D`), and the direction/scale sanity
  check (`check_direction`) — generalized from stitch.py's right/below-only
  pair to all four directions.
- **Tier 4 — wall preview heat overlay.** Reuses the existing "review
  coverage" preview compositor; adds a translucent heat tint per scored
  cell and a colored line along each scored shared edge.

Combined cell score = 40% image score + 60% neighbour score (spec §3),
or just the image score until a neighbour exists. The single lowest-scoring
contributing metric drives a human-readable failure message (spec §6),
shown only for red/orange results.

Every threshold and weight lives in `CaptureQualityConfig` — nothing is
hardcoded, per the spec's explicit instruction that real cut-offs can only
be set after testing on real device captures.

---

## 2. Architecture

```
lib/features/grid_capture/
  domain/
    entities/capture_quality.dart        QualityTier enum, ImageQualityMetrics,
                                          NeighbourMatchMetrics, CellQualityResult
                                          (pure Dart, zero Flutter dependency)
    services/
      capture_quality_config.dart        every tunable threshold/weight
      capture_analyzer.dart              the ported Stitcher: SIFT, BFMatcher,
                                          findHomography/estimateAffine2D,
                                          check_direction — via opencv_dart
      grid_preview_composer.dart         (existing file, extended) Tier 4 heat overlay
  data/
    models/cell_quality_record.dart      Hive persistence (spec §8's raw-metrics JSON)
    mappers/cell_quality_mapper.dart     CellQualityResult <-> CellQualityRecord
    repositories/grid_capture_repository_impl.dart   (extended) getCellQuality/recordCellQuality
  presentation/
    theme/quality_tier_meta.dart         heat colors (spec §5's exact hex values)
    widgets/quality_badge.dart           QualityBadge (full badge) + QualityDot (dense contexts)
    cubit/capture_session_cubit.dart     (extended) triggers analysis on capture/delete
    pages/camera_capture_page.dart       (extended) shows the active cell's badge
    pages/coverage_review_page.dart      (extended) feeds quality into the Tier 4 preview
    widgets/grid_cell_tile.dart,
    widgets/camera_grid_navigator.dart   (extended) per-cell heat dot
```

**Why `QualityTier` is split across two files:** the enum and the 0–100→tier
banding function live in the domain entity (pure Dart — needed by
`capture_analyzer.dart`, which must stay runnable outside the Flutter
engine for testing). The `Color` mapping lives in a separate
presentation-layer file, since only grid_capture needs it — unlike
`WallStatus`, which several features share and rightly lives in
`core/theme/`.

**Why quality data isn't a field on `GridCell`:** `WallEntity`/`GridState`/
`GridCell` (`core/domain/entities/wall.dart`) are shared across features
(map_navigation, site_backup, ...) via `SiteRepository`. Quality is
grid_capture's own concern — it's carried on `CaptureSessionCubit`'s own
state (`cellQuality: Map<int, CellQualityResult>`) and persisted through
`GridCaptureRepository.getCellQuality`/`recordCellQuality`, never touching
the shared entity.

**Isolate dispatch:** `CaptureSessionCubit._analyzeCellQuality` calls
`compute(analyzeCellQuality, request)` — same pattern the existing
`grid_preview_composer.dart` already used for its own isolate work. Runs
fire-and-forget after `takePhoto()`/`deletePhoto()` (never blocks the
shutter), and cascades one level to already-captured neighbours whose
Tier 2/3 the new photo could newly satisfy.

---

## 3. The native dependency: `opencv_dart`

Flutter has no built-in SIFT/RANSAC. `stitch.py`'s Tier 1–3 logic depends
entirely on OpenCV, so faithfully porting it required a real OpenCV
binding — not a hand-rolled approximation, which would have violated the
spec's explicit "don't build a second SIFT system" / "same SIFT config as
backend... consistency matters more than tuning this in isolation" rule.

`opencv_dart` (backed by `dartcv4`) was added — it wraps the same
underlying OpenCV C++ core `stitch.py` calls from Python, so mobile scores
stay numerically consistent with the backend's own `--audit`. This was the
one architecture decision put to you (the user) before implementation
began, given it's a real native dependency with build-time cost.

Configured in `pubspec.yaml`:

```yaml
hooks:
  user_defines:
    dartcv4:
      include_modules: [imgproc, imgcodecs, features2d, calib3d]
      android:
        ndk_version: "26.3.11579264"
```

---

## 4. Correctness — proven, not assumed

Two purpose-built test harnesses run the *real* `analyzeCellQuality`
function (the exact code the app dispatches via `compute()`) against the
real sample wall in `Stitch/img/`:

- **`test/manual/capture_analyzer_field_check.dart`** — runs on Windows
  desktop (`flutter test ... -d windows`). `opencv_dart` supports desktop
  targets too, so this validates the actual algorithm fast, with no
  emulator involved.
- **`integration_test/capture_analyzer_device_test.dart`** — runs *on* an
  Android device/emulator via the `integration_test` package. Reads the
  sample photos from `/data/local/tmp/stitch_img/img` (pushed via
  `adb push`), so it exercises the real Android-built native library
  against real capture photos — not the emulator's synthetic camera feed.

**Ground truth:** `python stitch.py -f img --audit-only` was run directly
against the same `img/` folder for a side-by-side numeric comparison.
Along the way this caught a real finding: the manifest's default
`--manifest-axes row_colR` disagrees on all 37 claimed adjacencies (a
systematic below↔right swap) — `--manifest-axes col_row` is the correct
reading for this specific sample data (confirmed: 37/37 agree, "every
claimed adjacency checks out"). Both test harnesses use `col_row`.

**Result — both platforms, identical:**

- 24/24 cells scored, all green.
- **74/74 (100%) direction-check agreement** — every measured join agrees
  with the manifest's claimed adjacency.
- Numbers match `stitch.py`'s own output *exactly* where directly
  comparable, e.g. cell-806→cell-807: `dx=+121 dy=+40 inliers=7002` on
  both sides of the port.

This is what "don't build a second SIFT system" actually cashes out to: if
the two ever disagreed, that would be a bug, not two implementations that
happened to differ — and right now they don't disagree.

One real bug *was* found and fixed during this validation: failure-reason
messages were showing up on green (90+) cells whenever a single
neighbour's scale ratio was marginally outside `[0.5, 2.0]` (e.g. 0.47),
even though the cell was clearly fine overall. Spec §6 says "a red or
**orange** result should say why" — not green. `pickFailureReason` now
gates on the cell's own tier, not on individual boolean pass/fail
components in isolation.

---

## 5. Real on-device performance data (spec §9)

The Android emulator run produced actual timing per cell — directly the
kind of measurement spec §9 asks "the developer" to make before deciding
where Tier 1 vs Tier 2/3 should run:

| | |
|---|---|
| Cells measured | 24 |
| Total (Tier 1 + all available Tier 2/3 neighbours, combined) | 312.9s |
| Average per cell | 13.0s |
| Range | 4.6s (1 neighbour) – 31.4s (4 neighbours) |

Caveats that matter before treating these as final numbers: **debug
build** (no compiler optimizations) on an **x86_64 emulator** (not real
hardware) — both push this toward a worst case, not a representative
one. Tier 1 and Tier 2/3 weren't timed separately in this pass.

Even so, this is well over the "well under a second" budget the spec sets
for Tier 1 alone — which matches the spec's own suspicion that Tier 2/3 is
too heavy to run synchronously on-device. It's exactly why
`CaptureSessionCubit` already dispatches analysis via `compute()` as
fire-and-forget rather than awaiting it before re-enabling the shutter —
the capture flow never blocks on this regardless of how long scoring
takes. Whether Tier 2/3 should eventually move to a backend call (the
spec's own "working assumption") is still the open call spec §9 asks for;
what changed today is that there's now a real number to make that call
with, instead of a guess.

---

## 6. Two native build bugs found and fixed

Neither was in this app's own code — both were environment/upstream
`opencv_dart`/`dartcv4` build configuration issues, discovered by chasing
"native symbol not found" and linker errors down to their root cause
rather than working around the symptom.

1. **Missing modules.** `dartcv4` excludes `calib3d` and `features2d` from
   its native build *by default* — only `imgproc`+`imgcodecs` ship. SIFT,
   `BFMatcher`, `findHomography`, `estimateAffine2D` all live in those two
   excluded modules, so their native symbols were never compiled in at
   all. Surfaces at runtime, not build time
   (`Couldn't resolve native function 'cv_SIFT_create_2'`). Fixed by
   declaring `include_modules` in `pubspec.yaml`'s `hooks.user_defines`.

2. **NDK version.** The highest installed NDK (29.0.14206865) fails
   CMake's own C-compiler sanity check on this machine — `clang`/`lld`
   can't find `crtbegin_dynamic.o`/`-lc`/`-lm`/`-latomic` in its own
   sysroot. NDK 27.0.12077973 gets past that and compiles OpenCV cleanly,
   but then fails the *final link* with hundreds of undefined libc++
   symbols (`__cxa_throw`, `recursive_mutex`, `operator new[]`, ...) — a
   known NDK r27 libc++-linking regression also reported in other native
   build ecosystems (e.g. React Native). NDK 26.3.11579264 has neither
   problem. Pinned the same way, via `hooks.user_defines.dartcv4.android.
   ndk_version`.

Both fixes are config-only (`pubspec.yaml`), documented in place, and
apply regardless of which machine builds this project next — though a
different machine's installed NDK set could still need a different pin;
if a future `flutter run`/`build` fails the same way, this section is
where to look first.

---

## 7. Known limitations / natural follow-ups

- **Normalization anchors are starting points, not calibrated values.**
  `keypointDensityFullScore`, `sharpnessFullScore`, `contrastFullScore`,
  etc. in `CaptureQualityConfig` are reasonable defaults, not numbers
  measured against a field-calibration pass — exactly what spec §3/§9
  expect to happen next, now that the pipeline itself is proven correct.
- **Tier 1/2/3 timing wasn't split apart.** The 13s/cell average bundles
  both; a follow-up pass timing them separately would give a cleaner
  answer to spec §9 Q1–3.
- **Tier 2/3 still runs entirely on-device.** Functionally complete and
  already async/non-blocking, but the spec's own suspicion (and the
  timing data above) suggests a backend path may still be worth building
  for battery/thermal reasons on a real, sustained capture session — no
  backend exists in this workspace to wire that up against yet.
- **`android/app/build.gradle.kts`'s `ndkVersion`** was reverted to
  `flutter.ndkVersion` (its original default) — it doesn't control
  `dartcv4`'s own native-assets build (that's the separate pubspec.yaml
  hook), and leaving it pinned was only adding a spurious plugin-version
  warning.

---

## 8. How to re-run the validation

```bash
# Fast, no emulator — runs the real analyzer against Stitch/img/ on this machine
flutter test test/manual/capture_analyzer_field_check.dart -d windows

# On a connected Android device/emulator, using the real sample photos
adb push "../Stitch/img" /data/local/tmp/stitch_img
flutter test integration_test/capture_analyzer_device_test.dart -d <device-id>

# Ground truth, for comparison
cd ../Stitch && python stitch.py -f img --audit-only --manifest-axes col_row
```
