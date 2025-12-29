import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'update_service.dart';

class UpdateDialog extends ConsumerWidget {
  const UpdateDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updateState = ref.watch(updateProvider);

    return AlertDialog(
      title: Text(_getTitle(updateState.status)),
      content: _buildContent(updateState),
      actions: _buildActions(context, ref, updateState),
    );
  }

  String _getTitle(UpdateStatus status) {
    switch (status) {
      case UpdateStatus.available:
        return 'Update Available';
      case UpdateStatus.downloading:
        return 'Downloading...';
      case UpdateStatus.readyToInstall:
        return 'Ready to Install';
      case UpdateStatus.error:
        return 'Update Error';
      default:
        return 'Update';
    }
  }

  Widget _buildContent(UpdateState state) {
    switch (state.status) {
      case UpdateStatus.available:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version ${state.updateInfo?.version} is available.'),
            if (state.updateInfo?.changelog != null) ...[
              const SizedBox(height: 8),
              Text(
                state.updateInfo!.changelog!,
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ],
        );

      case UpdateStatus.downloading:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(value: state.downloadProgress),
            const SizedBox(height: 8),
            Text('${(state.downloadProgress * 100).toStringAsFixed(0)}%'),
          ],
        );

      case UpdateStatus.readyToInstall:
        return const Text('Tap Install to complete the update.');

      case UpdateStatus.error:
        return Text(
          state.errorMessage ?? 'An error occurred',
          style: const TextStyle(color: Colors.red),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  List<Widget> _buildActions(BuildContext context, WidgetRef ref, UpdateState state) {
    switch (state.status) {
      case UpdateStatus.available:
        return [
          TextButton(
            onPressed: () {
              ref.read(updateProvider.notifier).reset();
              Navigator.of(context).pop();
            },
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(updateProvider.notifier).downloadAndInstall();
            },
            child: const Text('Download'),
          ),
        ];

      case UpdateStatus.downloading:
        return [
          TextButton(
            onPressed: () {
              ref.read(updateProvider.notifier).reset();
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
        ];

      case UpdateStatus.readyToInstall:
        return [
          TextButton(
            onPressed: () {
              ref.read(updateProvider.notifier).reset();
              Navigator.of(context).pop();
            },
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(updateProvider.notifier).installUpdate();
              Navigator.of(context).pop();
            },
            child: const Text('Install'),
          ),
        ];

      case UpdateStatus.error:
        return [
          TextButton(
            onPressed: () {
              ref.read(updateProvider.notifier).reset();
              Navigator.of(context).pop();
            },
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(updateProvider.notifier).checkForUpdate();
            },
            child: const Text('Retry'),
          ),
        ];

      default:
        return [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ];
    }
  }
}

/// Shows update dialog if an update is available
Future<void> showUpdateDialogIfAvailable(BuildContext context, WidgetRef ref) async {
  await ref.read(updateProvider.notifier).checkForUpdate();
  final state = ref.read(updateProvider);

  if (state.status == UpdateStatus.available && context.mounted) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const UpdateDialog(),
    );
  }
}
