# Offline downloads UI checklist

Use this checklist to verify the PR3 UI slice for offline downloads without changing navigation or playback architecture.

## Quick path

1. Open the Library screen and use the new Downloads entry point.
2. Download a remote Subsonic track, watch status feedback, then reopen the app and verify the state persists.
3. Switch offline, play the saved track, verify artwork/queue continuity, then delete the track and test deleted-server cleanup.

## Scope

| Area | Included now | Out of scope |
|---|---|---|
| Track actions | Remote library/search/Now Playing download actions | Bulk album/playlist downloads |
| Downloads entry | Library app bar entry to `/downloads` | Navigation redesign or new tab |
| Playback | Local-first offline playback continuity | Provider/player architecture rewrite |
| Cleanup | Retry, cancel, delete, deleted-server reconciliation | Export/transcoding controls |

## Manual QA checklist

- [ ] Open **Downloads** from the Library app bar and confirm the dedicated screen loads.
- [ ] Start a remote track download from the Remote library surface.
- [ ] Start a remote track download from Remote search results.
- [ ] Open **Now Playing → Track info** for a remote track and confirm offline download actions appear.
- [ ] Confirm local-only tracks do **not** show remote download actions.
- [ ] Watch queued/downloading/completed/failed states and confirm status feedback updates without obvious list flicker.
- [ ] Cancel an active download and confirm the UI returns to a non-downloading state.
- [ ] Retry a failed download and confirm progress resumes.
- [ ] Force close the app, reopen it, and confirm interrupted downloads recover or stay consistent.
- [ ] Enable airplane mode and play a completed remote download; playback should use the offline file.
- [ ] Remove or corrupt the offline file and confirm playback falls back to remote when available, or shows the offline-unavailable error when not.
- [ ] Delete a completed download and confirm the managed file plus manifest entry are removed.
- [ ] Delete the backing server and confirm only that server's downloads are reconciled away.
- [ ] Confirm previously cached artwork still appears for downloaded tracks when offline.
- [ ] Queue a downloaded remote track with other playable items and confirm the queue order remains stable offline.
- [ ] Verify local playback still works exactly as before.
- [ ] Verify Navidrome streaming still works for non-downloaded remote tracks.

## Notes for reviewers

- Review the Downloads entry point first, then remote row actions, then Now Playing actions.
- The slice intentionally stays track-level only.
- If artwork offline behavior is inconsistent on device, capture whether the track had cached artwork before going offline.
