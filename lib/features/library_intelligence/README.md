# Library Intelligence (Slice 1)

- **Schema**: `LibrarySnapshot.currentSchemaVersion` (currently `1`), persisted in `library_intelligence.json`.
- **Stable identity**: use `providerId::trackId` as track key.
- **Reducer baseline rules**:
  - `playStarted`: increments `playCount` and updates `lastPlayedAt`.
  - `progressUpdated`: updates `resumePositionMs` only when `positionMs >= 15000`.
  - `playbackCompleted`: marks `isCompleted=true` and clears resume position.
  - `favoriteToggled`: updates favorite flag explicitly (no implicit favorite from play).
