Write an advanced, robust, and production-ready continuous daemon script for Linux named **audio-manager** that implements Smart Audio Ducking using **`playerctl`** (leveraging MPRIS protocol for instant state detection and zero keep-alive delay). You are completely unrestricted in using any Python libraries (e.g., `pulsectl`, `dbus-python`, `gobject`, third-party packages, `asyncio`, etc.) as long as it works reliably, efficiently, and cleanly on Linux.

### 1. Architecture, Naming & Systemd Optimization

- **Tool Name:** `audio-manager`.
- **Execution Model:** Designed for continuous daemon execution, optimized to be managed by a systemd service.
- **Log Format:** Output clean log messages directly to `stdout`/`stderr` **without manual timestamps**, since systemd journal automatically prepends timestamps.

### 2. Configuration Class & CLI Arguments

- **Configuration:** Place all default configurations inside a dedicated `Config` class at the beginning of the file (e.g., primary app name `spotify`, check interval, fade steps, debounce/delay timeouts, pause lock file path).
- **CLI Options:** Support CLI arguments to override settings dynamically, including `--blacklist-json <path>` to load the blacklist from an external JSON file and a `--debug` flag for verbose troubleshooting logs.

### 3. Core Ducking & Spotify Artist-based Priority Logic

- **Primary Source (Source A):** Spotify (continuous background music).
- **Transient Source (Source B):**
  - If set to `*`, trigger ducking when _any_ other MPRIS-compatible application/player starts playing.
  - If set to a specific name (e.g., `vivaldi`), trigger ducking **only** when that specific player is active/playing.
- **Spotify Artist Status Rule (via `playerctl -F` / real-time monitoring):**
  - Continuously monitor Spotify's artist metadata: `playerctl --player=spotify metadata --format '{{artist}}' -F`.
  - **Rule 1 (Empty Artist):** If the artist string returns empty (`""`), **immediately lower Spotify's volume to 0%**, regardless of whether Source B is playing or not.
  - **Rule 2 (Non-Empty Artist):** If the artist string is _not_ empty (`!= ""`), check the status of Source B:
    - If Source B is active/playing -> set Spotify's volume to **50%**.
    - If Source B is NOT active/stopped -> restore Spotify's volume to **100%**.
- **Enforcing Volume per Loop Cycle (Fixing Track Change Reset):**
  - In every main loop check cycle, actively enforce and re-apply Spotify's target volume (50% when B is active, or 100% when B is stopped). This ensures that when Spotify switches to a new track and automatically resets its volume to 100%, the daemon immediately overrides and pulls it back down to 50% if Source B is currently running.

### 4. Concurrency & Event Streams

- Use **`asyncio`** with asynchronous subprocesses (`asyncio.create_subprocess_exec`) to handle real-time `playerctl -F` event streams and periodic checks concurrently without blocking.

### 5. Safety & Advanced Features

- **Blacklist Filtering:** Combine the inline blacklist and the `--blacklist-json` file to ignore specific players even when `*` is active. Use case-insensitive matching.
- **Smooth Fade Transitions & Hysteresis:** Implement smooth volume transitions (fade-in / fade-out) and a short grace period delay before restoring volume to prevent rapid volume flapping.
- **Manual Override:** Check for a user lock file (e.g., `~/.cache/audio_manager_paused`). If present, temporarily bypass ducking.
- **Graceful Shutdown & Cleanup:** Implement signal handlers (`SIGINT`, `SIGTERM`) to ensure that if the daemon exits or stops, Spotify's volume is safely restored to 100%.

### 6. Coding Standards & Documentation

- Unrestricted Python libraries allowed (choose the best and most robust tools for audio/D-Bus control).
- Clean object-oriented or well-structured functional design.
- All code, comments, docstrings (`"""`), terminal messages, and documentation must be written strictly in **English**.
