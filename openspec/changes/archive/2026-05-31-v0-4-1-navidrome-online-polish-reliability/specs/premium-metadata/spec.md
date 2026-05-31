# Delta for premium-metadata

## ADDED Requirements

### Requirement: Server-Scoped Remote Artwork Cache

The system MUST cache remote artwork by `serverId` and `coverArtId`, MUST deduplicate concurrent downloads for the same key, and MUST NOT reuse artwork across servers unless keys match in the same server scope.

#### Scenario: Artwork cache is server isolated
- GIVEN two servers expose the same cover art id
- WHEN artwork is requested from server A
- THEN only server A cache entries are read or written

#### Scenario: Duplicate download is coalesced
- GIVEN multiple visible items request the same server/coverArt key
- WHEN downloads start concurrently
- THEN one network fetch is used and all callers receive the same result

### Requirement: Missing or Corrupt Artwork Fallback

The system MUST render premium-consistent placeholders for missing, failed, or corrupt remote artwork and MUST cache failed outcomes within policy limits to avoid repeated heavy fetches.

#### Scenario: Corrupt artwork does not break rendering
- GIVEN a remote cover response is corrupt
- WHEN a library item renders
- THEN a styled placeholder is shown and diagnostics omit secrets

### Requirement: Lightweight Artwork Loading

The system MUST lazy-load artwork for scrollable surfaces, SHOULD lightly precache now-playing and queue artwork, and MUST NOT block scrolling, first paint, or playback controls on artwork resolution.

#### Scenario: Scroll remains responsive
- GIVEN a remote album list is scrolling
- WHEN artwork is unresolved
- THEN placeholders render immediately and artwork resolves asynchronously

#### Scenario: Now playing and queue are lightly prepared
- GIVEN remote tracks enter now playing or queue
- WHEN artwork keys are known
- THEN lightweight precache MAY start without full offline sync/download behavior

### Requirement: Scope Boundaries

This delta MUST NOT introduce visual redesign, full offline artwork sync/downloads, new provider families, or cross-server artwork merge behavior.

#### Scenario: Premium style preserved
- GIVEN this change is accepted
- WHEN artwork fallback states are reviewed
- THEN existing premium visual language is preserved without redesign
