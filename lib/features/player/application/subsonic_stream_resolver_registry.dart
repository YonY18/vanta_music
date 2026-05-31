import 'package:audio_service/audio_service.dart';

import '../../downloads/domain/download_item.dart';
import '../../downloads/infrastructure/download_database.dart';
import '../../downloads/infrastructure/file_download_storage.dart';
import '../../providers/application/subsonic_providers.dart';
import '../../providers/domain/provider_identity.dart';
import '../../providers/infrastructure/subsonic_api_client.dart';
import '../../providers/infrastructure/subsonic_server_store.dart';
import '../infrastructure/vanta_audio_handler.dart';

class SubsonicStreamResolverRegistry implements StreamResolverRegistry {
  const SubsonicStreamResolverRegistry({
    required this.store,
    required this.clientFactory,
    this.downloadDatabase,
    this.downloadStorage,
  });

  final SubsonicServerStore store;
  final SubsonicApiClientFactory clientFactory;
  final DownloadDatabase? downloadDatabase;
  final FileDownloadStorage? downloadStorage;

  @override
  Future<Uri> resolve(MediaItem item) async {
    final canonical = _tryParseNonEmpty(item.extras?['canonicalUri']);
    final itemUri = Uri.tryParse(item.id);
    final subsonicUri = canonical?.isScheme('subsonic') == true
        ? canonical
        : itemUri?.isScheme('subsonic') == true
        ? itemUri
        : null;

    if (subsonicUri == null) {
      if (_isSubsonicProvider(item)) {
        throw StateError(
          'Cannot resolve Subsonic stream: missing canonical Subsonic URI.',
        );
      }
      return Uri.parse(item.id);
    }

    final serverId = _serverId(item, subsonicUri);
    final songId = subsonicUri.queryParameters['id'];
    if (serverId == null) {
      throw StateError('Cannot resolve Subsonic stream: missing server id.');
    }
    if (songId == null || songId.isEmpty) {
      throw StateError('Cannot resolve Subsonic stream: missing song id.');
    }

    final offlineResult = await _resolveOfflineUri(
      item,
      serverId: serverId,
      songId: songId,
    );
    if (offlineResult.uri != null) {
      return offlineResult.uri!;
    }

    final server = (await store.loadServers())
        .where((server) => server.id == serverId)
        .firstOrNull;
    if (server == null) {
      throw StateError('Cannot resolve Subsonic stream: server not found.');
    }

    final password = await store.readPassword(server.id);
    if (password == null || password.isEmpty) {
      throw StateError('Cannot resolve Subsonic stream: missing password.');
    }

    try {
      return clientFactory(
        server: server,
        password: password,
      ).streamUri(songId);
    } on SubsonicFailure catch (error) {
      if (offlineResult.invalidatedCompletedFile) {
        throw RemoteTrackResolveException.retryable(
          item: item,
          message:
              'Could not play ${item.title}. Offline copy is unavailable. Retry this track.',
        );
      }
      throw RemoteTrackResolveException.fromSubsonicFailure(
        item: item,
        error: error,
      );
    }
  }

  Future<_OfflineResolutionResult> _resolveOfflineUri(
    MediaItem item, {
    required String serverId,
    required String songId,
  }) async {
    final database = downloadDatabase;
    final storage = downloadStorage;
    if (database == null || storage == null) {
      return const _OfflineResolutionResult();
    }

    final providerId = _providerId(item, serverId);
    final download = await database.getDownload('$providerId::$songId');
    if (download == null || download.status != DownloadStatus.completed) {
      return const _OfflineResolutionResult();
    }

    final localRelativePath = download.localRelativePath;
    if (localRelativePath == null || localRelativePath.isEmpty) {
      await _markOfflineCopyInvalid(
        database,
        storage,
        download,
        code: 'offline-file-missing',
        message: 'Completed download is missing its local file path.',
      );
      return const _OfflineResolutionResult(invalidatedCompletedFile: true);
    }

    final isValid = await storage.isValidCompletedFile(localRelativePath);
    if (!isValid) {
      await _markOfflineCopyInvalid(
        database,
        storage,
        download,
        code: 'offline-file-missing',
        message: 'Completed download is missing or invalid on disk.',
      );
      return const _OfflineResolutionResult(invalidatedCompletedFile: true);
    }

    final file = await storage.resolveFinalFile(localRelativePath);
    return _OfflineResolutionResult(uri: file.uri);
  }

  Future<void> _markOfflineCopyInvalid(
    DownloadDatabase database,
    FileDownloadStorage storage,
    DownloadItem download, {
    required String code,
    required String message,
  }) async {
    await storage.deleteArtifacts(finalRelativePath: download.localRelativePath);
    await database.putDownload(
      download.copyWith(
        status: DownloadStatus.failed,
        retryable: true,
        errorCode: code,
        errorMessage: message,
        completedAt: null,
        updatedAt: DateTime.now().toUtc(),
        lastValidatedAt: DateTime.now().toUtc(),
      ),
    );
  }
}

bool _isSubsonicProvider(MediaItem item) {
  final providerId = item.extras?['providerId']?.toString();
  return providerId?.startsWith('$subsonicProviderPrefix:') ?? false;
}

Uri? _tryParseNonEmpty(Object? value) {
  final text = value?.toString();
  if (text == null || text.isEmpty) return null;
  return Uri.tryParse(text);
}

String? _serverId(MediaItem item, Uri canonical) {
  final uriServerId = canonical.queryParameters['serverId'];
  if (uriServerId != null && uriServerId.isNotEmpty) return uriServerId;

  final providerId = item.extras?['providerId']?.toString();
  if (providerId == null ||
      !providerId.startsWith('$subsonicProviderPrefix:')) {
    return null;
  }
  return providerId.substring('$subsonicProviderPrefix:'.length);
}

String _providerId(MediaItem item, String serverId) {
  final providerId = item.extras?['providerId']?.toString();
  if (providerId != null && providerId.startsWith('$subsonicProviderPrefix:')) {
    return providerId;
  }
  return subsonicProviderId(serverId);
}

class _OfflineResolutionResult {
  const _OfflineResolutionResult({
    this.uri,
    this.invalidatedCompletedFile = false,
  });

  final Uri? uri;
  final bool invalidatedCompletedFile;
}
