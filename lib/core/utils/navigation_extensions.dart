import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Guards [GoRouter.pop] against rapid double-taps on a back button: the
/// first tap pops before the widget is removed from the tree, so a second
/// tap in quick succession can fire with nothing left to pop.
extension SafePopExtension on BuildContext {
  void safePop() {
    if (canPop()) pop();
  }
}

/// Pops back to [path] instead of jumping there with [GoRouter.go].
///
/// `go()` replaces the whole navigation stack with a freshly built page for
/// the target location, discarding every page pushed on top of it (e.g. a
/// save action deep in the grid-capture flow) *and* the destination page's
/// own in-memory state (e.g. FloorWallsPage's selected room filter) since a
/// brand-new instance is built rather than the existing one being revealed.
/// Popping instead keeps that instance — and the rest of the back stack
/// below it — intact.
extension PopToPathExtension on BuildContext {
  void popToPath(String path) {
    final router = GoRouter.of(this);
    // Deliberately NOT `currentConfiguration.uri.path`: `RouteMatchList.push`
    // (go_router's own `copyWith`) carries the *base* list's `uri` forward
    // unchanged onto the merged list, so after a chain of `context.push()`
    // calls (site -> building -> floor -> wall -> capture, all pushes)
    // `uri.path` stays pinned at wherever the last `go()`/initial location
    // was — e.g. `/sites` — no matter how deep the stack actually is. That
    // made this comparison never match, so the loop below silently popped
    // all the way to the app root (home) instead of stopping at [path].
    // Each individual match's own `matchedLocation`, in contrast, is the
    // real concrete location for that stack entry.
    while (router.canPop() &&
        router.routerDelegate.currentConfiguration.matches.last
                .matchedLocation !=
            path) {
      router.pop();
    }
  }
}
