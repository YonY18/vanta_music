# Delta for intelligent-library

## ADDED Requirements

### Requirement: Source-Scoped Intelligence Identity

The system MUST preserve provider/server identity for remote favorites, history, stats, recent, and continue-listening records. Remote records MUST NOT collide with local records or other servers.

#### Scenario: Identity preserved in history and favorites
- GIVEN a remote track from server A
- WHEN user favorites it and plays it
- THEN favorites/history records store provider+server identity with track identity

#### Scenario: No collisions across sources
- GIVEN matching track IDs exist in local and server B
- WHEN stats/recent/continue views compute data
- THEN each source is counted independently without overwrite

### Requirement: Remote Search and Navigation Resilience

Remote search/navigation MUST provide debounce, loading, empty, and error states. The system MUST cancel stale search requests/results and SHOULD keep source labels explicit on rendered items.

#### Scenario: Debounced search with stale cancellation
- GIVEN a user types multiple queries quickly
- WHEN a newer query is issued
- THEN older in-flight remote search results are ignored/canceled

#### Scenario: Clear remote state signaling
- GIVEN a remote search returns none or fails
- WHEN results render
- THEN the UI shows explicit empty/error state and preserves source labels

### Requirement: Scope Boundaries

This delta MUST NOT require full offline sync/downloads, provider expansion beyond Subsonic scope, cross-server merge/sync playlists, or visual redesign.

#### Scenario: Bounded intelligent-library scope
- GIVEN this delta is validated
- WHEN out-of-scope capabilities are reviewed
- THEN excluded scope is not required for acceptance
