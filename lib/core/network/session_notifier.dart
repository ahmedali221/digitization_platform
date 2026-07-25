import 'package:flutter/foundation.dart';

/// Shared login-state flag, read by the router's redirect guard and written
/// by the auth feature (login/logout) and [AuthInterceptor] (on a real 401
/// from the server). Deliberately a plain [ValueNotifier], not a new
/// state-management abstraction — this is the one piece of state that both
/// `core/network` and `core/router` need without depending on each other or
/// on `features/auth`.
final ValueNotifier<bool> isLoggedInNotifier = ValueNotifier<bool>(false);
