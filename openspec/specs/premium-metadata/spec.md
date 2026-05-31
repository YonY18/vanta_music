# Premium Metadata Specification

## Purpose

Define enriched metadata while preserving offline-first responsiveness and visual identity.

## Requirements

### Requirement: Non-Blocking Artwork Resolution

The system MUST resolve missing artwork through local-first fallbacks and MUST preserve first paint responsiveness.

#### Scenario: Fallback artwork without blocking first paint

- GIVEN a track or album has no primary artwork
- WHEN a library surface renders the item
- THEN the UI renders immediately with a styled placeholder while fallback resolution runs asynchronously

### Requirement: Bounded Artwork Cache

The system MUST use a bounded cache for artwork/fallback results and MUST avoid repeated lookups for previously evaluated items.

#### Scenario: Reopen view after fallback evaluation

- GIVEN an item fallback result is cached (hit or miss)
- WHEN the same item is rendered again
- THEN the system reuses cached outcome without duplicate lookup within cache policy limits

### Requirement: Palette Extraction Must Not Block Interaction

The system SHOULD derive and cache artwork palettes; palette work MUST NOT block first paint, scrolling, or playback.

#### Scenario: Palette unavailable at initial render

- GIVEN artwork exists but no palette is cached
- WHEN the item first appears on screen
- THEN base UI colors render immediately and palette enrichment applies later without visible jank

### Requirement: Local Metadata Overrides

The system MUST allow local override of basic metadata fields and MUST keep overrides reversible and isolated from source files unless explicit save/export is introduced later.

#### Scenario: Apply and revert local override

- GIVEN a user edits a track title locally
- WHEN the override is saved and later reverted
- THEN library views show overridden then source metadata and source files remain unchanged

### Requirement: Optional Artist Enrichment Contracts

The system MAY expose artist artwork/biography model or interface contracts, but these MUST NOT require network providers in this change.

#### Scenario: Artist enrichment capability not implemented remotely

- GIVEN artist enrichment providers are absent
- WHEN artist data is requested
- THEN the system returns local/empty contract-safe values with no mandatory network feature

### Requirement: Placeholder and Offline Guardrails

The system MUST keep placeholders consistent with style tokens, MUST preserve offline-first behavior, and MUST avoid unbounded memory growth or unnecessary network requests.

#### Scenario: Offline rendering with missing metadata

- GIVEN the device is offline and metadata/artwork is incomplete
- WHEN library screens load
- THEN placeholders and fallback metadata render consistently with no blocking network dependency

### Requirement: Remote Artwork Fetch and Cache Guardrails

The system MUST support artwork retrieval for remote Subsonic items and MUST apply bounded caching so first paint and scrolling remain responsive.

#### Scenario: Async remote artwork render

- GIVEN a remote album/track has cover art
- WHEN a list item first renders
- THEN UI paints immediately with placeholder/fallback and remote artwork resolves asynchronously

#### Scenario: Cache prevents repeated heavy fetches

- GIVEN a remote artwork result was cached
- WHEN the same item re-enters viewport
- THEN cached outcome is reused within cache policy limits

### Requirement: Sensitive Data Hygiene in Metadata Paths

The system MUST avoid auth leakage in logs, error messages, and generated URLs where avoidable; credentials and tokens MUST NOT be emitted in plaintext telemetry.

#### Scenario: Logging during remote metadata failure

- GIVEN a remote cover or metadata request fails
- WHEN diagnostic logs are produced
- THEN logs include actionable context but redact or omit secrets/tokens

#### Scenario: Remote URL handling

- GIVEN a stream or cover endpoint requires auth parameters
- WHEN URLs are stored, displayed, or reported
- THEN the app uses sanitized forms outside transport paths where feasible

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

### Requirement: Scope Boundaries for Remote Artwork Hardening

This modification MUST NOT introduce visual redesign, full offline artwork sync/downloads, new provider families, or cross-server artwork merge behavior.

#### Scenario: Premium style preserved

- GIVEN this change is accepted
- WHEN artwork fallback states are reviewed
- THEN existing premium visual language is preserved without redesign
