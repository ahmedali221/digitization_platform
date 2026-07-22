// See `../../domain/repositories/site_repository.dart` — re-exports the
// shared in-memory implementation from `core/data` instead of duplicating
// it, so `core/di/injection_container.dart`'s feature-local import path
// resolves to the exact same `FakeSiteRepository` type.
export '../../../../core/data/repositories/fake_site_repository.dart';
