# Design: v0.3 Premium Metadata Core

## Technical Approach

Add a local-first premium metadata layer beside the existing library and artwork cache paths. `Track` remains the canonical playback identity; enriched display values and artwork/palette outcomes are resolved through repository interfaces and Riverpod providers. UI surfaces keep current Vanta cards, gradients, radii, and typography, rendering placeholders first and applying async enrichment later.

Implementation should ship in reviewable slices: domain contracts, JSON stores/cache policy, provider wiring, then small UI consumption points.

## Architecture Decisions

| Option | Tradeoff | Decision |
|--------|----------|----------|
| Extend `Track` with override fields | Simple but risks identity drift in playback/history | Keep `Track` canonical; add `ResolvedTrackMetadata` display model keyed by stable track key. |
| Reuse Drift now | Strong schema but larger migration/review scope | Use JSON stores under app support directory, matching `FileLibraryIntelligenceStore`. |
| Add external metadata API now | Faster enrichment demo but creates lock-in/network risk | Define provider interfaces only; no network implementation in this slice. |
| Resolve artwork directly in widgets | Easy but repeats work and complicates tests | Resolve through repositories/providers with in-memory miss memoization and file cache reuse. |

## Data Flow

    Track list ──→ PremiumMetadataRepository ──→ ResolvedTrackMetadata
        │                    │                         │
        │                    ├── MetadataOverrideStore  │
        │                    ├── ArtworkCacheResolver   │
        │                    └── PaletteCacheStore      │
        └── playback uses canonical Track identity ◀────┘

First paint uses source `Track` + styled placeholder. Async providers load overrides, fallback artwork, and palette cache; UI rebuilds only affected tiles/surfaces.

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `lib/features/premium_metadata/domain/metadata_models.dart` | Create | `ResolvedTrackMetadata`, `MetadataOverride`, `ArtworkResolution`, `ArtworkPalette`, artist enrichment contracts. |
| `lib/features/premium_metadata/application/premium_metadata_providers.dart` | Create | Riverpod providers/families for resolved metadata, artwork, palette, and artist empty contracts. |
| `lib/features/premium_metadata/infrastructure/file_metadata_override_store.dart` | Create | JSON persistence for reversible local overrides. |
| `lib/features/premium_metadata/infrastructure/file_palette_cache_store.dart` | Create | Bounded JSON palette cache keyed by artwork cache key/path. |
| `lib/shared/artwork_cache/artwork_cache_resolver.dart` | Modify | Return typed artwork result and memoize misses during provider lifetime to avoid repeated lookups. |
| `lib/shared/artwork_cache/file_artwork_cache_store.dart` | Modify | Expose bounded policy hooks/metadata needed by premium artwork results. |
| `lib/features/library/application/library_providers.dart` | Modify | Add display metadata provider wiring without changing `tracksProvider` identity. |
| `lib/features/library/presentation/library_screen.dart` | Modify | `_TrackTile`, album/artist rows, and smart sections consume resolved display fields/artwork placeholders. |
| `lib/features/player/presentation/now_playing_screen.dart` | Modify | Now playing artwork/title sheet consumes resolved metadata and cached palette when available. |
| `lib/features/player/presentation/mini_player.dart` | Modify | Mini-player uses same resolver without visual redesign. |
| `lib/shared/widgets/artwork_tile.dart` | Modify | Accept premium placeholder/palette inputs while preserving current Vanta style. |
| `test/features/premium_metadata/` | Create | Unit tests for overrides, repository merge, cache misses, palette non-blocking behavior. |
| Existing library/player/artwork tests | Modify | Cover enriched display without identity/stat changes. |

## Interfaces / Contracts

```dart
abstract class PremiumMetadataRepository {
  Future<ResolvedTrackMetadata> resolveTrack(Track track);
  Future<void> saveOverride(String trackKey, MetadataOverride override);
  Future<void> clearOverride(String trackKey);
}

abstract class ArtistEnrichmentRepository {
  Future<ArtistEnrichment> getArtist(String artistKey); // local/empty only now
}
```

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Unit | Override merge/revert, artist empty contracts, palette cache, artwork miss memoization | `flutter_test` with fake stores/sources. |
| Widget | Library, mini-player, now-playing placeholders and resolved updates | Existing widget tests with provider overrides. |
| Regression | Smart sections/stats use canonical identity | Extend `library_intelligence_sections_test.dart` and provider mapping tests. |

## Migration / Rollout

No destructive migration required. New JSON files are additive: `metadata_overrides.json` and `palette_cache.json`. Roll out by slices under the 400-line review budget: contracts, stores, artwork policy, library UI, player UI/tests. Rollback is deleting those files or reverting commits; source media and existing intelligence JSON remain valid.

## Open Questions

- [ ] Should metadata editing UI ship in this change, or only repository/store support for a later UX slice?
