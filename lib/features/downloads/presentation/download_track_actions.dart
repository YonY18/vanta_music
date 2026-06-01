import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../library/domain/track.dart';
import '../application/download_providers.dart';
import '../domain/download_item.dart';

class DownloadTrackActionButton extends ConsumerWidget {
  const DownloadTrackActionButton({super.key, required this.track});

  final Track track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = downloadRequestFromRemoteTrack(track);
    if (request == null) return const SizedBox.shrink();

    final progress = ref
        .watch(downloadProgressProvider(request.identity.downloadKey))
        .valueOrNull;

    return IconButton(
      tooltip: 'Download actions',
      onPressed: () =>
          showDownloadTrackActionsSheet(context: context, track: track),
      icon: _DownloadStatusIcon(progress: progress),
    );
  }
}

Future<void> showDownloadTrackActionsSheet({
  required BuildContext context,
  required Track track,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: DownloadTrackActionsSection(track: track),
        ),
      ),
    ),
  );
}

class DownloadTrackActionsSection extends ConsumerWidget {
  const DownloadTrackActionsSection({
    super.key,
    required this.track,
    this.title = 'Offline download',
  });

  final Track track;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = downloadRequestFromRemoteTrack(track);
    if (request == null) return const SizedBox.shrink();

    final download = ref
        .watch(downloadItemProvider(request.identity.downloadKey))
        .valueOrNull;
    final progress = ref
        .watch(downloadProgressProvider(request.identity.downloadKey))
        .valueOrNull;
    final actions = downloadActionsForTrack(track: track, download: download);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        _DownloadStatusCard(progress: progress, download: download),
        const SizedBox(height: 8),
        for (final action in actions.availableActions)
          _DownloadActionTile(
            track: track,
            action: action,
            downloadKey: request.identity.downloadKey,
          ),
      ],
    );
  }
}

class _DownloadActionTile extends ConsumerWidget {
  const _DownloadActionTile({
    required this.track,
    required this.action,
    required this.downloadKey,
  });

  final Track track;
  final DownloadTrackAction action;
  final String downloadKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(downloadControllerProvider);
    final (icon, label) = switch (action) {
      DownloadTrackAction.download => (
        Icons.download_rounded,
        'Download for offline',
      ),
      DownloadTrackAction.cancel => (Icons.close_rounded, 'Cancel download'),
      DownloadTrackAction.retry => (Icons.refresh_rounded, 'Retry download'),
      DownloadTrackAction.delete => (
        Icons.delete_outline_rounded,
        'Delete download',
      ),
    };

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label),
      onTap: () async {
        final messenger = ScaffoldMessenger.of(context);
        final navigator = Navigator.of(context);
        try {
          switch (action) {
            case DownloadTrackAction.download:
              await controller.enqueueTrack(track);
              messenger.showSnackBar(
                const SnackBar(content: Text('Download queued.')),
              );
            case DownloadTrackAction.cancel:
              await controller.cancel(downloadKey);
              messenger.showSnackBar(
                const SnackBar(content: Text('Download canceled.')),
              );
            case DownloadTrackAction.retry:
              await controller.retry(downloadKey);
              messenger.showSnackBar(
                const SnackBar(content: Text('Download retry started.')),
              );
            case DownloadTrackAction.delete:
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete download?'),
                  content: const Text(
                    'This removes the offline copy and keeps the canonical track.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Keep'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (confirmed != true) return;

              final guard = controller.deleteGuard(downloadKey);
              if (guard.isBlocked) {
                messenger.showSnackBar(
                  SnackBar(content: Text(guard.reason ?? 'Delete blocked.')),
                );
                return;
              }

              await controller.delete(downloadKey);
              messenger.showSnackBar(
                const SnackBar(content: Text('Download deleted.')),
              );
          }

          if (navigator.canPop()) navigator.pop();
        } catch (error) {
          messenger.showSnackBar(
            SnackBar(content: Text('Download action failed: $error')),
          );
        }
      },
    );
  }
}

class _DownloadStatusCard extends StatelessWidget {
  const _DownloadStatusCard({required this.progress, required this.download});

  final DownloadProgressSnapshot? progress;
  final DownloadItem? download;

  @override
  Widget build(BuildContext context) {
    final status = progress?.status ?? download?.status;
    final label = switch (status) {
      null => 'Ready to save this remote track offline.',
      DownloadStatus.queued => 'Queued for download.',
      DownloadStatus.downloading => _downloadingLabel(progress),
      DownloadStatus.completed => 'Available offline on this device.',
      DownloadStatus.failed =>
        download?.errorMessage?.trim().isNotEmpty == true
            ? download!.errorMessage!
            : 'The offline copy failed. You can retry or delete it.',
      DownloadStatus.removing => 'Removing offline copy…',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _DownloadStatusIcon(progress: progress),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }

  String _downloadingLabel(DownloadProgressSnapshot? progress) {
    final fraction = progress?.progressFraction;
    if (fraction == null) return 'Downloading…';
    return 'Downloading ${(fraction * 100).round()}%';
  }
}

class _DownloadStatusIcon extends StatelessWidget {
  const _DownloadStatusIcon({required this.progress});

  final DownloadProgressSnapshot? progress;

  @override
  Widget build(BuildContext context) {
    final status = progress?.status;
    if (status == DownloadStatus.downloading) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          value: progress?.progressFraction,
        ),
      );
    }

    final icon = switch (status) {
      DownloadStatus.queued => Icons.schedule_rounded,
      DownloadStatus.completed => Icons.download_done_rounded,
      DownloadStatus.failed => Icons.error_outline_rounded,
      DownloadStatus.removing => Icons.delete_outline_rounded,
      _ => Icons.download_rounded,
    };

    return Icon(icon, size: 20);
  }
}
