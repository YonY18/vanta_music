import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SubsonicServerConfig {
  const SubsonicServerConfig({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.username,
    this.apiVersion = defaultApiVersion,
  });

  static const defaultApiVersion = '1.16.1';

  final String id;
  final String name;
  final String baseUrl;
  final String username;
  final String apiVersion;

  SubsonicServerConfig normalized() {
    return SubsonicServerConfig(
      id: _requireText(id, 'id'),
      name: _requireText(name, 'name'),
      baseUrl: _normalizeBaseUrl(baseUrl),
      username: _requireText(username, 'username'),
      apiVersion: _requireText(apiVersion, 'apiVersion'),
    );
  }

  Map<String, Object?> toJson() {
    final normalizedConfig = normalized();
    return <String, Object?>{
      'id': normalizedConfig.id,
      'name': normalizedConfig.name,
      'baseUrl': normalizedConfig.baseUrl,
      'username': normalizedConfig.username,
      'apiVersion': normalizedConfig.apiVersion,
    };
  }

  static SubsonicServerConfig fromJson(Map<String, Object?> json) {
    return SubsonicServerConfig(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      baseUrl: json['baseUrl'] as String? ?? '',
      username: json['username'] as String? ?? '',
      apiVersion: json['apiVersion'] as String? ?? defaultApiVersion,
    ).normalized();
  }
}

class SubsonicServerState {
  const SubsonicServerState({this.servers = const [], this.activeServerId});

  final List<SubsonicServerConfig> servers;
  final String? activeServerId;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'servers': servers
          .map((server) => server.toJson())
          .toList(growable: false),
      'activeServerId': activeServerId,
    };
  }

  static SubsonicServerState fromJson(Map<String, Object?> json) {
    final rawServers = json['servers'];
    final servers = rawServers is List<Object?>
        ? rawServers
              .whereType<Map<String, Object?>>()
              .map(SubsonicServerConfig.fromJson)
              .toList(growable: false)
        : const <SubsonicServerConfig>[];
    final activeServerId = json['activeServerId'] as String?;
    return SubsonicServerState(
      servers: servers,
      activeServerId: activeServerId?.trim().isEmpty == true
          ? null
          : activeServerId,
    );
  }
}

abstract class SubsonicServerMetadataStore {
  Future<SubsonicServerState> read();
  Future<void> write(SubsonicServerState state);
}

class FileSubsonicServerMetadataStore implements SubsonicServerMetadataStore {
  const FileSubsonicServerMetadataStore(this.file);

  final File file;

  @override
  Future<SubsonicServerState> read() async {
    if (!await file.exists()) return const SubsonicServerState();
    final content = await file.readAsString();
    if (content.trim().isEmpty) return const SubsonicServerState();
    final decoded = jsonDecode(content);
    if (decoded is! Map<String, Object?>) return const SubsonicServerState();
    return SubsonicServerState.fromJson(decoded);
  }

  @override
  Future<void> write(SubsonicServerState state) async {
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(state.toJson()));
  }
}

abstract class SubsonicSecretStore {
  Future<String?> readPassword(String serverId);
  Future<void> writePassword(String serverId, String password);
  Future<void> deletePassword(String serverId);
}

abstract class SubsonicServerCleanup {
  Future<void> deleteServerData(String serverId);
}

class FlutterSecureSubsonicSecretStore implements SubsonicSecretStore {
  const FlutterSecureSubsonicSecretStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> readPassword(String serverId) {
    return _storage.read(key: _passwordKey(serverId));
  }

  @override
  Future<void> writePassword(String serverId, String password) {
    return _storage.write(key: _passwordKey(serverId), value: password);
  }

  @override
  Future<void> deletePassword(String serverId) {
    return _storage.delete(key: _passwordKey(serverId));
  }
}

class InMemorySubsonicSecretStore implements SubsonicSecretStore {
  final Map<String, String> _passwords = <String, String>{};

  @override
  Future<String?> readPassword(String serverId) async =>
      _passwords[_passwordKey(serverId)];

  @override
  Future<void> writePassword(String serverId, String password) async {
    _passwords[_passwordKey(serverId)] = password;
  }

