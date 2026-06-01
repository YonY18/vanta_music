import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../application/download_providers.dart';
import '../domain/download_item.dart';

class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grouped = ref.watch(groupedDownloadsProvider);
    final summary = ref.watch(downloadsSummaryProvider);
    final storage = ref.watch(downloadStorageSummaryProvider);

    final loading = grouped.isLoading || summary.isLoading || storage.isLoading;
    final error = grouped.asError?.error ??
        summary.asError?.error ??
        storage.asError?.error;

    return Scaffold(
      appBar: AppBar(title: const Text('Downloads')),
      body: SafeArea(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
            ? _ErrorState(
                error: error,
                onRetry: () {
                  ref.invalidate(allDownloadsProvider);
                  ref.invalidate(downloadStorageSummaryProvider);
                },
              )
            : _DownloadsBody(
                grouped: grouped.requireValue,
                summary: summary.requireValue,
                storage: storage.requireValue,
              ),
      ),
    );
  }
}

class _DownloadsBody extends ConsumerWidget {
  const _DownloadsBody({
    required this.grouped,
    required this.summary,
    required this.storage,
  });

  final GroupedDownloads grouped;
  final DownloadsSummary summary;
  final DownloadStorageSummary storage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queuedCount = grouped.active
        .where((item) => item.status == DownloadStatus.queued)
        .length;

    if (summary.totalCount == 0) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.download_for_offline_rounded, size: 40),
              SizedBox(height: 16),
              Text(
                'No downloads yet',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 8),
              Text(
                'Download remote tracks to manage them offline here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: VantaColors.muted),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Storage summary',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_formatBytes(storage.totalBytes)} saved offline',
                  style: const TextStyle(
                    color: VantaColors.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _StatPill(label: '${summary.activeCount} active'),
                    _StatPill(label: '$queuedCount pending'),
                    _StatPill(label: '${summary.completedCount} downloaded'),
                    _StatPill(label: '${summary.failedCount} failed'),
                  ],
                ),
                if (grouped.failed.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => _confirmClearFailed(context, ref),
                      child: const Text('Clear failed'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (grouped.active.isNotEmpty)
          _DownloadSection(
            title: 'Downloading & queued',
            items: grouped.active,
          ),
        if (grouped.completed.isNotEmpty) ...[
          if (grouped.active.isNotEmpty) const SizedBox(height: 16),
          _DownloadSection(title: 'Completed', items: grouped.completed),
        ],
        if (grouped.failed.isNotEmpty) ...[
          if (grouped.active.isNotEmpty || grouped.completed.isNotEmpty)
            const SizedBox(height: 16),
          _DownloadSection(title: 'Failed', items: grouped.failed),
        ],
      ],
    );
  }

  Future<void> _confirmClearFailed(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear failed downloads?'),
        content: const Text(
          'This removes failed downloads and keeps completed items untouched.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear failed'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final cleared = await ref.read(downloadControllerProvider).clearFailed();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Cleared $cleared failed downloads.')),
        );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Could not clear failed downloads: $error')),
        );
    }
  }
}

class _DownloadSection extends StatelessWidget {
  const _DownloadSection({required this.title, required this.items});

