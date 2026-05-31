# Proposal: v0.4.1 Navidrome Online Polish & Reliability

## Intent

Harden existing Navidrome/Subsonic support for daily use without redesign. Improve failures, bounded networking, playback recovery, source-aware intelligence, artwork caching, server management, and regression coverage while preserving local/offline-first behavior and premium dark/minimal UI.

## Scope

### In Scope
- Map typed failures to clear UI states, manual retry, and bounded retry/backoff.
- Replace `getTracks()` N+1 hydration with bounded/incremental remote loading.
- Harden playback refresh, queue/session recovery, sanitized persistence, and fail-closed resolution.
- Improve provider-scoped cache behavior, placeholders, diagnostics, and redaction.
- Add source-aware guardrails for favorites, history, stats, search/navigation.
- Add multi-server management: list, switch, rename, remove, retest.
- Add docs/tests for reliability, security, performance, local safety.

### Out of Scope
- Offline downloads/sync, library merge, complex multi-server sync/playlists.
- Jellyfin, YouTube Music, SMB/WebDAV, or new provider families.
- Architecture rewrite, Drift migration, redesign, or local playback changes.

## Capabilities

### New Capabilities
- None.

### Modified Capabilities
- `subsonic-provider`: reliability, retry/error UX, bounded browse/search, cache interaction, basic server management, playback robustness, security hygiene.
- `intelligent-library`: source-aware favorites/history/stats/search/navigation guardrails without default local/remote mixing.
- `premium-metadata`: artwork cache behavior, placeholder fallback, bounded fetches, diagnostics, sanitization.

## Approach

Use progressive hardening inside current provider/player/cache/library boundaries. Sequence small work units: errors, retry, browse performance, artwork cache, playback, intelligence, search/navigation, server management, security/performance, docs/tests.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `lib/features/providers/**` | Modified | API reliability, browse/search, servers. |
| `lib/features/player/**` | Modified | Stream/session recovery. |
| `lib/features/library/**` | Modified | Remote navigation, errors, search. |
| `lib/features/library_intelligence/**` | Modified | Source-aware guardrails. |
| `lib/shared/artwork_cache/**` | Modified | Cache, placeholders, redaction. |
| `test/**` | Modified | Reliability/local-safety coverage. |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Large libraries feel slow | Med | Bound requests, avoid N+1 paths, test timeouts. |
| Retry loops harm UX/battery | Med | Bounded backoff and manual retry. |
| Source identity drift | Med | Add local/remote tests. |
| Secret leakage in diagnostics | Low | Redaction audits and sanitized URL assertions. |

## Rollback Plan

Revert progressive work units or disable remote-only UI affordances. Local playback, library, and persisted data remain compatible because no schema or rewrite is planned.

## Dependencies

- Existing Subsonic provider, secure storage, artwork cache, player, Riverpod providers.

## Success Criteria

- [ ] Remote errors are actionable and never retry indefinitely.
- [ ] Remote browse/search/playback stay bounded and preserve local behavior.
- [ ] Artwork renders placeholders first, caches safely, and does not leak secrets.
- [ ] Multi-server management supports basic recovery workflows.
- [ ] Tests/docs cover reliability, source separation, security, and performance guardrails.
