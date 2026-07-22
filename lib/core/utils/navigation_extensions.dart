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
