import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../infrastructure/subsonic_api_client.dart';
import '../infrastructure/subsonic_server_store.dart';

typedef SubsonicApiClientFactory =
    SubsonicApiClientContract Function({
      required SubsonicServerConfig server,
      required String password,
    });

final subsonicApiClientFactoryProvider = Provider<SubsonicApiClientFactory>(
  (ref) =>
      ({required server, required password}) =>
          SubsonicApiClient(server: server, password: password),
);

final subsonicServerStoreProvider = FutureProvider<SubsonicServerStore>((
  ref,
) async {
  final directory = await getApplicationSupportDirectory();
  return SubsonicServerStore(
    metadataStore: FileSubsonicServerMetadataStore(
      File('${directory.path}/subsonic_servers.json'),
    ),
    secretStore: const FlutterSecureSubsonicSecretStore(),
  );
});
