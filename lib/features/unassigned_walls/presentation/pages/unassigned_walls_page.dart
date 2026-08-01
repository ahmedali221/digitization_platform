import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/navigation_extensions.dart';
import '../../../../core/widgets/circle_icon_button.dart';
import '../../../../core/widgets/feedback_states.dart';
import '../../domain/repositories/unassigned_wall_repository.dart';
import '../cubit/unassigned_walls_cubit.dart';
import '../cubit/unassigned_walls_state.dart';
import '../widgets/unassigned_wall_card.dart';

/// Horizontal page padding used consistently for every screen body in the
/// design handoff prototype (`WallBase Sites.dc.html`, e.g. lines 26, 115,
/// 126, 390-391). DESIGN_SYSTEM.md §4 states a generic default of 16 for
/// page horizontal padding, but 20 isn't part of the 4pt `AppSpacing` scale
/// and isn't reused elsewhere yet, so it's kept as a small local constant
/// here rather than added to the shared token file speculatively.
const double _kPageHorizontalPadding = 20;

/// Phase 5 — list of walls captured before a room/zone was assigned. Tapping
/// a card opens `UnassignedWallDetailPage`, where capture/sync/resolution
/// actually happen; resolving a card to a real wall itself still happens on
/// the dashboard (`UnassignedWallController`), not here.
class UnassignedWallsPage extends StatelessWidget {
  const UnassignedWallsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => UnassignedWallsCubit(sl<UnassignedWallRepository>()),
      child: const _UnassignedWallsView(),
    );
  }
}

class _UnassignedWallsView extends StatelessWidget {
  const _UnassignedWallsView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                _kPageHorizontalPadding,
                0,
                _kPageHorizontalPadding,
                AppSpacing.md,
              ),
              child: Text(
                'Captured before a room was assigned — sync these and link '
                'them to a wall once back online',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.onSurfaceMuted,
                ),
              ),
            ),
            const Expanded(child: _Body()),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          CircleIconButton(
            icon: Icons.arrow_back,
            visualDiameter: 40,
            iconSize: 22,
            color: AppColors.textPrimary,
            onTap: () => context.safePop(),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'Unassigned walls',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontSize: 20),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<UnassignedWallsCubit, UnassignedWallsState>(
      builder: (context, state) {
        if (state is UnassignedWallsLoading) {
          return const LoadingIndicator();
        }
        if (state is UnassignedWallsError) {
          return ErrorRetryView(
            message: state.message,
            onRetry: () => context.read<UnassignedWallsCubit>().retry(),
          );
        }
        final items = (state as UnassignedWallsLoaded).items;
        if (items.isEmpty) {
          return const EmptyState(
            icon: Icons.check_circle_outline,
            message: 'No unassigned walls this trip',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            _kPageHorizontalPadding,
            0,
            _kPageHorizontalPadding,
            AppSpacing.xl,
          ),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final item = items[index];
            return UnassignedWallCard(
              item: item,
              onTap: () => context.push(
                '/sites/${item.siteId}/buildings/${item.buildingId}'
                '/floors/${item.floorId}/unassigned/${item.localId}',
              ),
            );
          },
        );
      },
    );
  }
}
