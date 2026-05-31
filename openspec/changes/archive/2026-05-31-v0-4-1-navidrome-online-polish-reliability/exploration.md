## Exploration: v0.4.1 — Navidrome Online Polish & Reliability

### Current State
Subsonic/Navidrome is already integrated with secure token auth (`u/s/t`), typed failures (timeout/TLS/auth/server/malformed), server-scoped provider identities, and fail-closed stream/artwork resolution for missing canonical URI/server/password. Playback session persistence sanitizes auth-bearing URLs and reconstructs canonical `subsonic://` identity.

Remote browsing currently uses `remoteLibraryTracksProvider -> provider.getTracks()`, where `SubsonicMusicProvider.getTracks()` fetches album list then calls `getAlbum()` per album (N+1 network pattern). Remote search API exists (`search3`) but is not wired into remote UX. Multi-server state exists in storage (list + active server + secure password) but UI only supports connect/activate (no switch/edit/delete/manage flow).

Artwork caching is provider-scoped: cache key includes `providerId|trackId|source|size`, and remote source key includes `remote-cover:{providerId}:{coverArtId}`. This means cache separation by server/provider is already present and collision-resistant for Subsonic servers.

### Affected Areas
- `lib/features/providers/infrastructure/subsonic_api_client.dart` — request reliability primitives (timeouts/retry/backoff/error enrichment/redaction consistency).
- `lib/features/providers/infrastructure/subsonic_music_provider.dart` — remote browse/search behavior; current `getTracks()` N+1 fragility.
- `lib/features/providers/infrastructure/subsonic_server_store.dart` — multi-server metadata workflows and active-server transitions.
- `lib/features/providers/application/subsonic_providers.dart` — provider lifecycle/caching/reload boundaries.
- `lib/features/player/application/subsonic_stream_resolver_registry.dart` — reconnect/fail-closed stream refresh guarantees.
- `lib/features/player/infrastructure/vanta_audio_handler.dart` — robust playback recovery and queue/session resilience.
- `lib/features/player/domain/playback_session.dart` — remote-safe canonical persistence guardrails.
- `lib/features/library/application/library_providers.dart` — remote source hydration, remote search provider wiring, invalidation policy.
- `lib/features/library/presentation/library_screen.dart` — remote UX, actionable errors, online search/navigation, server management entry points.
- `lib/shared/artwork_cache/artwork_cache_resolver.dart` — remote artwork fallback/cache behavior and diagnostics.
- `lib/shared/artwork_cache/subsonic_remote_artwork_bytes_source.dart` — credentialed remote artwork retrieval robustness.
- `lib/features/library_intelligence/*` — source-aware favorites/history/stats consistency across local+remote.
- `test/features/providers/**`, `test/features/player/**`, `test/shared/artwork_cache/**`, `test/features/library_intelligence/**` — regression coverage for hardening.

### Approaches
1. **Progressive hardening in current architecture** — add reliability layers and UX polish around existing provider/player/cache boundaries without structural rewrite.
   - Pros: aligns with constraints (no redesign, minimal progressive change, local behavior safety); fastest path to daily-use reliability; low migration risk.
   - Cons: some technical debt remains (e.g., provider-specific logic spread across screens/providers); may require disciplined sequencing to avoid regressions.
   - Effort: Medium

2. **Introduce a broader online-domain abstraction first** — centralize remote lifecycle/search/retry/server management before feature hardening.
   - Pros: cleaner long-term model and fewer duplicated concerns.
   - Cons: violates “no redesign/rewrite architecture” constraint and raises risk to local stability/scope.
   - Effort: High

### Recommendation
Use **Approach 1**. The codebase already has the right primitives (typed failures, fail-closed resolver, provider-scoped identities, secure secret boundaries). v0.4.1 should layer reliability/UX/performance improvements incrementally on these primitives, with strict regression coverage to protect local playback and premium dark/minimal UX.

Minimal progressive plan and suggested sequencing (11 phases):
1. Error taxonomy + UX mapping (typed failures → actionable UI copy/retry hints).
2. Lightweight reconnect policy (bounded retry/backoff + manual retry affordances).
3. Remote library load reliability/perf (replace `getTracks()` N+1 with bounded incremental loading).
4. Remote metadata/artwork cache hardening (TTL/eviction diagnostics; keep provider/server partitioning).
5. Playback robustness online (queue/session recovery edge cases, stale URI refresh, fail-closed semantics).
6. Source-aware intelligence parity (favorites/history/stats assertions for local + remote identities).
7. Online search/navigation UX (wire `remoteSearchTracksProvider`; preserve local/remote separation).
8. Basic multi-server management UI (list/switch/rename/remove/retest, no architecture rewrite).
9. Security hardening pass (log redaction audits, URL sanitization checks, secret lifecycle checks).
10. Performance polish pass (bounded pagination/lazy rendering; cache warmup tuning).
11. Docs + regression tests finalization (runbook, UX notes, provider/player/cache/intelligence test expansion).

### Risks
- **Remote browse latency/timeouts at scale** due to `getTracks()` N+1 album expansion; can degrade UX and battery/network usage.
- **User trust risk from partial server UX** (connect-only flow) when credentials rotate/server changes occur, causing confusing recovery paths.
- **Inconsistent online discoverability** because remote search API exists but is not surfaced in navigation.
- **Cross-source intelligence drift** if favorites/history/stats mapping is not explicitly validated for remote-only/library-missing states.

### Ready for Proposal
Yes — propose a constrained hardening plan split into 11 progressive phases with strict “no redesign, no local regressions” acceptance gates.
