# Subsonic Provider Specification

## Purpose

Define a reusable Subsonic/OpenSubsonic provider (with Navidrome as first server use case) that adds bounded remote browse/search/stream while preserving local-first playback behavior.

## Requirements

### Requirement: Server Configuration and Secret Handling

The system MUST allow add/edit/delete/test/connect for Subsonic-compatible servers. Credentials MUST be stored only in secure storage and MUST NOT be persisted in plaintext JSON, local DB secret fields, or logs. Non-sensitive server metadata MAY be persisted locally.

#### Scenario: Configure and test server

- GIVEN a user enters server URL, username, and password
- WHEN the user saves and taps Connect
- THEN the app pings the server, shows progress, stores only non-sensitive metadata locally, stores the password securely, selects the server as active on success, and shows success/failure states

#### Scenario: Refresh remote library after connect

- GIVEN a previously saved server is connected successfully
- WHEN the user completes Connect
- THEN the remote preview/search surfaces refresh from the active server

#### Scenario: Persistence boundaries

- GIVEN server configuration was saved
- WHEN local metadata is inspected
- THEN only non-sensitive fields are persisted outside secure storage

### Requirement: Subsonic Auth and API Compatibility

The system MUST authenticate using username + salt + md5(password+salt) token, client id `vanta`, `f=json`, and a compatible Subsonic/OpenSubsonic API version.

#### Scenario: Authenticated request formation

- GIVEN valid credentials and server URL
- WHEN the client sends a Subsonic API request
- THEN request parameters include `u`, `s`, `t`, `c=vanta`, `f=json`, and supported `v`

#### Scenario: Authentication failure

- GIVEN invalid credentials or rejected token
- WHEN an API request is executed
- THEN the app returns an auth error state without leaking credentials

### Requirement: Remote Library and Streaming Operations

The provider MUST support ping, getArtists, getAlbumList2, getAlbum, getSong, search3, stream URL resolution, and getCoverArt. Remote tracks MUST stream and MUST NOT trigger full-download/offline-sync behavior.

#### Scenario: Browse and play remote track

- GIVEN server connection is valid
- WHEN a user browses/searches and starts a remote track
- THEN metadata is loaded via API and playback starts from a stream URL

#### Scenario: No offline full download path

- GIVEN a remote track is queued for playback
- WHEN playback is prepared
- THEN the system resolves a stream endpoint and does not perform full-file sync

### Requirement: Resilience, TLS, and Player Integration

The system MUST handle timeout, server-down, and TLS/certificate errors with explicit user-visible states. The system MUST NOT silently disable TLS validation. Player behavior SHALL remain source-agnostic; local playback MUST remain unaffected while remote playback supports queue/background/metadata/cover art where available.

#### Scenario: Network and TLS failure handling

- GIVEN a server is unreachable or certificate validation fails
- WHEN the client performs ping or content requests
- THEN the app shows an actionable error state and keeps TLS validation enforced

#### Scenario: Source-agnostic playback continuity

- GIVEN local playback works before remote provider setup
- WHEN remote tracks are played, queued, or resumed in background
- THEN local playback behavior remains unchanged and remote metadata/cover are used when available

### Requirement: Typed Remote Failure and Recovery States

The system MUST map server-down, bad URL, invalid credentials, timeout/slow network, TLS/certificate failure, invalid Subsonic response, and HTTP 401/403/404/500 into explicit non-blocking UI states with manual retry.

#### Scenario: Actionable failure state

- GIVEN a remote request fails with any typed failure
- WHEN the failure is handled
- THEN the UI shows a specific unavailable/offline/error state and a Retry action

#### Scenario: Bounded retry behavior

- GIVEN a recoverable network failure
- WHEN automatic retry is attempted
- THEN retries use bounded backoff with a hard cap and MUST NOT loop indefinitely

### Requirement: Provider-Scoped Remote Metadata Cache

The system MUST partition remote metadata cache by `serverId` and `providerId`, MUST show stale status and last sync timestamp, and MUST allow manual refresh. If server is unavailable, cached metadata SHALL still render.

#### Scenario: Cache isolation and stale visibility

- GIVEN metadata exists for two servers
- WHEN one server is selected
- THEN only that server/provider cache is read and stale+last-sync are visible

#### Scenario: Unavailable server uses cache

- GIVEN the active server is down and cached metadata exists
- WHEN a library surface loads
- THEN cached metadata renders with an unavailable/stale indicator

### Requirement: Bounded Remote Browse and Search

The system MUST avoid N+1 full-library hydration for remote browse/search and MUST use bounded, incremental requests with timeout handling.

#### Scenario: Large remote library remains bounded

- GIVEN a large Subsonic server library
- WHEN browse or search loads remote content
- THEN requests stay bounded and timeout failures surface as retryable states

### Requirement: Basic Multi-Server Operations

The system MUST support list active server, switch active, edit, delete, and test connection. Deleting a server MUST clear only that server's credentials and remote cache.

#### Scenario: Test connection does not switch server on failure

- GIVEN a saved inactive server has invalid settings
- WHEN the user tests connection
- THEN failure is shown and the active server remains unchanged

#### Scenario: Delete server isolates cleanup

- GIVEN multiple configured servers
- WHEN one server is deleted
- THEN only deleted-server secrets/cache are removed and other servers remain intact

### Requirement: Remote Playback Robustness and Secret Hygiene

The system MUST allow queue continuation when one remote track fails, MUST expose Now Playing error and manual retry for failed track, and MUST keep metadata/notification consistent. The system MUST NOT log or persist passwords, tokens, or auth URLs in plaintext logs/cache/session.

#### Scenario: Single-track failure does not break queue

- GIVEN a queue with remote tracks
- WHEN one track stream resolution fails
- THEN failure is visible for that track and queue playback continues for remaining tracks

#### Scenario: Security redaction

- GIVEN remote failures and diagnostics are emitted
- WHEN logs/cache/session artifacts are inspected
- THEN credentials, tokens, and auth URLs are absent or redacted

### Requirement: Scope Boundaries for Reliability Hardening

This modification MUST NOT introduce full offline downloads/sync, new provider families (Jellyfin/YT/SMB/WebDAV), complex multi-server merge/sync/cross-server playlists, or visual redesign.

#### Scenario: Reliability-only delivery

- GIVEN this change is verified
- WHEN acceptance criteria are checked
- THEN excluded capabilities are not required for completion