  final String title;
  final List<DownloadItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Card(
          child: Column(
            children: [
              for (var index = 0; index < items.length; index++) ...[
                _DownloadTile(item: items[index]),
                if (index != items.length - 1)
                  const Divider(height: 1, color: VantaColors.border),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DownloadTile extends ConsumerWidget {
  const _DownloadTile({required this.item});

  final DownloadItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subtitle = _subtitleFor(item);

    return ListTile(
      leading: _StatusBadge(status: item.status),
      title: Text(item.title),
      subtitle: Text(subtitle),
      trailing: Wrap(
        spacing: 4,
        children: _buildActions(context, ref),
      ),
    );
  }

  List<Widget> _buildActions(BuildContext context, WidgetRef ref) {
    final actions = <Widget>[];

    if (item.status == DownloadStatus.failed && item.retryable) {
      actions.add(
        IconButton(
          tooltip: 'Retry ${item.title}',
          onPressed: () => _runAction(
            context,
            () => ref.read(downloadControllerProvider).retry(item.downloadKey),
            success: 'Retry started for ${item.title}.',
            failurePrefix: 'Could not retry ${item.title}',
          ),
          icon: const Icon(Icons.refresh_rounded),
        ),
      );
    }

    if (item.status == DownloadStatus.queued ||
        item.status == DownloadStatus.downloading) {
      actions.add(
        IconButton(
          tooltip: 'Cancel ${item.title}',
          onPressed: () => _runAction(
            context,
            () => ref.read(downloadControllerProvider).cancel(item.downloadKey),
            success: 'Cancelled ${item.title}.',
            failurePrefix: 'Could not cancel ${item.title}',
          ),
          icon: const Icon(Icons.close_rounded),
        ),
      );
    }

    if (item.status == DownloadStatus.completed ||
        item.status == DownloadStatus.failed) {
      actions.add(
        IconButton(
          tooltip: 'Delete ${item.title}',
          onPressed: () => _confirmDelete(context, ref),
          icon: const Icon(Icons.delete_outline_rounded),
        ),
      );
    }

    return actions;
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final guard = ref.read(downloadControllerProvider).deleteGuard(item.downloadKey);
    if (guard.isBlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(guard.reason ?? 'Delete is blocked right now.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete download?'),
        content: Text('Remove ${item.title} from offline storage?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    await _runAction(
      context,
      () => ref.read(downloadControllerProvider).delete(item.downloadKey),
      success: 'Deleted ${item.title}.',
      failurePrefix: 'Could not delete ${item.title}',
    );
  }

  Future<void> _runAction(
    BuildContext context,
    Future<void> Function() action, {
    required String success,
    required String failurePrefix,
  }) async {
    try {
      await action();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(success)));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('$failurePrefix: $error')));
    }
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: VantaColors.surfaceHigh,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: VantaColors.border),
      ),
      child: Text(label),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final DownloadStatus status;

  @override
  Widget build(BuildContext context) {
    final (icon, label) = switch (status) {
      DownloadStatus.queued => (Icons.schedule_rounded, 'Queued'),
      DownloadStatus.downloading => (Icons.download_rounded, 'Downloading'),
      DownloadStatus.completed => (Icons.check_circle_rounded, 'Completed'),
      DownloadStatus.failed => (Icons.error_outline_rounded, 'Failed'),
      DownloadStatus.removing => (Icons.delete_sweep_rounded, 'Removing'),
    };

    return Tooltip(
      message: label,
      child: CircleAvatar(
        radius: 18,
        backgroundColor: VantaColors.surfaceHigh,
        child: Icon(icon, size: 18),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Could not load downloads',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  '$error',
                  style: const TextStyle(color: VantaColors.muted),
                ),
                const SizedBox(height: 16),
                FilledButton(onPressed: onRetry, child: const Text('Try again')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _subtitleFor(DownloadItem item) {
  final buffer = StringBuffer('${item.artist} • ${item.album}');
  switch (item.status) {
    case DownloadStatus.queued:
      buffer.write(' • Pending');
    case DownloadStatus.downloading:
      final total = item.totalBytes;
      if (total != null && total > 0) {
        final percent = ((item.progressBytes / total) * 100).round();
        buffer.write(' • $percent%');
      } else {
        buffer.write(' • Downloading');
      }
    case DownloadStatus.completed:
      if (item.sizeBytes != null) {
        buffer.write(' • ${_formatBytes(item.sizeBytes!)}');
      } else {
        buffer.write(' • Ready offline');
      }
    case DownloadStatus.failed:
      buffer.write(' • ${item.errorMessage ?? 'Failed'}');
    case DownloadStatus.removing:
      buffer.write(' • Removing');
  }
  return buffer.toString();
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(kb >= 10 ? 0 : 1)} KB';
  final mb = kb / 1024;
  return '${mb.toStringAsFixed(mb >= 10 ? 0 : 1)} MB';
}
