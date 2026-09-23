#!/usr/bin/env python3
"""
audio-manager
=============

A production-ready, continuously-running daemon that implements "Smart Audio
Ducking" for a primary background player (by default Spotify) whenever any
other MPRIS-compatible application starts playing audio.

Design summary
---------------
* Uses ``playerctl`` (the standard Linux MPRIS command-line client) for all
  player state detection and volume control. No polling of raw D-Bus is
  needed: real-time events are consumed through ``playerctl --follow``,
  giving instant reactions with zero artificial keep-alive delay.
* Built entirely on ``asyncio`` with asynchronous subprocesses, so multiple
  long-running ``playerctl --follow`` streams and a periodic self-healing
  loop all run concurrently without blocking one another.
* Volume changes are applied as smooth fades (never hard jumps) and a short
  grace period is used before *restoring* volume, to avoid rapid flapping
  when a transient player starts/stops repeatedly in quick succession.
  Ducking down, in contrast, is applied immediately.
* A user-controlled lock file allows temporarily disabling all ducking
  behaviour without stopping the daemon.
* On shutdown (SIGINT/SIGTERM) the primary player's volume is always
  restored to 100% before the process exits.

Core rule set (Spotify artist-based priority logic)
----------------------------------------------------
1. If the primary player's ``artist`` metadata is empty (no track loaded /
   nothing meaningful playing), its volume is immediately set to 0%,
   regardless of the transient source's state.
2. If the artist metadata is non-empty:
   * transient source playing  -> primary volume = 50% (ducked)
   * transient source stopped  -> primary volume = 100% (restored)
3. The target volume is re-applied every loop cycle even when the logical
   state hasn't changed, which corrects Spotify's habit of silently
   resetting its own MPRIS volume to 100% whenever a new track starts.

Logging
-------
Log lines are written to stdout/stderr with no manual timestamps -- when run
under systemd, the journal already timestamps every line.

Usage
-----
    ./audio-manager.py [--primary spotify] [--transient '*']
                        [--interval 2.0] [--fade-steps 10]
                        [--fade-duration 0.5] [--grace-period 1.5]
                        [--lock-file ~/.cache/audio_manager_paused]
                        [--blacklist name1,name2]
                        [--blacklist-json /path/to/blacklist.json]
                        [--debug]

Example systemd unit (install as ~/.config/systemd/user/audio-manager.service):

    [Unit]
    Description=Smart Audio Ducking daemon (audio-manager)
    After=graphical-session.target

    [Service]
    Type=simple
    ExecStart=/usr/local/bin/audio-manager.py
    Restart=on-failure
    RestartSec=2

    [Install]
    WantedBy=default.target

Then: systemctl --user daemon-reload && systemctl --user enable --now audio-manager
"""

from __future__ import annotations

import argparse
import asyncio
import json
import logging
import signal
import sys
from pathlib import Path
from typing import AsyncIterator, Dict, Optional, Set

LOG = logging.getLogger("audio-manager")


