# Dashboard ↔ Mobile Wiring — Change Log

What changed to connect the Laravel dashboard and the Flutter mobile app, and move the
mobile app from a UI-only scaffold to a real local-first client. Organized by system, then
by area. Verified: `php artisan test` (90/90) on the dashboard, `flutter analyze` (clean) and
`flutter test` (10/10) on mobile, and live-checked against the deployed dashboard at
`https://digital.niletechdev.com`.

---

## Dashboard (`dashboard/`)

### Fixed: token issuance was unreachable

`POST /api/tokens` used to sit inside the `auth:sanctum` middleware group and mint a token
from `$request->user()` — but a mobile client has no prior session or token, so it could
never reach it. There was no public, credential-based login route anywhere.

- **`app/Http/Requests/Api/LoginRequest.php`** (new) — validates `email`/`password`/
  `device_name`, resolves the user via `Hash::check()` (not `Auth::attempt()`, since this
  route is stateless), with the same rate-limiting/lockout behavior as the web login form.
- **`app/Http/Controllers/Api/AuthController.php`** — `createToken()` renamed to `login()`,
  now takes `LoginRequest` and mints the token from the request's resolved user instead of
  `$request->user()`.
- **`routes/api.php`** — `POST /tokens` moved out of the `auth:sanctum` group to public
  scope (still under Laravel's default `api` throttling).
- **`tests/Feature/ApiAuthTest.php`** — rewritten to hit `/api/tokens` with real credentials
  and no `Sanctum::actingAs` (the old test bypassed the exact bug being fixed); added
  invalid-credentials and missing-device-name cases.

### Added: site listing endpoint

The app had no way to discover which sites exist before already knowing a site ID.

- **`app/Http/Controllers/Api/SiteController.php`** (new) — `GET /sites` (added to
  `routes/api.php` inside the existing `auth:sanctum` group): lists every site with its
  latest package version/status/published-at, or `null` if nothing's published yet.
- **`tests/Feature/ApiSiteListingTest.php`** (new) — auth-gating, null/populated/
  in-progress package states.

### Fixed: package/photo files were served as direct, unauthenticated storage links

Package files (`site_package.json`, `floor_{id}.json`) and canvas background images were
served as plain `Storage::disk(...)->url()`/`temporaryUrl()` links — publicly downloadable
by anyone with the URL, no token required. On the live host (Hostinger), direct requests to
these `/storage/...` paths get **403'd by the hosting provider's edge/WAF layer** regardless
of file permissions (confirmed live: the file is readable directly on disk and via `cat`
through the `public/storage` symlink, but every direct HTTP request to it — GET or HEAD, with
or without their CDN toggle on — comes back 403 from Hostinger's `hcdn` edge, which isn't
configurable from the visible hPanel settings). Rather than depend on a hosting-provider
setting outside the app's control, these files now flow through authenticated API routes
instead of direct storage links — which also closes the "no token required" gap.

- **`app/Http/Controllers/Api/SitePackageController.php`** — added `packageFile()`: streams
  one file (`site_package` / `floor_{id}`) of a site's latest published package via
  `Storage::disk(...)->response($path)`.
- **`app/Http/Controllers/Api/FileProxyController.php`** (new) — generic authenticated proxy
  for canvas background images, scoped strictly to the `canvas-backgrounds/` prefix and
  rejecting any `..` in the client-supplied path.
- **`app/Services/SitePackagePublisher.php`** — `resolveFileUrls()` now returns
  `/api/sites/{site}/package-files/{key}` URLs instead of direct storage links; added
  `resolveFilePath()` for the controller to resolve the on-disk path for a given key.
- **`app/Services/SitePackageBuilder.php`** — `resolveBackgroundUrl()` now rewrites
  `/storage/...` background URLs to `/api/files?path=...` proxy URLs.
- **`routes/api.php`** — added `GET /sites/{site}/package-files/{key}` and `GET /files`
  (both inside the `auth:sanctum` group).
- **`tests/Feature/ApiPackageFileProxyTest.php`**, **`tests/Feature/ApiFileProxyTest.php`**
  (new) — auth-gating, streamed content, unknown key / missing file / path-traversal /
  wrong-prefix all 404. **`tests/Feature/CanvasBackgroundTest.php`** — added a case
  confirming a published background URL is now a proxy URL, not a raw storage link.

Note: background image URLs are baked into the published JSON at publish time, so existing
published packages need a **republish** to pick up the new proxy URLs — package/floor file
URLs themselves are unaffected since those are computed fresh on every `GET
/sites/{id}/package` call.

### Added: wall name in the published bundle

`floor_{id}.json`'s `rooms[].walls[]` entries carried `id, wall_id, edge, x1/y1/x2/y2` but
no name, even though `Wall.name` exists in the database — the mobile app has nothing to
label a wall with otherwise.

- **`app/Services/SitePackageBuilder.php`** — added `'name' => $wallShape->wall?->name` to
  both the manually-drawn and auto-layout wall-shape code paths; added `wallShapes.wall` to
  the eager-load list to avoid N+1.

No other dashboard changes — the sync endpoints (`/sync/unassigned`, `/sync/mappings`,
`/sync/sessions(+confirm)`, `/walls/{wall}/captures`, `/sites/{site}/publish(+status)`,
`/sites/{site}/package`) already existed and needed nothing.

---

## Mobile app (`mobile-app/`)

Previously a UI-only scaffold: every repository was an in-memory fake, and `dio`/`hive`
were declared dependencies with zero lines of real networking or persistence anywhere.

### Dependencies (`pubspec.yaml`)

Added `connectivity_plus`, `workmanager`, `flutter_secure_storage`, `crypto`, `uuid`,
`disk_space_plus`; dev: `hive_generator`, `build_runner`.

### Networking (`lib/core/network/`)

- `api_config.dart` — base URL (defaults to `https://digital.niletechdev.com`, overridable
  via `--dart-define=API_BASE_URL=...`).
- `api_endpoints.dart` — path constants for every dashboard route.
- `auth_interceptor.dart` — attaches the stored bearer token; clears the session on a real
  401, **never** on a network/timeout error (so a field operator with no signal stays
  logged in).
- `api_client.dart` — the app's singleton `Dio`.
- `session_notifier.dart` — shared `isLoggedInNotifier` the router and auth feature read/write.
- `connectivity_observer.dart` — wraps `connectivity_plus` as `Stream<bool>`.
- `file_downloader.dart` — `Dio.download()` wrapper with skip-if-already-downloaded (by
  size, since the package manifest carries no per-file checksum).

### Errors (`lib/core/errors/`)

- `failure.dart` — `NetworkFailure` / `ServerFailure` / `ValidationFailure` (matches the
  documented `{message, errors}` 422 shape) / `UnauthorizedFailure`.
- `dio_failure_mapper.dart` — the one place `DioException` gets turned into a `Failure`.

### Local storage (`lib/core/storage/`)

- `hive_boxes.dart` — registers every Hive adapter, opens every box (`sites`, `floors`,
  `wall_status`, `sessions`, `unassigned`, `sync_queue`, `field_notes`, `id_mappings`,
  `device`).
- `secure_token_storage.dart` — the bearer token, in secure storage (not Hive).
- `device_id_provider.dart` — stable per-install UUID.
- `directory_manager.dart` — `packages/{site_id}/`, `sessions/{wall_id}/`,
  `backup/{wall_id}/`, `thumbs/`; also wraps `disk_space_plus` for the storage watchdog.

### Real `SiteRepository` (site discovery, download, local-first reads)

- `lib/core/data/models/` — `site_package_record.dart` (catalog metadata **and** the
  downloaded bundle, in one record), `floor_package_record.dart`, `wall_status_record.dart`
  (the actual local source of truth for status), `id_mapping_record.dart`,
  `hive_type_ids.dart`.
- `lib/core/data/datasources/site_local_data_source.dart` — pure Hive CRUD, plus
  locally-added-wall support for the existing "Add wall" flow.
- `lib/core/data/datasources/site_remote_data_source.dart` — `GET /sites`,
  `GET /sites/{id}/package`.
- `lib/core/data/mappers/site_mapper.dart` — turns the real backend JSON (verified against
  `SitePackageBuilder.php` directly, not just the planning docs) into the existing
  `SiteEntity`/`BuildingEntity`/`FloorEntity`/`WallEntity` — unchanged entity shapes. Local
  wall status always wins over whatever's frozen in a downloaded bundle.
- `lib/core/data/repositories/site_repository_impl.dart` — the real implementation, swapped
  in over `FakeSiteRepository` in DI. Added two contract methods:
  `estimateDownload`/`deleteCachedSite`/`refreshCatalog` (on `SiteRepository`, implemented
  in both the real and fake repositories).
- **Deleted**: `lib/features/site_sync/domain/repositories/site_repository.dart` and its
  fake — a duplicate of the `core/` version with zero real importers.

### Site download flow (`lib/features/site_sync/`)

- `domain/services/site_download_service.dart` — fetches the manifest, downloads
  `site_package.json` + every `floor_{id}.json` + every background image, persists
  everything locally, only then marks the site ready. Uses the app's one authenticated
  `Dio` throughout (an earlier "raw"/unauthenticated second `Dio` instance was removed
  entirely) — package/floor/image URLs are now authenticated `/api/...` proxy routes on
  the dashboard, not direct storage links, so every request needs the bearer token.
- `presentation/widgets/download_confirm_dialog.dart` — the pre-download "N files, N MB —
  download?" summary, wired into `sites_list_page.dart`'s download button.
- `presentation/cubit/sites_cubit.dart` — now calls `refreshCatalog()` on load and uses
  real `ConnectivityObserver` instead of a hardcoded offline flag.

### Auth (`lib/features/auth/`, new feature)

- `domain/repositories/auth_repository.dart`, `data/datasources/auth_remote_data_source.dart`,
  `data/repositories/auth_repository_impl.dart` — login/logout, local-only session check.
- `presentation/cubit/login_cubit.dart` + `presentation/pages/login_page.dart` — a plain
  email/password screen (single-operator app, no registration flow).
- `lib/core/router/app_router.dart` — added `/login`, gated every other route behind
  `isLoggedInNotifier`.

### Real capture-session persistence (`lib/features/grid_capture/`)

- `data/models/capture_session_record.dart` — one record per wall (reused across capture
  rounds, including later top-up captures on an already-`done` wall), holding grid
  dimensions and every cell's photos with checksums.
- `data/datasources/capture_session_local_data_source.dart` — Hive CRUD for that.
- `data/datasources/grid_capture_local_data_source.dart` (extended) — saves each shot,
  immediately copies it to a backup directory before anything else happens, computes its
  sha256, atomically writes the completion manifest.
- `data/repositories/grid_capture_repository_impl.dart` — replaces the fake. Overlays local
  capture progress onto whatever `SiteRepository` returns; `saveFull`/`savePartial` write
  the manifest, update wall status, and hand the round off to the sync queue.
- `domain/repositories/grid_capture_repository.dart` — added the storage-watchdog check
  (`checkStorageForNewSession`) and threaded a checksum/shot-number through `capturePhoto`.
- `presentation/pages/grid_init_page.dart` — checks free storage before creating a grid;
  warns below a threshold, blocks entirely below a critical one.
- **Deleted**: `fake_grid_capture_repository.dart` (no longer referenced anywhere).

### Sync-out pipeline (`lib/features/sync_queue/`)

- `data/models/sync_queue_item_record.dart` — one queue item per wall's capture round.
- `data/datasources/sync_remote_data_source.dart` — `POST /sync/sessions`,
  `POST /walls/{wall}/captures` (one multipart call per photo), `POST
  /sync/sessions/{id}/confirm`.
- `data/repositories/sync_queue_repository_impl.dart` — replaces the fake; implements both
  the existing `SyncQueueRepository` and a new narrow `SyncEnqueuer` port that
  `grid_capture` depends on.
- `domain/services/sync_queue_runner.dart` — drains the queue: register → upload every
  photo → confirm → **only then** delete the local backup. Network/5xx failures stay
  retryable automatically; a 422 is terminal until the operator fixes it and retries
  manually, per the contract's documented guidance.
- `presentation/pages/sync_queue_page.dart` — added a manual "Sync now" button.
- **Deleted**: `fake_sync_queue_repository.dart`.

### Background sync (`lib/core/background/`)

- `sync_background_task.dart` — `workmanager` periodic task (every 15 min, requires
  connectivity) that re-initializes Hive/DI in its own isolate and drains the queue.
  Foreground reconnect also triggers an immediate drain
  (`wireForegroundSyncOnReconnect()` in `main.dart`).
- **Not done**: the native platform registration step `workmanager` needs (a custom Android
  `Application` class / iOS Background Fetch capability) — the Dart side is fully wired,
  but that's native project configuration outside what could be done here. Foreground
  sync-on-reconnect and manual "Sync now" work regardless of this.

### Wiring

- `lib/core/di/injection_container.dart` — rewritten: registers the full real stack
  (network, storage, auth, site repository, grid capture, sync queue) in dependency order;
  only `UnassignedWallRepository` still resolves to its fake.
- `lib/main.dart` — now async: init Hive → open boxes → set up DI → seed session → wire
  reconnect sync → init background task → run app.
- `test/widget_test.dart` — updated to register the fake repository directly (a pure
  UI/navigation smoke test) and bypass the login redirect, since it predates auth and the
  real data layer.

### Explicitly deferred (not silently dropped)

- Grid registration against an unresolved `local_id` (unassigned wall) — the dashboard
  doesn't support this yet either; mobile keeps treating unassigned captures as a flat photo
  list, per the existing plan docs.
- A "delete cached site" UI entry point — the repository method
  (`deleteCachedSite`/`estimateDownload`) exists and works; no button calls it yet.
