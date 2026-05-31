<div align="center">

<!-- Logo / Banner Placeholder -->
<img src="docs/assets/banner-placeholder.svg" alt="Vanta Music Banner" width="100%" />

# Vanta Music

### A modern, minimal and performance-first music player.

Vanta Music is an Android-first Flutter music player focused on local/offline playback, background audio, rich library browsing, and Subsonic/Navidrome-compatible streaming.

<br />

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Android](https://img.shields.io/badge/Android-111111?style=for-the-badge&logo=android&logoColor=3DDC84)
![Status](https://img.shields.io/badge/status-internal_beta_prep-7C3AED?style=for-the-badge)
![License](https://img.shields.io/badge/license-TBD-222222?style=for-the-badge)

</div>

---

## Overview

**Vanta Music** is a dark, minimal music player built for daily Android listening. It combines local library playback with a self-hosted remote path through the Subsonic API, while keeping the architecture feature-based and easy to extend.

The current app is centered on:

- Local music from Android MediaStore and manually selected folders.
- Background playback with notification, lockscreen, and media controls.
- A library-first UI with tracks, albums, artists, search, playlists, favorites, recents, and listening stats.
- Cached artwork for smooth library and player surfaces.
- Early Subsonic/Navidrome-compatible browsing, search, and playback.

---

## Screenshots

> Screenshots will be added as the UI stabilizes.

<div align="center">

| Home | Player | Library |
|---|---|---|
| <img src="docs/assets/screenshot-home-placeholder.svg" width="250" /> | <img src="docs/assets/screenshot-player-placeholder.svg" width="250" /> | <img src="docs/assets/screenshot-library-placeholder.svg" width="250" /> |

</div>

---

## Current beta scope

Vanta Music is being prepared for an internal Android beta focused on daily local playback plus a first self-hosted streaming slice.

### Included now

- Local music playback from MediaStore and selected folders.
- MP3, FLAC, OGG, and M4A local library support.
- Background playback through `audio_service` and `just_audio`.
- Notification, lockscreen, and media button controls.
- Persistent playback queue/session restore.
- Tracks, albums, artists, search, favorites, recents, most played, continue listening, and library stats.
- Local playlists with persisted playlist data.
- Mini player, full now-playing screen, queue view, play next, add to queue, and remove from queue.
- Cached local and remote artwork, including embedded/folder artwork extraction for local files.
- Subsonic/Navidrome-compatible remote connection, browse preview, search, playback, and cached snapshot fallback.
- Dark, minimal, portrait-first Android UI.

### Not in this beta

- Jellyfin integration.
- YouTube Music integration.
- Cloud sync.
- Desktop/iOS support.
- Full metadata editing UI.
- Full remote catalog sync/offline cache.

---

## Features

### Implemented

- 🎵 Local/offline music playback
- 🎧 Background audio playback
- 📱 Android-first, portrait-first experience
- 🔎 Local library search
- 💿 Track, album, and artist browsing
- 🧾 Local playlists
- ⭐ Favorites and listening history
- 📊 Recents, most played, continue listening, and stats
- 🧺 Queue management
- 🖼️ Cached artwork for library and player surfaces
- 🎼 MP3, FLAC, OGG, and M4A support
- ☁️ Subsonic/Navidrome-compatible remote playback slice
- 🌑 Dark, minimal and premium interface
- 🧱 Feature-based architecture

### Planned or partial

- 🪼 Jellyfin integration
- ▶️ YouTube Music integration
- 🧾 Metadata editing UI
- 🔄 Cloud/library sync
- 📦 Offline cache strategy for remote libraries
- 🧠 AI-assisted library tools
- 🖥️ Linux and Windows desktop support
- 🍎 iOS support

---

## Tech Stack

| Area | Technology |
|---|---|
| Framework | Flutter |
| Language | Dart |
| Routing | go_router |
| State management | Riverpod |
| Audio playback | just_audio |
| Background audio | audio_service |
| Android library access | on_audio_query |
| Folder selection | file_picker |
| Permissions | permission_handler |
| Remote API | http, Subsonic-compatible API client |
| Secure credentials | flutter_secure_storage |
| Local persistence | JSON/file stores under app support storage |
| Artwork and metadata | palette_generator, local/remote artwork cache, metadata override plumbing |
| Primary platform | Android |

---

## Project Philosophy

Vanta Music is built around a few core principles:

### Performance first

The app should feel fast, lightweight and reliable even with large local music libraries.

### Minimal but expressive

The interface should stay clean, dark and focused, without sacrificing personality or visual quality.

### Offline by default

Local music playback is the foundation. Network features should enhance the experience, not replace it.

### Clean architecture

The codebase should be easy to maintain, test and extend as the project grows.

### Future-ready

The architecture should support future integrations with self-hosted music servers and desktop platforms.

---

## Getting Started

### Requirements

Before running the project, make sure you have:

- Flutter SDK installed
- Dart SDK installed
- Android Studio or Android SDK configured
- A connected Android device or emulator

Check your environment:

```bash
flutter doctor
```

---

## Installation

Clone the repository:

```bash
git clone https://github.com/your-username/vanta_music.git
cd vanta_music
```

Install dependencies:

```bash
flutter pub get
```

---

## Running the Project

Run on Android:

```bash
flutter run
```

Run tests:

```bash
flutter test
```

Build a local release APK:

```bash
flutter build apk --release
```

---

## Android beta

Beta APKs are available from the repository **Releases** page.

Open the latest Vanta Music beta prerelease, then download the APK from **Assets**.

Before sharing a build, run through [`docs/internal-beta-checklist.md`](docs/internal-beta-checklist.md).

Quick gate:

- [ ] `flutter test`
- [ ] `flutter build apk --release`
- [ ] Long background playback test
- [ ] Notification/lockscreen controls test
- [ ] Large-library scroll test
- [ ] Subsonic/Navidrome smoke test, when remote playback is part of the build
- [ ] No secrets or local files tracked by Git

---

## Project Structure

```text
lib/
├── app/                       # App shell, router, theme
├── features/
│   ├── library/               # Local library, permissions, folders, search, screens
│   ├── library_intelligence/  # Favorites, recents, play stats, listening history
│   ├── player/                # audio_service, just_audio, player UI, queue/session
│   ├── playlists/             # Local playlists and persistence
│   ├── premium_metadata/      # Metadata override and palette cache plumbing
│   ├── providers/             # Local, Subsonic, and placeholder provider integrations
│   └── search/                # Search feature placeholder
├── shared/                    # Artwork cache, widgets, utilities
└── main.dart                  # App entry point
```

---

## Remote music support

Vanta Music already includes an early Subsonic-compatible provider path. It is intended to support servers such as Navidrome through the Subsonic API.

| Service | Status |
|---|---|
| Local device library | Implemented |
| Selected local folders | Implemented |
| Subsonic-compatible servers | Early implementation |
| Navidrome | Early implementation through Subsonic API |
| Jellyfin | Placeholder |
| YouTube Music | Placeholder |
| Cloud sync | Planned |
| Remote offline cache | Planned |

The remote tab currently favors connection, preview browsing, search, playback, retry/error handling, and cached snapshot fallback. Full remote catalog sync is still planned.

Manual remote testing notes live in [`docs/manual/navidrome-subsonic-test.md`](docs/manual/navidrome-subsonic-test.md).

---

## Roadmap

### Done or active

- [x] Feature-based project architecture
- [x] Local Android library access
- [x] Selected folder scanning
- [x] Audio playback foundation
- [x] Background audio service
- [x] Dark UI system
- [x] Library tabs for tracks, albums, and artists
- [x] Full player screen
- [x] Mini player
- [x] Queue management
- [x] Search
- [x] Local playlists
- [x] Favorites, recents, most played, continue listening, and stats
- [x] Artwork cache
- [x] Subsonic/Navidrome-compatible remote playback slice

### Next

- [ ] Stabilize internal Android beta builds
- [ ] Improve playlist management UI
- [ ] Expand metadata editing into user-facing flows
- [ ] Harden remote library browsing and sync behavior
- [ ] Add remote offline cache strategy
- [ ] Add Jellyfin provider implementation
- [ ] Evaluate desktop and iOS support after Android beta stability

---

## Current Status

Vanta Music is in **internal beta preparation**. The current goal is daily-use stability for local playback, while the Subsonic/Navidrome-compatible remote path continues to mature.

---

## Design Inspiration

Vanta Music takes inspiration from:

- Nothing OS visual language
- Minimal premium audio apps
- Dark-first interfaces
- High-contrast typography
- Smooth, focused mobile experiences

The goal is not to copy an existing product, but to build a music player with its own identity: quiet, dark, elegant and fast.

---

## Contributing

Contributions are welcome once the project foundation becomes stable.

For now, the best way to contribute is by:

- Opening issues with ideas or bugs
- Suggesting UX improvements
- Reviewing architecture decisions
- Testing on different Android devices

Before contributing code, please open an issue to discuss the change.

---

## License

License is not defined yet.

```text
TBD
```

---

<div align="center">

**Vanta Music**  
Dark. Minimal. Fast.

</div>