# --------------------------------------------------------------------------- #
# Configuration
# --------------------------------------------------------------------------- #
class Config:
    """
    Central configuration for audio-manager.

    Class attributes hold the built-in defaults; an instance is built from
    CLI arguments via :meth:`Config.from_args` and carries the effective,
    possibly-overridden settings used by the running daemon.
    """

    # --- Defaults -----------------------------------------------------------
    PRIMARY_PLAYER = "spotify"
    TRANSIENT_PLAYER = "*"          # '*' = any other MPRIS player
    CHECK_INTERVAL = 0.2            # seconds between self-healing poll cycles
    FADE_STEPS = 10
    FADE_DURATION = 0.5             # seconds, total fade time
    RESTORE_GRACE_PERIOD = 0.5      # seconds of silence before un-ducking
    VOLUME_FULL = 1.0
    VOLUME_DUCKED = 0.5
    VOLUME_MUTED = 0.0
    VOLUME_EPSILON = 0.01
    PAUSE_LOCK_FILE = Path.home() / ".cache" / "audio_manager_paused"
    DEFAULT_BLACKLIST = {"playerctld"}
    PLAYERCTL_BIN = "playerctl"

    def __init__(self) -> None:
        self.primary_player: str = self.PRIMARY_PLAYER
        self.transient_player: str = self.TRANSIENT_PLAYER
        self.check_interval: float = self.CHECK_INTERVAL
        self.fade_steps: int = self.FADE_STEPS
        self.fade_duration: float = self.FADE_DURATION
        self.restore_grace_period: float = self.RESTORE_GRACE_PERIOD
        self.volume_full: float = self.VOLUME_FULL
        self.volume_ducked: float = self.VOLUME_DUCKED
        self.volume_muted: float = self.VOLUME_MUTED
        self.volume_epsilon: float = self.VOLUME_EPSILON
        self.pause_lock_file: Path = self.PAUSE_LOCK_FILE
        self.blacklist: Set[str] = set(self.DEFAULT_BLACKLIST)
        self.debug: bool = False

    @classmethod
    def from_args(cls, args: argparse.Namespace) -> "Config":
        cfg = cls()
        cfg.primary_player = args.primary
        cfg.transient_player = args.transient
        cfg.check_interval = args.interval
        cfg.fade_steps = max(1, args.fade_steps)
        cfg.fade_duration = max(0.0, args.fade_duration)
        cfg.restore_grace_period = max(0.0, args.grace_period)
        cfg.pause_lock_file = Path(args.lock_file).expanduser()
        cfg.debug = args.debug

        if args.blacklist:
            cfg.blacklist |= {
                name.strip().lower() for name in args.blacklist.split(",") if name.strip()
            }

        if args.blacklist_json:
            cfg.blacklist |= cls._load_blacklist_json(args.blacklist_json)

        return cfg

    @staticmethod
    def _load_blacklist_json(path: str) -> Set[str]:
        """Load an additional blacklist from a JSON file.

        Accepts either a plain JSON array of names, or an object of the form
        ``{"blacklist": ["name1", "name2"]}``.
        """
        p = Path(path).expanduser()
        try:
            with p.open("r", encoding="utf-8") as fh:
                data = json.load(fh)
        except (OSError, json.JSONDecodeError) as exc:
            LOG.error("Failed to load blacklist JSON from %s: %s", p, exc)
            return set()

        if isinstance(data, dict):
            entries = data.get("blacklist", [])
        elif isinstance(data, list):
            entries = data
        else:
            LOG.error("Unsupported blacklist JSON structure in %s (expected list or object)", p)
            return set()

        return {str(x).strip().lower() for x in entries if str(x).strip()}


