# WallBase Mobile — Design System

Design source of truth for the WallBase Flutter app. Read alongside `CLAUDE.md` (architecture) and
`../Digitization-Platform/FLUTTER_MOBILE_PLAN.md` (features/phases). This file defines the visual
language so every screen — built now or later, by anyone — looks like one app.

## 1. Design context (why the system looks the way it does)

- **Outdoor, sunlit use.** Screens are read in direct sun at tomb/temple sites. Contrast and text
  size default toward the high end of normal, not the low end.
- **One-handed, gloved, dusty fingers.** Touch targets are generous everywhere, not just on
  primary actions. Nothing critical depends on precision tapping or hover/long-press-only affordances.
- **Single operator, task-focused, no chrome for chrome's sake.** No dashboards-for-dashboards'-sake,
  no decorative illustration. Every screen answers "what wall am I on and what do I do next."
- **Offline-first visual honesty.** Sync/connectivity state is always visible, never hidden behind
  a settings page — the operator must always know whether "captured" is confirmed or still local-only.
- **Consistency with the web dashboard.** The same wall status must render as the same color on
  mobile and on the dashboard map — the admin and the field operator are looking at the same truth.

## 2. Color

### 2.1 Brand seed

Material 3 tonal palette generated from a single seed color, in the same blue family the web
dashboard already uses for `captured`-status walls:

