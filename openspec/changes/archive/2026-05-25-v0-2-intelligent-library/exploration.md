## Exploration: v0.2 Intelligent Library

### Current State
La app ya tiene una base sólida para v0.2 sin rediseño: Home con secciones inteligentes (`Continuar escuchando`, `Recientes`, `Más escuchadas`, `Favoritos`), favoritos persistidos, playlists locales simples, y sesión de reproducción persistida.

Persistencia actual:
- **Inteligencia + favoritos + recents + most played**: JSON (`library_intelligence.json`) con eventos de reproducción reducidos a snapshot.
- **Playlists**: JSON (`playlists.json`).
- **Sesión/cola actual**: JSON (`playback_session.json`).
- **Fuentes de carpeta**: JSON (`folder_library_sources.json`).

Performance ya presente:
- Defer de artwork en scroll (`_ArtworkDeferredOnScroll`).
- Precache de artwork con fingerprint y debounce (`artworkCacheWarmupBootstrapProvider`).
- Debounce de escritura para inteligencia (400ms) y sesión de playback (350ms).
- Limpieza/dedupe de tracks y caché de validación de archivos.

Gap importante: aunque `drift`/`sqlite3_flutter_libs` están en dependencias, hoy no se usan en runtime; todo está en archivos JSON.

### Affected Areas
- `lib/features/library/presentation/library_screen.dart` — Home, playlists tab, empty states, acciones de favorito/playlist, punto principal para secciones inteligentes y stats UI.
- `lib/features/library/presentation/library_intelligence_sections.dart` — definición y orden de secciones inteligentes visibles.
- `lib/features/library_intelligence/application/library_intelligence_providers.dart` — mapeo snapshot→tracks y stats; ya calcula métricas consumibles.
- `lib/features/library_intelligence/application/library_intelligence_sink.dart` — ingestión de eventos con debounce/persistencia.
- `lib/features/library_intelligence/domain/library_snapshot.dart` — modelo de snapshot + stats actuales.
- `lib/features/player/infrastructure/vanta_audio_handler.dart` — generación de eventos de reproducción y persistencia de cola/sesión.
- `lib/features/playlists/application/playlists_controller.dart` — lógica de playlists (actualmente create + add track).
- `lib/features/playlists/infrastructure/local_playlist_store.dart` — persistencia local de playlists.
- `lib/features/player/presentation/now_playing_screen.dart` — estado vacío de reproducción y potencial entrada para mejoras de cola ligeras.
- `test/features/**` (library_intelligence, playlists, player) — cobertura base disponible para expandir en v0.2.

### Approaches
1. **JSON-first incremental v0.2** — extender capacidades sobre la arquitectura actual (Riverpod + stores por archivo), sin migrar almacenamiento todavía.
   - Pros: mínimo riesgo, menor diff, respeta “no romper”, permite slices chicas (<400 líneas).
   - Cons: consultas agregadas complejas quedan limitadas; deuda técnica si crecen métricas/inteligencia.
   - Effort: Medium

2. **Migración temprana a Drift/SQLite para inteligencia/playlists/history** — introducir repositorio SQL ahora y adaptar providers.
   - Pros: mejor base para consultas, stats y escalabilidad futura.
   - Cons: alto riesgo para v0.2, mayor superficie de regresión, más trabajo de migración/test y excede fácil el budget de review.
   - Effort: High

### Recommendation
Recomiendo **Approach 1 (JSON-first incremental)** para v0.2: mantiene estilo visual y arquitectura limpia, minimiza cambios invasivos y prioriza performance con mejoras quirúrgicas.

Scope mínimo coherente v0.2 (sin features pesadas):
1) **Favorites + Smart Sections polish**: consolidar orden/límites, mejor fallback cuando no hay actividad, y navegación consistente.
2) **Playlists MVP+**: mantener create/add y sumar solo lo esencial (abrir detalle de playlist + remover track) sin rediseño.
3) **Queue UX liviana**: vista simple de cola actual (lectura + saltar a ítem), sin reorder complejo inicialmente.
4) **Basic Stats + Premium empty states**: exponer métricas existentes (tracked/favorites/completed/plays) y placeholders “Premium próximamente” para funciones explícitamente fuera de alcance (sync/cloud/AI).
5) **Performance hardening**: límites de listas, evitar recomputaciones innecesarias, y pruebas de regresión en lógica de inteligencia/cola.

Slice boundaries recomendadas (progresivas):
- **Slice A (bajo riesgo)**: empty states premium + stats UI (solo lectura).
- **Slice B**: playlists detalle/remoción mínima.
- **Slice C**: queue view liviana + jump to item.
- **Slice D**: ajustes finos de performance/telemetría local (sin nuevas dependencias pesadas).

### Risks
- **Crecimiento de JSON stores** puede impactar I/O en bibliotecas muy grandes si se persiste snapshot completo con mucha frecuencia.
- **Invalidaciones globales de providers** (`ref.invalidate(...)`) pueden causar rebuilds amplios si no se acotan en nuevos cambios.
- **Aclaración de alcance premium**: placeholders deben ser informativos, no caminos muertos confusos.
- **Riesgo de scope creep** si se intenta meter migración a Drift + nuevas features de cola avanzadas en la misma iteración.

### Ready for Proposal
Yes — listo para proponer v0.2 con alcance mínimo incremental, dividido en slices chicas, priorizando performance y estabilidad sobre rediseños o integraciones pesadas.
