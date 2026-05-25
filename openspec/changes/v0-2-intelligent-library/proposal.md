# Proposal: v0.2 Intelligent Library

## Intent

Make Vanta Music feel more personal without a redesign: smarter local surfaces, favorites, playlists, playback history, queue access, stats, premium empty states, and performant data access.

## Scope

### In Scope
- Polish favorites, smart sections, fallbacks, and navigation.
- Improve local playlists with detail view and track removal.
- Add local playback history, basic stats, and lightweight queue read/jump UX.
- Add premium empty states for deferred cloud/sync/AI features.
- Harden JSON access with limits, debounced writes, and tests.

### Out of Scope
- Full visual redesign or new design system.
- YouTube Music, Navidrome, Jellyfin, online sync, AI, heavy visualizer.
- Drift/SQLite migration, advanced queue reorder, or analytics beyond local basics.

## Capabilities

### New Capabilities
- `intelligent-library`: Local personalization, favorites, playlists MVP+, history, queue UX, stats, premium empty states, and performance guardrails.

### Modified Capabilities
- None; no existing `openspec/specs/` capabilities found.

## Approach

Use the exploration’s JSON-first incremental approach. Extend existing Riverpod providers, file stores, and clean feature boundaries. Keep UI changes surgical and split work into reviewable slices under the 400-line budget.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `lib/features/library/presentation/` | Modified | Smart sections, stats, empty states, playlist views. |
| `lib/features/library_intelligence/` | Modified | Snapshot mapping, stats, history/favorites, performance limits. |
| `lib/features/playlists/` | Modified | Playlist detail and remove-track flow over JSON store. |
| `lib/features/player/` | Modified | Playback events, session/queue read and jump behavior. |
| `test/features/**` | Modified | Regression tests for intelligence, playlists, queue, and limits. |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| JSON snapshots grow too large | Med | Cap list sizes, keep debounced writes, avoid Drift scope creep. |
| Provider invalidations cause broad rebuilds | Med | Prefer scoped providers/selectors and add regression tests. |
| Premium states feel like dead ends | Low | Make copy explicit: coming soon, not broken functionality. |
| v0.2 scope expands past beta stability | Med | Keep slices incremental and defer heavy integrations. |

## Rollback Plan

Revert v0.2 slices and keep existing JSON compatible. New optional fields default safely when absent so beta users retain current library, playlists, and session behavior.

## Dependencies

- Existing JSON stores and Riverpod architecture.
- No new heavy runtime dependencies.

## Success Criteria

- [ ] Existing beta library/playback behavior remains compatible.
- [ ] Favorites, playlists, history, queue, stats, and smart sections work locally.
- [ ] UI keeps current visual style with premium empty states for deferred features.
- [ ] Tests cover core local intelligence, playlist, and queue regressions.
