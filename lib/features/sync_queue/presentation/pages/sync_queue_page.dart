import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/navigation_extensions.dart';
import '../../../../core/widgets/circle_icon_button.dart';
import '../../../../core/widgets/feedback_states.dart';
import '../../domain/repositories/sync_queue_repository.dart';
import '../../domain/services/sync_queue_runner.dart';
import '../cubit/sync_queue_cubit.dart';
import '../cubit/sync_queue_state.dart';
import '../widgets/sync_queue_item_tile.dart';

class SyncQueuePage extends StatelessWidget {
  const SyncQueuePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          SyncQueueCubit(sl<SyncQueueRepository>(), sl<SyncQueueRunner>()),
      child: const _SyncQueueView(),
    );
  }
}

class _SyncQueueView extends StatelessWidget {
  const _SyncQueueView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const _SyncQueueHeader(),
            Expanded(
              child: BlocBuilder<SyncQueueCubit, SyncQueueState>(
                builder: (context, state) {
                  if (state is SyncQueueError) {
                    return ErrorRetryView(
                      message: state.message,
                      onRetry: () => context.read<SyncQueueCubit>().reload(),
                    );
                  }
                  if (state is SyncQueueLoaded) {
                    if (state.items.isEmpty) {
                      return const EmptyState(
                        icon: Icons.cloud_done,
                        message: 'Nothing queued — all captures are synced',
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      itemCount: state.items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = state.items[index];
                        return SyncQueueItemTile(
                          item: item,
                          onRetry: () =>
                              context.read<SyncQueueCubit>().retry(item.id),
                        );
                      },
                    );
                  }
                  return const LoadingIndicator();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SyncQueueHeader extends StatelessWidget {
  const _SyncQueueHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, AppSpacing.lg, 12, AppSpacing.sm),
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
          Expanded(
            child: Text(
              'Sync queue',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: 20,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          CircleIconButton(
            icon: Icons.sync,
            visualDiameter: 40,
            iconSize: 20,
            color: AppColors.textPrimary,
            onTap: () => context.read<SyncQueueCubit>().syncNow(),
          ),
        ],
      ),
    );
  }
}
