# PR4 Checklist Notes

## Scope Boundary

- Keep PR4 limited to basic multi-server storage helpers and targeted server cleanup.
- No redesign, no offline sync/downloads, and no new providers.
- Do not touch `android/build/reports/problems/problems-report.html`.

## Focused Manual Checks

- Save two Subsonic servers, switch the active server, and confirm the selected server remains active.
- Edit one server and confirm its stable id and stored password are preserved.
- Delete one server and confirm only that server's credentials/cache are cleared while the other server remains intact.
