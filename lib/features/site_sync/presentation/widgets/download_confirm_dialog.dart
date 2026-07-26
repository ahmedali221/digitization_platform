import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/primary_action_button.dart';

/// Phase 1's pre-download summary: "Karnak: 47 files, 132 MB — download?".
/// Returns `true` if the user confirmed, `false`/`null` otherwise.
Future<bool?> showDownloadConfirmDialog({
  required BuildContext context,
  required String siteName,
  required Future<({int fileCount, int totalBytes})> Function() loadEstimate,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) =>
        _DownloadConfirmDialog(siteName: siteName, loadEstimate: loadEstimate),
  );
}

class _DownloadConfirmDialog extends StatelessWidget {
  const _DownloadConfirmDialog({
    required this.siteName,
    required this.loadEstimate,
  });

  final String siteName;
  final Future<({int fileCount, int totalBytes})> Function() loadEstimate;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Download $siteName?'),
      content: FutureBuilder(
        future: loadEstimate(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox(
              height: 48,
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            );
          }
          if (snapshot.hasError) {
            return Text(
              'Could not check the download size: ${snapshot.error}',
              style: TextStyle(color: AppColors.onDangerContainer),
            );
          }
          final estimate = snapshot.data!;
          return Text(
            '${estimate.fileCount} files, ${_formatBytes(estimate.totalBytes)}. '
            'The whole site is downloaded up front so it works fully '
            'offline in the field.',
          );
        },
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        SizedBox(
          width: 140,
          child: PrimaryActionButton(
            label: 'Download',
            onTap: () => Navigator.of(context).pop(true),
          ),
        ),
      ],
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
