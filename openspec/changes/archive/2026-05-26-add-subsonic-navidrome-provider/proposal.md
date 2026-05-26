# Proposal: Add Subsonic/Navidrome Provider

## Intent

Add initial Navidrome support through a reusable Subsonic/OpenSubsonic provider while preserving local-first playback, offline responsiveness, and current style.

## Scope

### In Scope
- Server config, ping/test connection, and secure credentials via `flutter_secure_storage`.
- JSON Subsonic library read/search plus stream and cover URL resolution.
- Source-separated remote library/search UI.
- Remote playback through existing queue/player with dynamic stream resolution.
- Remote cover fetch/cache with bounded, non-blocking artwork behavior.
- Manual Navidrome testing documentation.

### Out of Scope
- Full downloads, bidirectional sync, multi-device sync, or unified local+remote library.
- Remote metadata editing, YouTube Music, Jellyfin, SMB/WebDAV, or other non-Subsonic providers.
- Full Drift migration unless minimal non-sensitive server metadata persistence is justified.
- Redesign or local playback behavior changes.

## Capabilities

### New Capabilities
- `subsonic-provider`: reusable Subsonic/OpenSubsonic config, auth, read/search, stream, cover, and playback integration.

### Modified Capabilities
- `intelligent-library`: source identity/display must support a separate remote source without mixing into local smart sections.
- `premium-metadata`: artwork/cache must support remote cover bytes without blocking first paint or unbounded network work.

## Approach

Build `SubsonicApiClient` + `SubsonicMusicProvider`; expose Navidrome as the first server config. Store secrets only in secure storage, keep server metadata non-sensitive, resolve streams dynamically, and keep remote UI separate.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `lib/features/providers/...` | New/Modified | Subsonic client, provider, config, credentials. |
| `lib/features/library/...` | Modified | Remote read/search and provider identity. |
| `lib/features/player/...` | Modified | Dynamic provider stream resolution without breaking local playback. |
| `lib/shared/artwork_cache/...` | Modified | Remote cover byte source and bounded cache behavior. |
| `pubspec.yaml` | Modified | Add secure credential/network dependencies. |
| `test/...`, `docs/...` | New/Modified | Provider/playback/artwork tests and Navidrome guide. |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Local playback regression | Med | Isolate provider resolution and cover local paths with focused tests. |
| Auth URLs leak secrets | Med | No plaintext passwords; sanitize logs/errors; prefer secure credential APIs. |
| Remote artwork hurts scroll | Med | Async bounded cache; no blocking first paint. |

## Rollback Plan

Remove Subsonic provider/config UI and dependency additions; restore direct URI loading for local tracks if needed.

## Dependencies

- `flutter_secure_storage`; existing Flutter/Riverpod/audio stack; Navidrome-compatible Subsonic test server.

## Success Criteria

- [ ] Local playback, playlists, favorites, history, and smart sections remain stable.
- [ ] A Navidrome server can be configured, tested, searched, browsed separately, and streamed.
- [ ] Remote credentials are never stored as plaintext.
- [ ] Remote artwork loads asynchronously without scroll/playback regressions.
