import 'package:flutter/material.dart';

import '../../../../core/domain/entities/site.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

Future<String?> showSelectSiteDialog({
  required BuildContext context,
  required List<SiteEntity> sites,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _SelectSiteDialog(sites: sites),
  );
}

class _SelectSiteDialog extends StatelessWidget {
  const _SelectSiteDialog({required this.sites});

  final List<SiteEntity> sites;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Which site does this wall belong to?'),
      content: SizedBox(
        width: double.maxFinite,
        child: sites.isEmpty
            ? const Text('No sites available on this device yet.')
            : ListView.separated(
                shrinkWrap: true,
                itemCount: sites.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, color: AppColors.outlineSubtle),
                itemBuilder: (context, index) {
                  final site = sites[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(site.name),
                    onTap: () => Navigator.of(context).pop(site.id),
                  );
                },
              ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
