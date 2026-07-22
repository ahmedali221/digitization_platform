// The site/zone/wall data tree is owned by this feature (site_sync), but the
// abstract contract and its fake implementation are shared with other
// features (grid_capture, sync_queue, unassigned_walls all read the same
// tree) so they live in `core/domain` per CLAUDE.md's DIP rule. Re-exported
// here — rather than duplicated — so `core/di/injection_container.dart` can
// depend on this feature-local path while every consumer still resolves to
// the exact same `SiteRepository` type.
export '../../../../core/domain/repositories/site_repository.dart';