- **Seed / primary:** `#1D4ED8` (Tailwind blue-700) — deliberately a shade darker than the
  `captured` status blue (`#2563EB`, §2.2) so primary buttons/nav and the `captured` badge read as
  related but stay visually distinguishable when they appear side by side (e.g. a blue "Add more
  photos" button next to a blue `captured` chip on the same wall action sheet).

Generate the full `ColorScheme` from this seed via `ColorScheme.fromSeed(seedColor: ...)` (Material
3 default) rather than hand-picking every tonal step — hand-picked secondary/tertiary/surface tones
drift out of sync with each other over time.

### 2.2 Wall status colors — fixed, not derived

These are **not** part of the seeded tonal palette. They are a shared semantic contract with the
web dashboard (`resources/js/stores/canvasHelpers.js:statusColor`) and must stay byte-for-byte
identical on both platforms:

| Status | Hex | Swatch | Notes |
| :-- | :-- | :-- | :-- |
| `not_started` | `#6B7280` | gray | default/unset state |
| `in_progress` | `#D97706` | amber | at least one cell photographed, not all |
| `captured` | `#2563EB` | blue | full coverage saved, awaiting admin stitch/review |
| `done` | `#059669` | emerald | admin-verified; reopens to `captured` on new photos |
| `skipped` | `#64748B` | slate | manually marked inaccessible/skipped |

Define these as a `WallStatusColors` extension/const map in `core/theme/`, never inline hex in
feature code (SSOT — see CLAUDE.md's SOLID/DIP rule: widgets depend on this token set, not literals).

### 2.3 Semantic roles (beyond Material's defaults)

| Token | Purpose |
| :-- | :-- |
| `onSurfaceMuted` | secondary text, timestamps, helper captions |
| `outlineSubtle` | hairline dividers, card borders |
| `successContainer` / `onSuccessContainer` | sync-confirmed banners, "Ready for field" badge |
| `warningContainer` / `onWarningContainer` | low battery, low storage, save-partial warnings |
| `dangerContainer` / `onDangerContainer` | destructive confirmations (delete cached site) |
| `offlineIndicator` | persistent offline/online status chip in the app bar |

### 2.4 Light theme vs. outdoor high-contrast theme

Ship two `ThemeData` variants (Phase 8's "high-contrast outdoor UI theme" candidate — build the
token structure now so adding the second theme later is a values swap, not a rewrite):

- **Standard:** Material 3 light scheme from the seed above.
- **Outdoor/high-contrast:** same hue relationships, pushed to higher contrast — darker text on
  lighter surfaces, saturated status colors, no color used below WCAG AA (4.5:1) against its
  background. No dark/night theme is needed for v1 — this is a daylight-only field tool.

Toggle lives in Settings; default theme choice can also be inferred from ambient light later, but
v1 is a manual toggle only.

## 3. Typography

Base font: **Figtree** (via `google_fonts`), matching the web dashboard's `fontFamily.sans`. Fall
back to the platform default sans if the font asset can't load — never block render on a font fetch
offline; bundle the font file locally rather than relying on `google_fonts`' runtime download.

| Style | Size / weight | Usage |
| :-- | :-- | :-- |
| `displaySmall` | 28 / 600 | site name on site overview |
| `titleLarge` | 22 / 600 | screen titles (building, floor) |
| `titleMedium` | 18 / 600 | section headers, wall action sheet title |
| `bodyLarge` | 16 / 400 | primary content, form fields, notes |
| `bodyMedium` | 14 / 400 | secondary content, list rows |
| `labelLarge` | 14 / 600 | button labels |
| `labelSmall` | 12 / 600 | status badges, cell coordinate labels (`R2C3`) |

Rules:
- Never hardcode a font size outside this scale — extend the scale if a real need appears.
- Respect system text-scale factor up to at least 130% without clipping or overlap (test at 1.3×).
- Status badge and cell-label text (`labelSmall`) always paired with a shape/icon, never color alone
  (colorblind-safe — see §7).

## 4. Spacing, radius, elevation

- **Spacing scale (4pt base):** `4, 8, 12, 16, 24, 32, 48` — define as `AppSpacing.xs..xxl` consts
  in `core/theme/`. Page horizontal padding defaults to `16`; section gaps default to `24`.
- **Radius scale:** `8` (chips, badges), `12` (cards, buttons, sheets), `24` (bottom sheet top
  corners). No sharp (`0`) corners in v1 — softens the otherwise dense, data-heavy screens.
- **Elevation:** keep flat (elevation 0–1) for in-page cards; use elevation only for things that
  float above content — bottom sheets, dialogs, the persistent capture FAB, snackbars.

## 5. Iconography & motion

- Icon set: Material Symbols (rounded), 24dp default, 20dp inline-with-text, 32dp for the primary
  capture action. No custom icon font for v1 — a rounded grid/camera glyph pair is the only
  candidate for a custom icon (grid-cell coverage icon), added only if Material's set proves
  insufficient once Phase 3 screens are actually built.
- Motion: short and functional only — 150–200ms standard Material easing for sheets/dialogs, no
  decorative animation. Haptic feedback (Phase 8) fires on: cell-photo captured, full coverage
  reached, sync confirmed — never on simple navigation.

## 6. Layout & responsiveness

Primary target is a single phone in portrait, but every page must degrade gracefully to larger
phones, foldables, and landscape (a site visit doesn't wait for the "right" device):

- No fixed pixel widths/heights on any page-level widget — use `LayoutBuilder`/`MediaQuery` per
  CLAUDE.md's responsiveness rule.
- Breakpoint used only where a layout genuinely reflows (not just scales): `< 600` logical px =
  compact phone layout (single column, bottom sheet actions); `≥ 600` = wide layout (side-by-side
  panel for e.g. floor canvas + room list instead of a bottom sheet). Most screens need only the
  compact layout for v1 — don't build the wide variant speculatively before a screen needs it.
- Grid capture screen and floor canvas use `CustomPainter`/`InteractiveViewer`, sized to available
  space via `LayoutBuilder`, never a hardcoded aspect ratio.
- Lists that mix a header, a filter row, and a scrolling body use `CustomScrollView` with slivers
  (`SliverAppBar`/`SliverToBoxAdapter`/`SliverList`) rather than a fixed header + inner scroll view.
- Minimum touch target: **48×48dp**, no exceptions — this is a gloved-finger, outdoor tool.

## 7. Component inventory

Organize implementations per CLAUDE.md: shared/generic ones in `core/widgets/`, screen-specific
ones in that feature's `presentation/widgets/`.

### 7.1 Shared components (`core/widgets/`)

| Component | Notes |
| :-- | :-- |
| `PrimaryButton` / `SecondaryButton` / `DangerButton` | full-width by default on mobile forms |
| `StatusBadge` | wall/aggregate status → color (§2.2) + icon + label, never color-only |
| `OfflineBanner` | persistent, dismissible-never, shown whenever no confirmed connectivity |
| `SyncPendingChip` | small inline indicator on any record not yet server-confirmed |
| `EmptyState` | icon + message + optional action, used for empty lists everywhere |
| `LoadingIndicator` | full-screen and inline variants; no bare `CircularProgressIndicator` in feature code |
| `ErrorRetryView` | message + "Retry" — standard shape for any repository failure surfaced to UI |
| `ConfirmDialog` | for destructive actions (delete cached site, discard session) |
| `SectionHeader` | label + optional trailing action, used above list groups |
| `SwipeableListTile` | base for sync queue / unassigned-wall list rows |

### 7.2 Feature components (representative — not exhaustive; extend per screen as built)

| Screen (Phase) | Component | Key states |
| :-- | :-- | :-- |
| Sites list (P1) | `SiteCard` | not-downloaded / downloading (progress) / ready (green "Ready for field") / update-available badge |
| Site overview (P2) | `BuildingZoneShape` | colored by aggregate status (§2.2), tap target ≥48dp regardless of drawn shape size |
| Floor canvas (P2) | `RoomShape`, `StatusLegend`, `RemainingFilterToggle` | legend always visible when filter is active |
| Room sheet (P2) | `WallRow` | name, `StatusBadge`, last-capture thumbnail, chevron |
| Wall action sheet (P2) | `WallActionSheet` | capture button label swaps "Start capture" ↔ "Add more photos" per §4 of the mobile plan — never disabled |
| Grid init (P3) | `GridSizePicker` | presets (2×2/3×3/4×3) + custom stepper, live cell-count validation (max 100) |
| Grid capture (P3) | `GridCell` | empty / has-N-photos (count badge) / current-selection outline |
| Camera capture (P3) | `CaptureOverlay` | persistent cell label (`R2C3`), shutter, exposure-lock indicator, thumbnail strip with delete/retake |
| Coverage review (P4) | `CoverageThumbnailGrid`, save vs. save-partial buttons | save enabled only at 100% coverage; save-partial always enabled with warning style |
| Unassigned walls (P5) | `UnassignedWallCard` | local-ID badge, required-note indicator, photo count |
| Sync status (P7) | `SyncQueueItem` | queued / uploading (progress) / confirmed / failed-retry, ordered by the priority in Phase 7 |

## 8. Feedback & system states

Every screen that loads data must implement all four states explicitly — no bare spinners with no
error path, no silent empty lists that look like "still loading":

1. **Loading** — `LoadingIndicator`
2. **Empty** — `EmptyState` with a clear next action ("Prepare a site to get started")
3. **Error** — `ErrorRetryView`, always with Retry; never a raw exception string
4. **Content** — the real screen

Sync/connectivity feedback is layered on top of this, not a replacement for it: a screen can be in
"Content" state while also showing `OfflineBanner` and per-item `SyncPendingChip`s.

## 9. Accessibility

- Color is never the only signal for status — pair with icon + text label (§2.2, §7.1).
- Minimum 48×48dp touch targets; minimum body text 14pt at 1.0× scale, verified readable at 1.3×.
- Contrast ≥ 4.5:1 for body text in both themes; outdoor theme targets closer to 7:1 where feasible.
- All primary actions reachable one-handed in the lower 2/3 of the screen (thumb zone) — avoid
  putting the sole path to "capture" in a top app bar.

## 10. Implementation mapping (ties to CLAUDE.md)

- Tokens (color, type scale, spacing, radius) live in `core/theme/` as const classes / a
  `ThemeExtension`, consumed via `Theme.of(context)` — never redefined per-feature.
- `StatusBadge` and the wall-status color map are the single place §2.2's five colors are encoded;
  every status-aware widget (canvas shapes, list rows, chips) reads from it.
- Two `ThemeData` instances (§2.4) registered in `app.dart`, switched via a `ThemeCubit` in `core/`
  (or a simple `ValueNotifier` if a full cubit is overkill for a single boolean toggle).

## 11. Open items (resolve before Phase 2 UI work starts)

- Confirm Figtree is acceptable to bundle as a local font asset (license permits it — Figtree is
  OFL-licensed, so this is a formality, not a blocker).
- Decide whether the outdoor high-contrast theme ships in v1 or stays a Phase 8 add-on as originally
  scoped in the mobile plan — this doc assumes the latter (tokens ready, second theme deferred).
