# Delta for Intelligent Library

## ADDED Requirements

### Requirement: Provider Identity for Library Items

The system MUST carry provider/source identity for remote tracks in browsing, search, queue, favorites, and history records where those features are supported.

#### Scenario: Source identity preserved in actions

- GIVEN a remote track is visible in remote library/search
- WHEN the user adds it to queue or favorites
- THEN the resulting item stores provider identity with track identity

#### Scenario: Local behavior remains compatible

- GIVEN existing local tracks and actions
- WHEN provider identity support is introduced
- THEN local favorites/history/queue behavior remains unchanged

### Requirement: Source-Separated Discovery Surfaces

The system MUST keep remote browsing/search separated from local smart sections in this phase and MUST NOT mix local and remote items in a single section by default.

#### Scenario: Separate library surfaces

- GIVEN local and remote sources are both available
- WHEN the user opens intelligent library views
- THEN local smart sections show local items only and remote items appear in dedicated remote surfaces

#### Scenario: No confusing mixed results

- GIVEN a user runs search in a local-only surface
- WHEN results render
- THEN remote items are excluded unless the user is in a remote-scoped surface
