# Delta for Premium Metadata

## ADDED Requirements

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