# --------------------------------------------------------------------------- #
# Low-level playerctl helpers
# --------------------------------------------------------------------------- #
async def run_playerctl(*args: str, timeout: float = 5.0) -> str:
    """Run a one-shot playerctl command and return its stripped stdout.

    Non-zero exit codes (e.g. "No players found") are tolerated and simply
    yield an empty string; genuine failures to spawn or a timeout raise
    RuntimeError.
    """
    try:
        proc = await asyncio.create_subprocess_exec(
            Config.PLAYERCTL_BIN,
            *args,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
    except FileNotFoundError as exc:
        raise RuntimeError(f"'{Config.PLAYERCTL_BIN}' binary not found in PATH") from exc

    try:
        stdout, stderr = await asyncio.wait_for(proc.communicate(), timeout=timeout)
    except asyncio.TimeoutError as exc:
        proc.kill()
        await proc.wait()
        raise RuntimeError(f"playerctl {' '.join(args)} timed out after {timeout}s") from exc

    if proc.returncode not in (0, None) and stderr:
        LOG.debug("playerctl %s -> exit %s, stderr: %s", args, proc.returncode, stderr.decode(errors="replace").strip())

    return stdout.decode(errors="replace").strip()


async def stream_playerctl(*args: str) -> AsyncIterator[str]:
    """Yield stripped lines from a long-running ``playerctl --follow`` process.

    If the underlying process exits for any reason (player closed,
    playerctld restarted, transient error, ...), it is automatically
    respawned after a short backoff so the stream is effectively permanent
    for the lifetime of the daemon.
    """
    while True:
        proc: Optional[asyncio.subprocess.Process] = None
        try:
            proc = await asyncio.create_subprocess_exec(
                Config.PLAYERCTL_BIN,
                *args,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )
            assert proc.stdout is not None
            async for raw_line in proc.stdout:
                yield raw_line.decode(errors="replace").rstrip("\n")
        except asyncio.CancelledError:
            if proc is not None and proc.returncode is None:
                proc.kill()
                await proc.wait()
            raise
        except FileNotFoundError:
            LOG.error("'%s' binary not found in PATH; retrying in 5s", Config.PLAYERCTL_BIN)
            await asyncio.sleep(5.0)
            continue
        except Exception as exc:  # noqa: BLE001 - keep the stream alive no matter what
            LOG.warning("playerctl stream %s crashed: %s", args, exc)
        else:
            LOG.debug("playerctl stream %s ended, respawning", args)

        if proc is not None and proc.returncode is None:
            proc.kill()
            await proc.wait()
        await asyncio.sleep(1.0)


# --------------------------------------------------------------------------- #
# Volume control with smooth fades
# --------------------------------------------------------------------------- #
class VolumeController:
    """Controls the MPRIS volume of a single player, with smooth fades."""

    def __init__(self, player: str, cfg: Config) -> None:
        self.player = player
        self.cfg = cfg
        self._current_target: Optional[float] = None
        self._fade_task: Optional[asyncio.Task] = None
        self._last_known_volume: float = cfg.volume_full

    def is_idle(self) -> bool:
        """True if no fade is currently in flight."""
        return self._fade_task is None or self._fade_task.done()

    async def get_volume(self) -> Optional[float]:
        try:
            out = await run_playerctl(f"--player={self.player}", "volume")
        except RuntimeError as exc:
            LOG.debug("Could not read volume for '%s': %s", self.player, exc)
            return None
        if not out:
            return None
        try:
            return float(out)
        except ValueError:
            LOG.debug("Unparseable volume output for '%s': %r", self.player, out)
            return None

    async def set_volume(self, value: float) -> None:
        value = max(0.0, min(1.0, value))
        try:
            await run_playerctl(f"--player={self.player}", "volume", f"{value:.3f}")
            self._last_known_volume = value
        except RuntimeError as exc:
            LOG.warning("Failed to set volume for '%s': %s", self.player, exc)

    async def fade_to(self, target: float) -> None:
        """Smoothly fade this player's volume to ``target``.

        Any fade already in progress is cancelled first, so rapid state
        changes always converge to the latest requested target instead of
        stacking competing fades.
        """
        target = max(0.0, min(1.0, target))

        if self._current_target is not None and abs(self._current_target - target) < self.cfg.volume_epsilon:
            return  # Already at, or already fading toward, this target.

        if self._fade_task is not None and not self._fade_task.done():
            self._fade_task.cancel()
            try:
                await self._fade_task
            except asyncio.CancelledError:
                pass

        self._current_target = target
        self._fade_task = asyncio.create_task(self._do_fade(target))

    async def _do_fade(self, target: float) -> None:
        start = await self.get_volume()
        if start is None:
            start = self._last_known_volume

        steps = max(1, self.cfg.fade_steps)
        delta = target - start

        if abs(delta) < self.cfg.volume_epsilon or self.cfg.fade_duration <= 0:
            await self.set_volume(target)
            return

        step_delay = self.cfg.fade_duration / steps
        try:
            for i in range(1, steps + 1):
                value = start + delta * (i / steps)
                await self.set_volume(value)
                await asyncio.sleep(step_delay)
            LOG.info("Volume for '%s' faded to %.0f%%", self.player, target * 100)
        except asyncio.CancelledError:
            LOG.debug("Fade for '%s' interrupted by a newer target", self.player)
            raise


# --------------------------------------------------------------------------- #
# Main ducking engine
# --------------------------------------------------------------------------- #
class DuckingEngine:
    """
    Orchestrates state monitoring and volume control.

    Two long-lived ``playerctl --follow`` streams feed real-time events:

    * the primary player's ``artist`` metadata (drives Rule 1 / Rule 2), and
    * every player's playback status (drives transient-source detection).

    A periodic loop wakes up either on a state-change event or every
    ``check_interval`` seconds, whichever comes first, re-syncs state from
    one-shot playerctl calls (self-healing against any missed stream
    events) and (re-)applies the target volume.
    """

    def __init__(self, cfg: Config) -> None:
        self.cfg = cfg
        self.volume_ctl = VolumeController(cfg.primary_player, cfg)

        self.artist: str = ""
        self.player_statuses: Dict[str, str] = {}

        self.transient_raw_active: bool = False
        self._false_since: Optional[float] = None
        self._steady_target: float = cfg.volume_full

        self.change_event = asyncio.Event()
        self.shutdown_event = asyncio.Event()

    # -- relevance / filtering -------------------------------------------- #
    def is_relevant_player(self, name: str) -> bool:
        """Whether a given player name counts as a candidate transient source."""
        lname = name.lower()
        if lname == self.cfg.primary_player.lower():
            return False
        if lname in self.cfg.blacklist:
            return False
        if self.cfg.transient_player != "*" and lname != self.cfg.transient_player.lower():
            return False
        return True

    def _recompute_transient_active(self) -> bool:
        return any(
            status.lower() == "playing" and self.is_relevant_player(name)
            for name, status in self.player_statuses.items()
        )

    def _is_paused_override(self) -> bool:
        return self.cfg.pause_lock_file.exists()

    def _update_hysteresis(self) -> bool:
        """Return the *effective* (debounced) transient-active state.

        Ducking engages instantly. Restoring is delayed by
        ``restore_grace_period`` seconds of continuous silence, to avoid
        flapping when a transient player starts/stops in quick bursts.
        """
        now = asyncio.get_event_loop().time()
        raw = self._recompute_transient_active()
        self.transient_raw_active = raw

        if raw:
            self._false_since = None
            return True

        if self._false_since is None:
            self._false_since = now
        return (now - self._false_since) < self.cfg.restore_grace_period

    # -- streams ------------------------------------------------------------ #
    async def _watch_artist(self) -> None:
        args = (f"--player={self.cfg.primary_player}", "--follow", "metadata", "--format", "{{artist}}")
        async for line in stream_playerctl(*args):
            new_artist = line.strip()
            if new_artist != self.artist:
                LOG.info("Primary player artist changed: %r -> %r", self.artist, new_artist)
                self.artist = new_artist
                self.change_event.set()

    async def _watch_players(self) -> None:
        args = ("--all-players", "--follow", "metadata", "--format", "{{playerName}}::{{status}}")
        async for line in stream_playerctl(*args):
            if "::" not in line:
                continue
            name, status = (part.strip() for part in line.split("::", 1))
            if not name:
                continue
            key = name.lower()
            if self.player_statuses.get(key) != status:
                self.player_statuses[key] = status
                if self.is_relevant_player(name):
                    LOG.debug("Player '%s' status -> %s", name, status)
                self.change_event.set()

    # -- self-healing resync -------------------------------------------- #
    async def _resync_players(self) -> None:
        try:
            out = await run_playerctl("--all-players", "metadata", "--format", "{{playerName}}::{{status}}")
        except RuntimeError as exc:
            LOG.debug("Player resync failed: %s", exc)
            return
        if not out:
            self.player_statuses.clear()
            return

        seen: Set[str] = set()
        for line in out.splitlines():
            if "::" not in line:
                continue
            name, status = (part.strip() for part in line.split("::", 1))
            if not name:
                continue
            seen.add(name.lower())
            self.player_statuses[name.lower()] = status

        for stale in set(self.player_statuses) - seen:
            del self.player_statuses[stale]

    async def _resync_artist(self) -> None:
        try:
            out = await run_playerctl(f"--player={self.cfg.primary_player}", "metadata", "--format", "{{artist}}")
        except RuntimeError as exc:
            LOG.debug("Artist resync failed: %s", exc)
            return
        if out != self.artist:
            self.artist = out

    # -- decision + application ------------------------------------------ #
    async def _apply_state(self) -> None:
        paused = self._is_paused_override()
        effective_transient = self._update_hysteresis()

        if paused:
            target = self.cfg.volume_full
        elif self.artist == "":
            target = self.cfg.volume_muted
        elif effective_transient:
            target = self.cfg.volume_ducked
        else:
            target = self.cfg.volume_full

        if abs(target - self._steady_target) > self.cfg.volume_epsilon:
            LOG.info(
                "State change -> target %.0f%% (artist=%r, transient_active=%s, paused=%s)",
                target * 100,
                self.artist,
                effective_transient,
                paused,
            )
            self._steady_target = target
            await self.volume_ctl.fade_to(target)
        else:
            # Steady state unchanged: guard against external volume resets
            # (e.g. Spotify snapping back to 100% on a new track) by
            # re-applying the target directly, but only when no fade is
            # already in flight.
            if self.volume_ctl.is_idle():
                actual = await self.volume_ctl.get_volume()
                if actual is not None and abs(actual - target) > self.cfg.volume_epsilon:
                    LOG.info(
                        "Detected volume drift for '%s' (actual=%.0f%%, expected=%.0f%%); re-applying",
                        self.cfg.primary_player,
                        actual * 100,
                        target * 100,
                    )
                    await self.volume_ctl.set_volume(target)

    async def _periodic_loop(self) -> None:
        while not self.shutdown_event.is_set():
            try:
                await asyncio.wait_for(self.change_event.wait(), timeout=self.cfg.check_interval)
            except asyncio.TimeoutError:
                pass
            self.change_event.clear()

            await self._resync_players()
            await self._resync_artist()
            await self._apply_state()

    # -- lifecycle -------------------------------------------------------- #
    async def _restore_on_exit(self) -> None:
        LOG.info("Restoring '%s' volume to 100%% before exit", self.cfg.primary_player)
        await self.volume_ctl.set_volume(self.cfg.volume_full)

    def _install_signal_handlers(self) -> None:
        loop = asyncio.get_running_loop()
        for sig in (signal.SIGINT, signal.SIGTERM):
            loop.add_signal_handler(sig, self._handle_signal, sig)

    def _handle_signal(self, sig: signal.Signals) -> None:
        LOG.info("Received signal %s, shutting down", sig.name)
        self.shutdown_event.set()

    async def run(self) -> None:
        LOG.info(
            "Starting audio-manager (primary=%s, transient=%s, interval=%.1fs, "
            "fade=%.1fs/%d steps, grace=%.1fs, blacklist=%s)",
            self.cfg.primary_player,
            self.cfg.transient_player,
            self.cfg.check_interval,
            self.cfg.fade_duration,
            self.cfg.fade_steps,
            self.cfg.restore_grace_period,
            sorted(self.cfg.blacklist) or "(none)",
        )
        self._install_signal_handlers()

        tasks = [
            asyncio.create_task(self._watch_artist(), name="watch-artist"),
            asyncio.create_task(self._watch_players(), name="watch-players"),
            asyncio.create_task(self._periodic_loop(), name="periodic-loop"),
        ]

        try:
            await self.shutdown_event.wait()
        finally:
            for t in tasks:
                t.cancel()
            await asyncio.gather(*tasks, return_exceptions=True)
            await self._restore_on_exit()

        LOG.info("audio-manager stopped cleanly")


# --------------------------------------------------------------------------- #
# CLI entry point
# --------------------------------------------------------------------------- #
def parse_args(argv: Optional[list] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="audio-manager",
        description="Smart Audio Ducking daemon using playerctl / MPRIS.",
    )
    parser.add_argument(
        "--primary", default=Config.PRIMARY_PLAYER,
        help=f"Primary (background) player name to duck (default: {Config.PRIMARY_PLAYER})",
    )
    parser.add_argument(
        "--transient", default=Config.TRANSIENT_PLAYER,
        help="Transient player name that triggers ducking, or '*' for any other player "
             f"(default: {Config.TRANSIENT_PLAYER})",
    )
    parser.add_argument(
        "--interval", type=float, default=Config.CHECK_INTERVAL,
        help=f"Periodic self-healing check interval in seconds (default: {Config.CHECK_INTERVAL})",
    )
    parser.add_argument(
        "--fade-steps", type=int, default=Config.FADE_STEPS,
        help=f"Number of steps in a volume fade (default: {Config.FADE_STEPS})",
    )
    parser.add_argument(
        "--fade-duration", type=float, default=Config.FADE_DURATION,
        help=f"Total duration of a volume fade in seconds (default: {Config.FADE_DURATION})",
    )
    parser.add_argument(
        "--grace-period", type=float, default=Config.RESTORE_GRACE_PERIOD,
        help="Seconds of continuous silence from the transient source before restoring "
             f"volume (default: {Config.RESTORE_GRACE_PERIOD})",
    )
    parser.add_argument(
        "--lock-file", default=str(Config.PAUSE_LOCK_FILE),
        help=f"Path to a lock file that, when present, disables ducking (default: {Config.PAUSE_LOCK_FILE})",
    )
    parser.add_argument(
        "--blacklist", default="",
        help="Comma-separated list of additional player names to always ignore",
    )
    parser.add_argument(
        "--blacklist-json", default=None,
        help="Path to a JSON file with a blacklist array, or {'blacklist': [...]} object",
    )
    parser.add_argument("--debug", action="store_true", help="Enable verbose debug logging")
    return parser.parse_args(argv)


def setup_logging(debug: bool) -> None:
    logging.basicConfig(
        stream=sys.stdout,
        level=logging.DEBUG if debug else logging.INFO,
        format="[%(levelname)s] %(name)s: %(message)s",
    )


def main() -> None:
    args = parse_args()
    setup_logging(args.debug)
    cfg = Config.from_args(args)
    engine = DuckingEngine(cfg)
    try:
        asyncio.run(engine.run())
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
