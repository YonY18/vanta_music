# Intelligent Library Specification

## Purpose

Define local-first library intelligence so users can manage favorites, playlists, listening progress, queue actions, and lightweight insights without external services.

## Requirements

### Requirement: Persistent Favorites

The system MUST treat favorites as a persistent first-class library feature and retain favorite state across app restarts.

#### Scenario: Favorite a track from supported surfaces

- GIVEN a track is visible in song list, now playing, or mini-player
- WHEN the user toggles favorite on
- THEN the track is marked favorite in library state
- AND the favorite mark remains after relaunch

#### Scenario: Remove favorite

- GIVEN a track is already favorite
- WHEN the user toggles favorite off
- THEN the track is removed from favorites views and counts

### Requirement: Favorites Access Points

The system SHOULD provide favorite actions and favorite-state visibility from song list, now playing, and mini-player when each surface supports track actions.

#### Scenario: Surface parity for favorite access

- GIVEN a track action surface is rendered
- WHEN the surface supports contextual actions
- THEN favorite state and toggle action are available

### Requirement: Local Playlist Management

The system MUST allow local playlist create, rename, delete, add/remove tracks, and reorder tracks.

#### Scenario: Full local playlist lifecycle

- GIVEN the user opens playlists
- WHEN the user performs create, rename, add/remove, reorder, and delete operations
- THEN each operation updates local playlist state persistently

#### Scenario: Reorder boundaries

- GIVEN a playlist has multiple tracks
- WHEN the user reorders a track to first or last position
- THEN resulting order is deterministic and preserved

### Requirement: Local Playback History

The system MUST record per-track playback history entries including timestamp, listened duration, and completion status.

#### Scenario: History entry on playback

- GIVEN a track playback session occurs
- WHEN playback state changes to pause, stop, or complete
- THEN a history entry is stored with timestamp, listened duration, and completion flag

### Requirement: Smart Library Sections

The system MUST provide smart sections for recently added, recently played, most played, favorites, and continue listening based on local data.

#### Scenario: Smart sections populate

- GIVEN local library and playback data exist
- WHEN the library intelligence view loads
- THEN all configured smart sections render with bounded item lists

#### Scenario: Empty smart section behavior

- GIVEN a smart section has no qualifying items
- WHEN the section is evaluated
- THEN the UI shows an explicit empty state or hides the section per product rules

### Requirement: Queue Interaction UX

The system MUST allow users to view current queue, reorder items, remove items, play next, and add to end.

#### Scenario: Queue management actions

- GIVEN the queue contains one or more tracks
- WHEN the user performs reorder, remove, play next, or add-to-end
- THEN queue order updates immediately and playback intent is preserved

### Requirement: Basic Library Statistics

The system MUST expose basic local stats: song, album, and artist counts; total library duration; and top listened songs.

#### Scenario: Stats visibility

- GIVEN local metadata and play history are available
- WHEN stats are requested
- THEN counts, duration aggregate, and top listened list are shown from local state

### Requirement: Premium Empty States

The system MUST present clear premium empty states for deferred cloud/sync/AI features and MUST NOT imply broken functionality.

#### Scenario: Deferred feature messaging

- GIVEN a deferred premium capability is opened
- WHEN no local implementation exists by design
- THEN the UI states “coming soon” intent and current limitation clearly

### Requirement: Performance Guardrails

The system MUST avoid heavy library operations by using bounded/lazy/paginated list behavior where needed and MUST NOT load unbounded large libraries unnecessarily.

#### Scenario: Large library access

- GIVEN a library size beyond configured lightweight threshold
- WHEN the user opens smart sections, playlists, queue, or stats
- THEN data access is bounded and incremental so interaction remains responsive
