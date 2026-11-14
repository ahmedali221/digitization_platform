import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/domain/entities/object_type.dart';
import '../../../../core/domain/repositories/site_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/object_type_meta.dart';
import '../../../../core/utils/navigation_extensions.dart';
import '../../../../core/widgets/breadcrumb.dart';
import '../../../../core/widgets/circle_icon_button.dart';
import '../../../../core/widgets/primary_action_button.dart';
import '../cubit/add_item_cubit.dart';
import '../cubit/add_item_state.dart';
import '../widgets/form_field_label.dart';
import '../widgets/hall_picker.dart';
import '../widgets/object_metadata_form.dart';
import '../widgets/object_type_picker.dart';

/// Adds a wall or object to a floor from the site itself: what it is, which
/// hall it is in, its name, and — for an object — what its label says.
/// Saving stores it on the phone and goes straight on to capturing it.
class AddItemPage extends StatelessWidget {
  const AddItemPage({
    super.key,
    required this.siteId,
    required this.buildingId,
    required this.floorId,
    this.initialHallName,
  });

  final String siteId;
  final String buildingId;
  final String floorId;

  /// The hall the form opens on: the one the operator was looking at.
  final String? initialHallName;

  String get _floorPath =>
      '/sites/$siteId/buildings/$buildingId/floors/$floorId';

  /// The new item's page replaces this form, so Back from there returns to
  /// the floor; its capture screen then opens on top, ready to shoot.
  void _goToCapture(BuildContext context, AddItemState state) {
    final itemPath = '$_floorPath/walls/${state.savedItemId}';
    final captureSegment = state.objectType.captureMode == CaptureMode.grid
        ? 'grid-init'
        : 'object-capture';
    context
      ..pushReplacement(itemPath)
      ..push('$itemPath/$captureSegment');
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AddItemCubit(
        GetIt.instance<SiteRepository>(),
        siteId: siteId,
        buildingId: buildingId,
        floorId: floorId,
        initialHallName: initialHallName,
      ),
      child: BlocListener<AddItemCubit, AddItemState>(
        listenWhen: (previous, current) =>
            previous.savedItemId != current.savedItemId ||
            (current.failure != null && previous.failure != current.failure),
        listener: (context, state) {
          if (state.savedItemId != null) {
            _goToCapture(context, state);
            return;
          }
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.failure!)));
        },
        child: Scaffold(
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AddItemHeader(
                  siteId: siteId,
                  buildingId: buildingId,
                  floorPath: _floorPath,
                ),
                const Expanded(child: _AddItemForm()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddItemHeader extends StatelessWidget {
  const _AddItemHeader({
    required this.siteId,
    required this.buildingId,
    required this.floorPath,
  });

  static const double _backButtonDiameter = 40;
  static const double _backIconSize = 22;

  final String siteId;
  final String buildingId;
  final String floorPath;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AddItemCubit>().state;
    final wording = SiteWording.of(state.siteKind);

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
            onTap: () => context.safePop(),
            visualDiameter: _backButtonDiameter,
            iconSize: _backIconSize,
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
                  label: state.siteName,
                  onTap: () => context.go('/sites/$siteId/buildings'),
                ),
                BreadcrumbItem(
                  label: state.buildingName,
                  onTap: () =>
                      context.go('/sites/$siteId/buildings/$buildingId/floors'),
                ),
                BreadcrumbItem(
                  label: state.floorName,
                  onTap: () => context.go(floorPath),
                ),
                BreadcrumbItem(label: 'Add ${wording.item}'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddItemForm extends StatefulWidget {
  const _AddItemForm();

  @override
  State<_AddItemForm> createState() => _AddItemFormState();
}

class _AddItemFormState extends State<_AddItemForm> {
  final _name = TextEditingController();
  final _notes = TextEditingController();
  final _metadata = ObjectMetadataControllers();

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    _metadata.dispose();
    super.dispose();
  }

  void _submit() {
    context.read<AddItemCubit>().submit(
      name: _name.text,
      notes: _notes.text,
      metadata: _metadata.toMetadata(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AddItemCubit>();
    final state = context.watch<AddItemCubit>().state;
    final wording = SiteWording.of(state.siteKind);
    final typeLabel = state.objectType.meta.label.toLowerCase();
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.card),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add ${wording.item}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.xl),
          const FormFieldLabel('Type'),
          const SizedBox(height: AppSpacing.sm),
          ObjectTypePicker(
            selected: state.objectType,
            onSelected: cubit.selectType,
          ),
          const SizedBox(height: AppSpacing.lg),
          const FormFieldLabel('Name'),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => cubit.nameEdited(),
            decoration: InputDecoration(
              hintText: state.objectType == ObjectType.wall
                  ? 'e.g. North face'
                  : 'e.g. Seated scribe',
              errorText: state.nameError,
              border: fieldBorder,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FormFieldLabel(wording.hall),
          const SizedBox(height: AppSpacing.sm),
          HallPicker(
            halls: state.halls,
            selected: state.hall,
            onSelected: cubit.selectHall,
            hallWord: wording.hall,
          ),
          if (state.objectType != ObjectType.wall) ...[
            const SizedBox(height: AppSpacing.lg),
            ObjectMetadataForm(controllers: _metadata),
          ],
          const SizedBox(height: AppSpacing.lg),
          const FormFieldLabel('Notes'),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _notes,
            minLines: 3,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Optional notes about this $typeLabel',
              border: fieldBorder,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          PrimaryActionButton(
            label: 'Save and capture',
            icon: Icons.photo_camera,
            enabled: !state.isSaving,
            onTap: _submit,
          ),
        ],
      ),
    );
  }
}
