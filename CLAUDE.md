# WallBase Mobile — Architecture & Coding Conventions

Flutter field-capture app for WallBase. Full functional spec (phases, data model, API contract)
lives in the sibling repo: `../Digitization-Platform/FLUTTER_MOBILE_PLAN.md`. This file governs
*how* code is written here; that file governs *what* gets built.

## Architecture: MVVM, feature-first

- **View** — a `Page` widget (`*_page.dart`). Builds UI only, reads state via `BlocBuilder` /
  `BlocConsumer` / `BlocSelector`. No business logic, no direct repository/Dio calls.
- **ViewModel** — a `Cubit` (default) or `Bloc` (only when a feature genuinely needs discrete
  events, not just state transitions) per screen/feature slice. Calls repositories, exposes state.
- **Model** — data flows through the **repository pattern**: an abstract repository (contract) in
  `domain/`, implemented in `data/` against remote (`dio`) and/or local (Hive) data sources.
  Cubits depend on the abstract repository, never on `Dio`/Hive directly.

Dependency direction: `presentation → domain ← data`. Presentation never imports `data/` directly.

## Folder structure (feature-first)

```
lib/
  main.dart                     bootstrap: DI init, run app
  app.dart                      MaterialApp.router, theme, global providers

  core/                         cross-cutting, not feature-specific
    di/                         get_it setup (injection_container.dart), registered per feature
    router/                     go_router config, route names, guards
    network/                    Dio client + interceptors, API base config
    theme/                      colors, text styles, spacing tokens
    utils/                      pure helpers, extensions
    errors/                     failure/exception types shared across features
    widgets/                    shared, reusable, custom components (buttons, loaders,
                                 empty states, form fields) used by 2+ features

  features/
    <feature_name>/              e.g. site_sync, map_navigation, grid_capture,
                                  unassigned_walls, quick_start, sync_queue
      data/
        models/                  DTOs / Hive adapters
        datasources/             remote_data_source.dart (dio), local_data_source.dart (hive)
        repositories/            concrete repository implementation
      domain/
        entities/                (only if they diverge meaningfully from models)
        repositories/            abstract repository contract
      presentation/
        cubit/                   <feature>_cubit.dart + <feature>_state.dart
        pages/                   route-level screens only
        widgets/                 widgets used ONLY within this feature — never imported
                                 by another feature (promote to core/widgets/ if reused)
```

One cubit per cohesive screen/responsibility — don't merge unrelated concerns into one cubit
(SRP). Split further only when a screen's state genuinely branches into independent pieces.

## Stack

| Concern | Package |
| :-- | :-- |
| State management | `flutter_bloc` (Cubit by default, Bloc for event-driven flows) |
| Navigation | `go_router` |
| HTTP | `dio` |
| DI | `get_it` (service locator, initialized once in `core/di`) |
| Local storage | `hive` / `hive_flutter` (see data model in FLUTTER_MOBILE_PLAN.md §3) |
| Camera | `camera` |
| Background sync | `workmanager`, `connectivity_plus` |

## Widget separation rule

Never write widget trees inline in a page beyond simple layout composition. Extract anything with
its own responsibility (a list item, a card, a form section, a capture cell) into a named widget:

- Reused only inside one feature → `features/<feature>/presentation/widgets/`
- Reused across features, or generic enough to be app-agnostic → `core/widgets/`

Pages should read like a table of contents of widgets, not a wall of `Column`/`Container` nesting.

## Responsiveness

Every page and component must be responsive — no screen assumes a fixed device size:
- Use `LayoutBuilder` / `MediaQuery` / `OrientationBuilder` for breakpoint-sensitive layout, not
  hardcoded pixel widths/heights.
- Prefer `Expanded`/`Flexible`/`Wrap`/`FractionallySizedBox` over fixed sizing.
- Wrap scrollable content with `Sliver`-based widgets (`CustomScrollView`, `SliverList`,
  `SliverGrid`, etc.) where a page mixes scroll behaviors (e.g. header + grid + list) instead of
  nesting `SingleChildScrollView` + fixed-height children.
- Always respect `SafeArea` and text scaling (don't clip text that grows with system font size).

## SOLID / clean code, applied concretely

- **SRP** — one cubit per screen concern; one repository per aggregate; widgets do one visual job.
- **OCP** — add new capture flows / data sources by adding a new class implementing the existing
  repository contract, not by branching inside an existing implementation.
- **LSP** — any repository implementation (real, fake, in-memory for tests) must be swappable
  behind its abstract contract without the cubit caring which one is injected.
- **ISP** — keep repository interfaces narrow and scoped to one feature's needs; don't create one
  giant `AppRepository`.
- **DIP** — cubits/widgets depend on abstractions (`SiteRepository`, not `DioClient` or `Box`),
  wired via `get_it`.

Clean, humanized code:
- Descriptive names over comments — a well-named method/variable should make a comment redundant.
- Small functions/methods, guard clauses over deep nesting, no magic numbers/strings (name them).
- No dead code, no commented-out blocks, no speculative abstractions for hypothetical future needs.
- Comments only for non-obvious *why* (a workaround, a hidden constraint) — never for *what*.

## Design system

Colors, typography, spacing, component inventory, and states are specified in `DESIGN_SYSTEM.md`
(same folder). Theme tokens defined there belong in `core/theme/` — no hardcoded hex/font-size/
spacing values in feature code.

## Reference

Feature list, build phases, local data model, wall status machine, and the full API contract are
in `../Digitization-Platform/FLUTTER_MOBILE_PLAN.md`. Build in phase order (0 → 1 → 2 → ...);
each phase there maps to one or more `features/` modules here.
