# Internal beta checklist

Use this checklist before sharing an Android build for daily use. The goal is stability and real-world feedback, not new features.

## Smoke test

- [ ] Fresh install opens without crashes.
- [ ] Existing install upgrades without losing playlists or playback session.
- [ ] App starts with no required network access.
- [ ] Portrait-only behavior is stable.

## Library and permissions

- [ ] Android 13+ audio permission flow grants library access.
- [ ] Notification permission flow enables playback controls when accepted.
- [ ] Manual folder scan finds FLAC files.
- [ ] Empty library state explains the next action clearly.
- [ ] Large libraries scroll without visible jank after initial warmup.

## Playback

- [ ] Play/pause works from the app, notification, lockscreen, and Bluetooth controls.
- [ ] Next/previous works during rapid taps.
- [ ] Long FLAC playback continues with the screen off.
- [ ] Playback survives app backgrounding and returning to foreground.
- [ ] Session restores the current queue, track, and position after restart.

## Artwork and performance

- [ ] Artwork appears in lists, mini player, now playing, and notification where supported.
- [ ] Missing artwork falls back to the placeholder without crashes.
- [ ] Scroll stays smooth while artwork is loading.
- [ ] Startup has no repeated artwork diagnostic logs unless diagnostics are enabled.

## Release hygiene

- [ ] `flutter test` passes.
- [ ] `flutter build apk --release` succeeds.
- [ ] Version in `pubspec.yaml` is bumped for the beta build.
- [ ] No keystores, `key.properties`, local paths, logs, or generated build outputs are tracked.
- [ ] Release APK is signed with a private beta keystore before sharing outside local testing.
