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
    while (router.canPop() &&
        router.routerDelegate.currentConfiguration.uri.path != path) {
      router.pop();
    }
  }
}