  @override
  Future<void> deletePassword(String serverId) async {
    _passwords.remove(_passwordKey(serverId));
  }
}

class SubsonicServerStore {
  const SubsonicServerStore({
    required this.metadataStore,
    required this.secretStore,
    this.cleanupHooks = const <SubsonicServerCleanup>[],
  });

  final SubsonicServerMetadataStore metadataStore;
  final SubsonicSecretStore secretStore;
  final List<SubsonicServerCleanup> cleanupHooks;

  Future<List<SubsonicServerConfig>> loadServers() async {
    return (await metadataStore.read()).servers;
  }

  Future<SubsonicServerConfig?> loadServer(String serverId) async {
    final normalizedId = _requireText(serverId, 'serverId');
    final servers = await loadServers();
    return servers.where((server) => server.id == normalizedId).firstOrNull;
  }

  Future<SubsonicServerConfig?> loadActiveServer() async {
    final activeServerId = await readActiveServer();
    if (activeServerId == null) return null;
    return loadServer(activeServerId);
  }

  Future<void> saveServer(
    SubsonicServerConfig config, {
    String? password,
  }) async {
    final normalized = config.normalized();
    final state = await metadataStore.read();
    final updatedServers = [...state.servers];
    final index = updatedServers.indexWhere(
      (server) => server.id == normalized.id,
    );
    if (index == -1) {
      updatedServers.add(normalized);
    } else {
      updatedServers[index] = normalized;
    }
    await metadataStore.write(
      SubsonicServerState(
        servers: updatedServers,
        activeServerId: _activeIdIfPresent(
          state.activeServerId,
          updatedServers,
        ),
      ),
    );
    if (password != null) {
      await secretStore.writePassword(normalized.id, password);
    }
  }

  Future<void> deleteServer(String serverId) async {
    final normalizedId = _requireText(serverId, 'serverId');
    final state = await metadataStore.read();
    final deletedServer = state.servers.where(
      (server) => server.id == normalizedId,
    );
    if (deletedServer.isEmpty) return;
    final updatedServers = state.servers
        .where((server) => server.id != normalizedId)
        .toList(growable: false);
    await metadataStore.write(
      SubsonicServerState(
        servers: updatedServers,
        activeServerId: _activeIdIfPresent(
          state.activeServerId,
          updatedServers,
        ),
      ),
    );
    await secretStore.deletePassword(normalizedId);
    for (final cleanup in cleanupHooks) {
      await cleanup.deleteServerData(normalizedId);
    }
  }

  Future<void> selectActiveServer(String serverId) async {
    final normalizedId = _requireText(serverId, 'serverId');
    final state = await metadataStore.read();
    final exists = state.servers.any((server) => server.id == normalizedId);
    if (!exists) {
      throw StateError('Cannot select unknown Subsonic server.');
    }
    await metadataStore.write(
      SubsonicServerState(servers: state.servers, activeServerId: normalizedId),
    );
  }

  Future<String?> readActiveServer() async {
    return (await metadataStore.read()).activeServerId;
  }

  Future<String?> readPassword(String serverId) {
    return secretStore.readPassword(serverId);
  }
}

String? _activeIdIfPresent(
  String? activeServerId,
  List<SubsonicServerConfig> servers,
) {
  if (activeServerId == null) return null;
  return servers.any((server) => server.id == activeServerId)
      ? activeServerId
      : null;
}

String _passwordKey(String serverId) {
  return 'subsonic.server.${_requireText(serverId, 'serverId')}.password';
}

String _normalizeBaseUrl(String value) {
  final text = _requireText(value, 'baseUrl');
  final uri = Uri.parse(text);
  if (!uri.hasScheme || uri.host.isEmpty) {
    throw ArgumentError.value(value, 'baseUrl', 'must be an absolute URL');
  }
  return text.replaceFirst(RegExp(r'/+$'), '');
}

String _requireText(String value, String fieldName) {
  final text = value.trim();
  if (text.isEmpty) {
    throw ArgumentError.value(value, fieldName, 'must not be empty');
  }
  return text;
}
