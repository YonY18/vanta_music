import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/download_item.dart';
import '../infrastructure/download_database.dart';
import '../infrastructure/file_download_storage.dart';

class DownloadProgressSnapshot {
  const DownloadProgressSnapshot({
    required this.status,
    required this.progressBytes,
    required this.totalBytes,
  });

  final DownloadStatus? status;
  final int progressBytes;
  final int? totalBytes;

  double? get progressFraction {
    final total = totalBytes;
    if (total == null || total <= 0) return null;
    return progressBytes / total;
  }

  @override
  bool operator ==(Object other) {
    return other is DownloadProgressSnapshot &&
        other.status == status &&
        other.progressBytes == progressBytes &&
        other.totalBytes == totalBytes;
  }

  @override
  int get hashCode => Object.hash(status, progressBytes, totalBytes);
}

class DownloadStorageSummary {
  const DownloadStorageSummary({
    required this.completedCount,
    required this.totalBytes,
  });

  final int completedCount;
  final int totalBytes;

  @override
  bool operator ==(Object other) {
    return other is DownloadStorageSummary &&
        other.completedCount == completedCount &&
        other.totalBytes == totalBytes;
  }

  @override
  int get hashCode => Object.hash(completedCount, totalBytes);
}

final downloadDatabaseProvider = FutureProvider<DownloadDatabase>((ref) async {
  final directory = await getApplicationSupportDirectory();
  return DownloadDatabase.sharedFile(
    File('${directory.path}/downloads.sqlite'),
  );
});

final downloadStorageProvider = FutureProvider<FileDownloadStorage>((
  ref,
) async {
  final directory = await getApplicationSupportDirectory();
  return FileDownloadStorage(appSupportDirectory: () async => directory);
});

final downloadItemProvider = StreamProvider.family<DownloadItem?, String>((
  ref,
  downloadKey,
) async* {
  final database = await ref.watch(downloadDatabaseProvider.future);
  yield* database.watchDownload(downloadKey);
});

final downloadStatusProvider = StreamProvider.family<DownloadStatus?, String>((
  ref,
  downloadKey,
) async* {
  final database = await ref.watch(downloadDatabaseProvider.future);
  yield* database
      .watchDownload(downloadKey)
      .map((item) => item?.status)
      .distinct();
});

final downloadProgressProvider =
    StreamProvider.family<DownloadProgressSnapshot?, String>((
      ref,
      downloadKey,
    ) async* {
      final database = await ref.watch(downloadDatabaseProvider.future);
      yield* database.watchDownload(downloadKey).map((item) {
        if (item == null) return null;
        return DownloadProgressSnapshot(
          status: item.status,
          progressBytes: item.progressBytes,
          totalBytes: item.totalBytes,
        );
      }).distinct();
    });

final downloadStorageSummaryProvider = StreamProvider<DownloadStorageSummary>((
  ref,
) async* {
  final database = await ref.watch(downloadDatabaseProvider.future);
  yield* database.watchAllDownloads().map(_buildStorageSummary).distinct();
});

DownloadStorageSummary _buildStorageSummary(List<DownloadItem> downloads) {
  var completedCount = 0;
  var totalBytes = 0;
  for (final item in downloads) {
    if (item.status != DownloadStatus.completed) continue;
    completedCount += 1;
    totalBytes += item.sizeBytes ?? 0;
  }
  return DownloadStorageSummary(
    completedCount: completedCount,
    totalBytes: totalBytes,
  );
}
