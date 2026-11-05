import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/feedback_states.dart';
import '../../../../core/widgets/primary_action_button.dart';
import '../../../../core/widgets/thin_progress_bar.dart';
import '../../data/models/follow_up_upload_record.dart';
import '../../domain/entities/follow_up_package.dart';
import '../../domain/repositories/follow_up_repository.dart';
import '../cubit/follow_up_cubit.dart';
import '../cubit/follow_up_state.dart';
import '../widgets/upload_status_chip.dart';
import 'annotation_task_page.dart';
import 'target_detail_page.dart';

/// A site's follow-up work: the annotations to photograph again and the AR
/// targets to browse and replace, from a package that works with no signal.
class FollowUpPage extends StatelessWidget {
  const FollowUpPage({super.key, required this.siteId});

  final String siteId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => FollowUpCubit(GetIt.instance<FollowUpRepository>(), siteId),
      child: DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Follow-up captures'),
            bottom: const TabBar(
              tabs: [Tab(text: 'Annotations'), Tab(text: 'Targets'), Tab(text: 'Sent')],
            ),
          ),
          body: const SafeArea(child: _Body()),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FollowUpCubit, FollowUpState>(
      builder: (context, state) {
        if (state.loading) return const LoadingIndicator();
        final package = state.package;
        return Column(
          children: [
            _PackageBanner(state: state),
            Expanded(
              child: TabBarView(
                children: [
                  package == null ? const _NoPackage() : _AnnotationList(package: package),
                  package == null ? const _NoPackage() : _TargetList(package: package),
                  const _UploadList(),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _NoPackage extends StatelessWidget {
  const _NoPackage();

  @override
  Widget build(BuildContext context) => const EmptyState(
    icon: Icons.inventory_2_outlined,
    message:
        'No follow-up package on this phone. Create one from the Thoth index check page on the dashboard, then download it here.',
  );
}

class _PackageBanner extends StatelessWidget {
  const _PackageBanner({required this.state});

  final FollowUpState state;

  static const double _bytesPerMegabyte = 1024 * 1024;

  @override
  Widget build(BuildContext context) {
    final available = state.available;
    if (state.downloading) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Downloading the package… ${(state.progress * 100).round()}%'),
            const SizedBox(height: AppSpacing.xs),
            ThinProgressBar(progress: state.progress),
          ],
        ),
      );
    }
    if (available == null && state.error == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.error != null) ...[
            Text(state.error!, style: const TextStyle(color: AppColors.onDangerContainer)),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (available != null)
            PrimaryActionButton(
              icon: Icons.download,
              label:
                  'Download package · annotations: ${available.annotations.length}, '
                  'targets: ${available.targets.length}, '
                  '${(available.totalBytes / _bytesPerMegabyte).ceil()} MB',
              onTap: () => context.read<FollowUpCubit>().download(),
            ),
        ],
      ),
    );
  }
}

class _AnnotationList extends StatelessWidget {
  const _AnnotationList({required this.package});

  final FollowUpPackage package;

  @override
  Widget build(BuildContext context) {
    if (package.annotations.isEmpty) {
      return const EmptyState(icon: Icons.check_circle_outline, message: 'No annotations in this package.');
    }
    final cubit = context.read<FollowUpCubit>();
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: package.annotations.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final annotation = package.annotations[index];
        final upload = cubit.latestFor(FollowUpUploadRecord.kindAnnotation, annotation.id.toString());
        return _ItemCard(
          title: annotation.referenceCode,
          subtitle: '${annotation.wall.name} · ${annotation.grade ?? 'not checked'}',
          upload: upload,
          onTap: () => _open(context, AnnotationTaskPage(package: package, annotation: annotation)),
        );
      },
    );
  }
}

class _TargetList extends StatelessWidget {
  const _TargetList({required this.package});

  final FollowUpPackage package;

  @override
  Widget build(BuildContext context) {
    if (package.targets.isEmpty) {
      return const EmptyState(icon: Icons.image_not_supported_outlined, message: 'This site has no AR targets.');
    }
    final repository = GetIt.instance<FollowUpRepository>();
    final cubit = context.read<FollowUpCubit>();

    final walls = <String, List<FollowUpTarget>>{};
    for (final target in package.targets) {
      walls.putIfAbsent(target.wall.name, () => []).add(target);
    }

    return CustomScrollView(
      slivers: [
        for (final wall in walls.entries) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
              child: Text(wall.key, style: Theme.of(context).textTheme.titleSmall),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            sliver: SliverGrid.extent(
              maxCrossAxisExtent: 180,
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              children: [
                for (final target in wall.value)
                  _TargetTile(
                    target: target,
                    imagePath: repository.filePath(package.siteId, target.imageKey),
                    upload: cubit.latestFor(FollowUpUploadRecord.kindTarget, target.arKey),
                    onTap: () => _open(context, TargetDetailPage(package: package, target: target)),
                  ),
              ],
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
      ],
    );
  }
}

/// Details and the capture flow live on their own routes; coming back from one
/// is when a new upload appears.
Future<void> _open(BuildContext context, Widget page) async {
  final cubit = context.read<FollowUpCubit>();
  await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  cubit.refreshUploads();
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.title, required this.subtitle, required this.upload, required this.onTap});

  final String title;
  final String subtitle;
  final FollowUpUploadRecord? upload;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.outlineSubtle),
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceMuted),
                    ),
                    if (upload != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      UploadStatusChip(upload: upload!),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.iconMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _TargetTile extends StatelessWidget {
  const _TargetTile({required this.target, required this.imagePath, required this.upload, required this.onTap});

  static const int _thumbnailWidth = 400;

  final FollowUpTarget target;
  final Future<String> imagePath;
  final FollowUpUploadRecord? upload;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.chip),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.chip),
        child: Stack(
          fit: StackFit.expand,
          children: [
            FutureBuilder<String>(
              future: imagePath,
              builder: (context, snapshot) => snapshot.hasData
                  ? Image.file(File(snapshot.data!), fit: BoxFit.cover, cacheWidth: _thumbnailWidth)
                  : const ColoredBox(color: AppColors.surfaceNeutral),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                color: AppColors.cameraScrim,
                padding: const EdgeInsets.all(AppSpacing.xs),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      target.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white),
                    ),
                    if (upload != null) UploadStatusChip(upload: upload!),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UploadList extends StatelessWidget {
  const _UploadList();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<FollowUpCubit>().state;
    if (state.uploads.isEmpty) {
      return const EmptyState(icon: Icons.outbox_outlined, message: 'Nothing sent from this site yet.');
    }
    return RefreshIndicator(
      onRefresh: () => context.read<FollowUpCubit>().syncNow(),
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: state.uploads.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) => _UploadRow(upload: state.uploads[index]),
      ),
    );
  }
}

class _UploadRow extends StatelessWidget {
  const _UploadRow({required this.upload});

  final FollowUpUploadRecord upload;

  @override
  Widget build(BuildContext context) {
    final detail = [
      if (upload.rejectReason != null) upload.rejectReason!,
      ...upload.reasons,
      if (upload.status == FollowUpUploadRecord.statusFailed && upload.lastError != null) upload.lastError!,
    ];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.outlineSubtle),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                upload.kind == FollowUpUploadRecord.kindTarget ? Icons.center_focus_strong : Icons.text_snippet_outlined,
                size: 18,
                color: AppColors.iconMuted,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(upload.label, style: Theme.of(context).textTheme.titleSmall)),
              UploadStatusChip(upload: upload),
            ],
          ),
          for (final text in detail)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceMuted),
              ),
            ),
        ],
      ),
    );
  }
}
