import 'package:flutter_test/flutter_test.dart';
import 'package:vanta_music/features/downloads/domain/download_item.dart';

void main() {
  test('builds stable provider-neutral download identity keys', () {
    const identity = DownloadIdentity(
      providerFamily: 'subsonic',
      providerId: 'subsonic:home',
      serverId: 'home',
      trackId: 'track-42',
      remoteItemId: 'subsonic:home:track-42',
      canonicalUri: 'subsonic://track?serverId=home&id=track-42',
    );

    expect(identity.downloadKey, 'subsonic:home::track-42');
    expect(identity.safeServerSegment, 'home');
    expect(identity.safeTrackSegment, 'track-42');
  });

  test('creates queued download items with immutable manifest metadata', () {
    final queued = DownloadItem.createQueued(
      identity: const DownloadIdentity(
        providerFamily: 'subsonic',
        providerId: 'subsonic:home',
        serverId: 'home',
        trackId: 'track-42',
        remoteItemId: 'subsonic:home:track-42',
        canonicalUri: 'subsonic://track?serverId=home&id=track-42',
      ),
      title: 'Track 42',
      artist: 'The Artist',
      album: 'The Album',
      coverArtId: 'cover-42',
      now: DateTime.utc(2026, 5, 31, 15),
    );

    expect(queued.status, DownloadStatus.queued);
    expect(queued.progressBytes, 0);
    expect(queued.totalBytes, isNull);
    expect(queued.localRelativePath, isNull);
    expect(queued.tempRelativePath, isNull);
    expect(queued.downloadKey, 'subsonic:home::track-42');
  });
}
