# Offline downloads validation

Offline downloads keep the canonical Subsonic track identity and only swap the playback source to a managed local file when a validated download exists.

## Quick path

1. Enqueue a Subsonic track download and let it complete.
2. Play the same canonical track and confirm playback resolves from the local file when available.
3. Delete the server or the downloaded item and confirm the manifest entry plus managed file are removed without touching unrelated metadata.

## Lifecycle

| Step | Expected result |
|------|-----------------|
| Enqueue | One manifest row per `providerId::trackId`; duplicate requests reuse it. |
| Complete | The `.part` file is promoted atomically and storage totals include the finished item. |
| Playback | Resolver prefers the validated local file, then falls back to remote streaming if the copy is missing or invalid. |
| Cleanup | User delete or server removal clears linked manifest rows and managed files only. |

## Rollback

- Remove offline download entry points.
- Disable the offline resolver overlay.
- Sweep managed files under app-support `downloads/` if the feature is rolled back completely.

## Validation checklist

- [ ] Duplicate download requests do not create a second active manifest row.
- [ ] Download status and progress providers update by `downloadKey` without broad list churn.
- [ ] Completed download bytes appear in the storage summary.
- [ ] Missing or invalid local files fall back to remote playback safely.
- [ ] Server deletion removes only linked download rows/files and keeps unrelated metadata intact.
