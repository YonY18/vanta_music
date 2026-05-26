# Tasks: v0.3 Premium Metadata Core

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 700-1000 |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | PR 1 → PR 2 → PR 3 → final cleanup |
| Delivery strategy | auto-chain |
| Chain strategy | stacked-to-main |

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: stacked-to-main
400-line budget risk: High

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | Domain contracts + JSON stores + resolver policy | PR 1 | Base: main; includes unit tests (RED/GREEN). |
| 2 | Library wiring + placeholders + identity-safe display | PR 2 | Base: main after PR 1 merge; includes widget/regression tests. |
| 3 | Player wiring + palette-ready placeholder usage | PR 3 | Base: main after PR 2 merge; keep optional editor and final cleanup out. |
| 4 | Final verification + deferred editor boundary note | Final cleanup | Base: verified WU1-WU3; documentation/task/report alignment only. |

## Phase 1: Foundation (Domain + Persistence)

- [x] 1.1 RED: Add failing tests in `test/features/premium_metadata/domain/metadata_models_test.dart` for `ResolvedTrackMetadata`, override merge/revert, and canonical identity retention.
- [x] 1.2 GREEN: Create `lib/features/premium_metadata/domain/metadata_models.dart` with `MetadataOverride`, `ArtworkResolution`, `ArtworkPalette`, `ArtistEnrichment` and serializer helpers.
- [x] 1.3 RED: Add failing store tests in `test/features/premium_metadata/infrastructure/file_metadata_override_store_test.dart` and `file_palette_cache_store_test.dart` for save/load/clear + bounded eviction.
- [x] 1.4 GREEN: Implement `lib/features/premium_metadata/infrastructure/file_metadata_override_store.dart` and `file_palette_cache_store.dart` using app-support JSON (no Drift migration).

## Phase 2: Core Resolution + Provider Wiring

- [x] 2.1 RED: Add failing resolver tests in `test/shared/artwork_cache/artwork_cache_resolver_test.dart` for miss memoization and cached hit/miss reuse.
- [x] 2.2 GREEN: Update `lib/shared/artwork_cache/artwork_cache_resolver.dart` and `file_artwork_cache_store.dart` to return typed outcomes and bounded fallback metadata.
- [x] 2.3 RED: Add failing provider tests in `test/features/premium_metadata/application/premium_metadata_providers_test.dart` for async placeholder-first resolution and empty artist contract.
- [x] 2.4 GREEN: Create `lib/features/premium_metadata/application/premium_metadata_providers.dart` and wire into `lib/features/library/application/library_providers.dart` without changing `tracksProvider` identity.

## Phase 3: Library/Player Integration + Regression

- [x] 3.1 RED: Extend `test/features/library/presentation/library_screen_test.dart` and `library_intelligence_sections_test.dart` for placeholder-first render, deterministic sections, and stable stats semantics.
- [x] 3.2 GREEN: Update `lib/features/library/presentation/library_screen.dart` and `lib/shared/widgets/artwork_tile.dart` to consume resolved metadata/artwork/palette with current style tokens.
- [x] 3.3 RED: Add failing UI tests in `test/features/player/presentation/mini_player_test.dart` and `now_playing_screen_test.dart` for non-blocking title/artwork enrichment.
- [x] 3.4 GREEN: Update `lib/features/player/presentation/mini_player.dart` and `now_playing_screen.dart` for async enriched display while playback actions keep canonical track identity.

## Phase 4: Verification + Optional Follow-up Boundary

- [x] 4.1 Run `flutter test` for premium_metadata, library, player, and artwork cache suites; fix RED→GREEN regressions before merge.
- [x] 4.2 Update `openspec/changes/v0-3-premium-ecosystem/tasks.md` checkboxes during apply and add note: metadata editing UI remains deferred to a separate change/work unit.

> Deferred boundary: metadata editing UI remains deferred to a separate change/work unit. This final cleanup slice only validates the existing premium metadata foundation and keeps product/runtime behavior unchanged.
