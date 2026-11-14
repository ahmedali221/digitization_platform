import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/domain/repositories/site_repository.dart';
import '../../../../core/utils/navigation_extensions.dart';
import '../../../../core/widgets/feedback_states.dart';
import '../../domain/repositories/object_capture_repository.dart';
import '../../domain/repositories/object_scan_repository.dart';
import '../cubit/object_capture_cubit.dart';
import '../cubit/object_capture_state.dart';

/// What the three object capture screens share: a cubit for the object in
/// the route, the loading and not-found states, and a message when a
/// photograph could not be kept. [builder] draws the screen itself.
class ObjectCaptureScaffold extends StatelessWidget {
  const ObjectCaptureScaffold({
    super.key,
    required this.floorId,
    required this.wallId,
    required this.builder,
    this.onOpened,
  });

  final String floorId;
  final String wallId;
  final Widget Function(BuildContext context, ObjectCaptureLoaded state)
  builder;

  /// Runs once, as the screen opens, with its freshly made cubit.
  final void Function(ObjectCaptureCubit cubit)? onOpened;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = ObjectCaptureCubit(
          GetIt.instance<ObjectCaptureRepository>(),
          GetIt.instance<ObjectScanRepository>(),
          GetIt.instance<SiteRepository>(),
          floorId: floorId,
          wallId: wallId,
        );
        onOpened?.call(cubit);
        return cubit;
      },
      child: Scaffold(
        body: SafeArea(
          child: BlocConsumer<ObjectCaptureCubit, ObjectCaptureState>(
            listenWhen: (previous, current) =>
                current is ObjectCaptureLoaded &&
                current.failure != null &&
                !(previous is ObjectCaptureLoaded &&
                    previous.failure == current.failure),
            listener: (context, state) {
              final failure = (state as ObjectCaptureLoaded).failure!;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(failure)));
            },
            builder: (context, state) => switch (state) {
              ObjectCaptureLoading() => const LoadingIndicator(),
              ObjectCaptureNotFound() => ErrorRetryView(
                message: 'This item could not be found.',
                onRetry: () => context.safePop(),
              ),
              ObjectCaptureLoaded() => builder(context, state),
            },
          ),
        ),
      ),
    );
  }
}
