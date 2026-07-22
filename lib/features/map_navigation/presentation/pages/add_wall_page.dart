import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/domain/repositories/site_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/navigation_extensions.dart';
import '../../../../core/widgets/breadcrumb.dart';
import '../../../../core/widgets/circle_icon_button.dart';
import '../../../../core/widgets/primary_action_button.dart';

/// Form page for adding a new wall to a floor — title (required) and notes
/// (optional), replacing the old wall action sheet's lack of a create flow.
class AddWallPage extends StatefulWidget {
  const AddWallPage({
    super.key,
    required this.siteId,
    required this.buildingId,
    required this.floorId,
  });

  final String siteId;
  final String buildingId;
  final String floorId;

  @override
  State<AddWallPage> createState() => _AddWallPageState();
}

class _AddWallPageState extends State<AddWallPage> {
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  String? _titleError;

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = 'Title is required');
      return;
    }
    GetIt.instance<SiteRepository>().addWall(
      widget.floorId,
      title: title,
      notes: _notesController.text.trim(),
    );
    context.safePop();
  }

  @override
  Widget build(BuildContext context) {
    final repository = GetIt.instance<SiteRepository>();
    final site = repository.findSite(widget.siteId);
    final building = repository.findBuilding(widget.buildingId);
    final floor = repository.findFloor(widget.floorId);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
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
                    onTap: () => context.safePop(),
                    visualDiameter: 40,
                    iconSize: 22,
                    color: AppColors.textPrimary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Breadcrumb(
                      items: [
                        BreadcrumbItem(
                          label: 'Sites',
                          onTap: () => context.go('/sites'),
                        ),
                        BreadcrumbItem(
                          label: site?.name ?? '',
                          onTap: () =>
                              context.go('/sites/${widget.siteId}/buildings'),
                        ),
                        BreadcrumbItem(
                          label: building?.name ?? '',
                          onTap: () => context.go(
                            '/sites/${widget.siteId}/buildings/${widget.buildingId}/floors',
                          ),
                        ),
                        BreadcrumbItem(
                          label: floor?.name ?? '',
                          onTap: () => context.go(
                            '/sites/${widget.siteId}/buildings/${widget.buildingId}/floors/${widget.floorId}',
                          ),
                        ),
                        const BreadcrumbItem(label: 'Add wall'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  AppSpacing.sm,
                  20,
                  AppSpacing.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add wall',
                      style: textTheme.titleLarge?.copyWith(fontSize: 20),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _FieldLabel('TITLE'),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: _titleController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'e.g. North face',
                        errorText: _titleError,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.card),
                        ),
                      ),
                      onChanged: (_) {
                        if (_titleError != null) {
                          setState(() => _titleError = null);
                        }
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _FieldLabel('NOTES'),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: _notesController,
                      minLines: 3,
                      maxLines: 6,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Optional notes about this wall',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.card),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    PrimaryActionButton(label: 'Add wall', onTap: _submit),
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

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: AppColors.onSurfaceMuted,
        letterSpacing: 0.5,
      ),
    );
  }
}
