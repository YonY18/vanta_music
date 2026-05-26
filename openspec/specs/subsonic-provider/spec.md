# Subsonic Provider Specification

## Purpose

Define a reusable Subsonic/OpenSubsonic provider (with Navidrome as first server use case) that adds remote browse/search/stream while preserving local-first playback behavior.

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
- THEN the remote library/search surfaces refresh from the active server

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
