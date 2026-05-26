# Navidrome/Subsonic Manual Smoke Test

Use this checklist to verify the first Subsonic-compatible remote provider slice against a real Navidrome server. The goal is to prove configure, browse, search, stream, and artwork behavior without expanding into offline sync or metadata editing.

## Quick path

1. Start from a clean app install or clear saved provider data.
2. Add a Navidrome server using its base URL, username, and password.
3. Run the checks below in order and record pass/fail notes in the PR.

## Test environment

| Item | Value |
|------|-------|
| Server | Navidrome or Subsonic-compatible server |
| API format | JSON (`f=json`) |
| Client id | `vanta` |
| TLS | Validation must stay enabled; do not bypass invalid certificates |
| Local library | Keep at least one local track available for regression checks |

## Checklist

### 1. Server configuration

- [ ] Save a server with a valid URL, username, and password.
- [ ] Test connection reports success for valid credentials.
- [ ] Invalid credentials show a clear failure state without printing the password or auth token.
- [ ] Inspect local config/debug output if available: only non-sensitive metadata is visible outside secure storage.

### 2. Remote browsing and search

- [ ] Open the dedicated remote surface.
- [ ] Remote tracks load separately from local smart sections.
- [ ] Local-only views do not mix in remote items by default.
- [ ] Remote search returns matching server tracks.
- [ ] Empty and server-error states are understandable and actionable.

### 3. Remote playback

- [ ] Start playback from a remote track.
- [ ] Queue another remote track and skip to it.
- [ ] Play a local track afterward; local playback still uses its local URI.
- [ ] Restart the app if session persistence is available; no stored queue/session data contains `u=`, `s=`, `t=`, `password=`, or `token=` values.

### 4. Remote artwork and cache guardrails

- [ ] Remote list rows paint immediately with placeholder/fallback artwork before the network cover finishes.
- [ ] Remote cover art resolves asynchronously when the server returns cover bytes.
- [ ] Scrolling the same items back into view reuses cached artwork instead of visibly refetching every time.
- [ ] Cache file names and diagnostics do not contain usernames, passwords, salts, tokens, or full auth-bearing URLs.

## Automated verification for this slice

Run before handing the PR to review:

```bash
flutter test
flutter analyze --no-fatal-infos --no-fatal-warnings
```

## Out of scope

- Offline downloads or full sync.
- Metadata editing on the server.
- Non-Subsonic providers.
- UI redesign outside the minimal remote provider surfaces.
