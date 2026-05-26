# Proposal: v0.3 Premium Metadata Core

## Intent

Start Vanta Music v0.3 with a safe premium foundation: richer metadata/artwork behavior that feels native, fast, offline-first, and visually unchanged. This avoids turning “ecosystem” into a risky rewrite while preparing clean interfaces for later providers and storage upgrades.

## Scope

### In Scope
- Metadata/artwork abstraction for local-first enriched display.
- Missing artwork resolution pipeline with bounded cache reuse and intelligent fallback.
- Dynamic color extraction interface/cache for future premium surfaces.
- Basic local metadata override model/store using current lightweight persistence.
- UI placeholders integrated into existing screens without redesign.
- Performance guardrails for cache size, lazy work, and non-blocking resolution.

### Out of Scope
- Lyrics, karaoke, heavy FX, or large animation systems.
- Advanced queue reorder UX and broad performance overhaul.
- Full Drift migration or replacement of existing JSON stores.
- Full Navidrome/Jellyfin/SMB/WebDAV/provider implementations.
- Full desktop rollout or platform packaging work.

## Capabilities

### New Capabilities
- `premium-metadata`: Local-first enriched metadata, artwork fallback, bounded cache behavior, palette extraction contracts, and user metadata overrides.

### Modified Capabilities
- `intelligent-library`: Library display MAY consume premium metadata/artwork fallbacks while preserving stateless, bounded, responsive list behavior.

## Approach

Use the exploration’s progressive JSON-first path. Add domain/application interfaces first, then file-backed implementations and small UI integration points. Preserve current style tokens and screen structure. Avoid network/provider lock-in; future ecosystem integrations should plug into contracts, not drive this slice.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `lib/shared/artwork_cache/` | Modified | Extend fallback/cache policy behavior. |
| `lib/features/library/domain/` | Modified | Add enriched metadata/override model. |
| `lib/features/library/application/` | Modified | Resolve metadata/artwork without blocking UI. |
| `lib/features/library/presentation/` | Modified | Add premium placeholders with current visual style. |
| `test/shared/`, `test/features/library/` | Modified | Cover cache, fallback, and override behavior. |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Scope creep into ecosystem rebuild | Med | Keep providers as interfaces only. |
| UI rebuild/performance regressions | Med | Lazy resolution, bounded cache, focused tests. |
| Metadata state fragmentation | Low | Single local override store and repository boundary. |

## Rollback Plan

Revert this change folder and implementation commits. Since no migration or provider rollout is included, existing local library, artwork cache, playlists, and playback state remain usable.

## Dependencies

- Existing artwork cache and intelligent library behavior.
- No new external provider dependency required.

## Success Criteria

- [ ] Missing artwork resolves through deterministic local-first fallbacks.
- [ ] Metadata overrides persist locally without Drift migration.
- [ ] Palette extraction is cached/interface-driven and does not block scroll/playback.
- [ ] Existing visual style and intelligent-library responsiveness are preserved.
