import argparse
import asyncio
import sys
import time
import traceback

from dbus_fast import BusType, Message, MessageType, Variant
from dbus_fast.aio import MessageBus
from dbus_fast.constants import NameFlag, RequestNameReply
from dbus_fast.service import (
    PropertyAccess,
    ServiceInterface,
    dbus_property,
    method,
    signal,
)

UPSTREAM_PREFIX = "org.mpris.MediaPlayer2.chromium."
OWN_NAME = "org.mpris.MediaPlayer2.soundcloud"
LOCK_NAME = "dev.local.SoundCloudMprisProxy"
MPRIS_PATH = "/org/mpris/MediaPlayer2"
PLAYER_IFACE = "org.mpris.MediaPlayer2.Player"
PROPS_IFACE = "org.freedesktop.DBus.Properties"
BUS_NAME = "org.freedesktop.DBus"
BUS_PATH = "/org/freedesktop/DBus"

DEFAULTS = {
    "PlaybackStatus": "Stopped",
    "Metadata": {},
    "Volume": 1.0,
    "Rate": 1.0,
    "MinimumRate": 1.0,
    "MaximumRate": 1.0,
    "CanGoNext": True,
    "CanGoPrevious": True,
    "CanPlay": True,
    "CanPause": True,
    "CanSeek": True,
    "CanControl": True,
}


def log(*args):
    print(*args, file=sys.stderr, flush=True)


class Root(ServiceInterface):
    def __init__(self):
        super().__init__("org.mpris.MediaPlayer2")

    @method()
    def Raise(self):
        pass

    @method()
    def Quit(self):
        pass

    @dbus_property(access=PropertyAccess.READ)
    def CanQuit(self) -> "b":
        return False

    @dbus_property(access=PropertyAccess.READ)
    def CanRaise(self) -> "b":
        return False

    @dbus_property(access=PropertyAccess.READ)
    def HasTrackList(self) -> "b":
        return False

    @dbus_property(access=PropertyAccess.READ)
    def Identity(self) -> "s":
        return "SoundCloud"

    @dbus_property(access=PropertyAccess.READ)
    def DesktopEntry(self) -> "s":
        return "soundcloud"

    @dbus_property(access=PropertyAccess.READ)
    def SupportedUriSchemes(self) -> "as":
        return []

    @dbus_property(access=PropertyAccess.READ)
    def SupportedMimeTypes(self) -> "as":
        return []


class Player(ServiceInterface):
    def __init__(self, proxy):
        super().__init__(PLAYER_IFACE)
        self.proxy = proxy

    def get(self, name):
        return self.proxy.state.get(name, DEFAULTS[name])

    @method()
    async def Next(self):
        await self.proxy.forward("Next")

    @method()
    async def Previous(self):
        await self.proxy.forward("Previous")

    @method()
    async def Pause(self):
        await self.proxy.forward("Pause")

    @method()
    async def PlayPause(self):
        await self.proxy.forward("PlayPause")

    @method()
    async def Stop(self):
        await self.proxy.forward("Stop")

    @method()
    async def Play(self):
        await self.proxy.forward("Play")

    @method()
    async def Seek(self, offset: "x"):
        await self.proxy.forward("Seek", "x", [offset])

    @method()
    async def SetPosition(self, track_id: "o", position: "x"):
        await self.proxy.forward("SetPosition", "ox", [track_id, position])

    @method()
    async def OpenUri(self, uri: "s"):
        await self.proxy.forward("OpenUri", "s", [uri])

    @signal()
    def Seeked(self, position: "x") -> "x":
        return position

    @dbus_property(access=PropertyAccess.READ)
    def PlaybackStatus(self) -> "s":
        return self.get("PlaybackStatus")

    @dbus_property(access=PropertyAccess.READ)
    def Metadata(self) -> "a{sv}":
        return self.get("Metadata")

    @dbus_property(access=PropertyAccess.READ)
    def Position(self) -> "x":
        return self.proxy.position()

    @dbus_property()
    def Volume(self) -> "d":
        return self.get("Volume")

    @Volume.setter
    def Volume(self, value: "d"):
        self.proxy.spawn(self.proxy.set_volume(value))

    @dbus_property(access=PropertyAccess.READ)
    def Rate(self) -> "d":
        return self.get("Rate")

    @dbus_property(access=PropertyAccess.READ)
    def MinimumRate(self) -> "d":
        return self.get("MinimumRate")

    @dbus_property(access=PropertyAccess.READ)
    def MaximumRate(self) -> "d":
        return self.get("MaximumRate")

    @dbus_property(access=PropertyAccess.READ)
    def CanGoNext(self) -> "b":
        return self.get("CanGoNext")

    @dbus_property(access=PropertyAccess.READ)
    def CanGoPrevious(self) -> "b":
        return self.get("CanGoPrevious")

    @dbus_property(access=PropertyAccess.READ)
    def CanPlay(self) -> "b":
        return self.get("CanPlay")

    @dbus_property(access=PropertyAccess.READ)
    def CanPause(self) -> "b":
        return self.get("CanPause")

    @dbus_property(access=PropertyAccess.READ)
    def CanSeek(self) -> "b":
        return self.get("CanSeek")

    @dbus_property(access=PropertyAccess.READ)
    def CanControl(self) -> "b":
        return self.get("CanControl")


class Proxy:
    def __init__(self, bus, profile):
        self.bus = bus
        self.flag = f"--user-data-dir={profile}".encode()
        self.root = Root()
        self.player = Player(self)
        self.exported = False
        self.named = False
        self.upstream = None
        self.owner = None
        self.state = {}
        self.pos_base = 0
        self.pos_ts = time.monotonic()
        self.tasks = set()

    def spawn(self, coro):
        task = asyncio.create_task(coro)
        self.tasks.add(task)
        task.add_done_callback(self.done)

    def done(self, task):
        self.tasks.discard(task)
        if not task.cancelled() and task.exception():
            traceback.print_exception(task.exception())

    async def call(self, dest, path, iface, member, signature="", body=None):
        reply = await self.bus.call(
            Message(
                destination=dest,
                path=path,
                interface=iface,
                member=member,
                signature=signature,
                body=body or [],
            )
        )
        if reply.message_type != MessageType.METHOD_RETURN:
            log("call failed:", dest, iface, member, reply.error_name, reply.body)
            return None
        return reply

    async def bus_call(self, member, signature="", body=None):
        return await self.call(BUS_NAME, BUS_PATH, BUS_NAME, member, signature, body)

    async def forward(self, member, signature="", body=None):
        if self.upstream:
            await self.call(
                self.upstream, MPRIS_PATH, PLAYER_IFACE, member, signature, body
            )

    async def set_volume(self, value):
        if self.upstream:
            await self.call(
                self.upstream,
                MPRIS_PATH,
                PROPS_IFACE,
                "Set",
                "ssv",
                [PLAYER_IFACE, "Volume", Variant("d", value)],
            )

    def position(self):
        pos = self.pos_base
        if self.state.get("PlaybackStatus") == "Playing":
            rate = self.state.get("Rate", 1.0)
            pos += int((time.monotonic() - self.pos_ts) * 1_000_000 * rate)
        return pos

    def rebase(self, position=None):
        self.pos_base = self.position() if position is None else position
        self.pos_ts = time.monotonic()

    def apply(self, changed):
        if "Position" in changed:
            self.rebase(changed["Position"])
        out = {}
        for name, value in changed.items():
            if name not in DEFAULTS or self.state.get(name) == value:
                continue
            if name == "PlaybackStatus" and "Position" not in changed:
                self.rebase()
            self.state[name] = value
            out[name] = value
        if out and self.exported:
            self.player.emit_properties_changed(out)

    async def belongs(self, name):
        reply = await self.bus_call("GetConnectionUnixProcessID", "s", [name])
        if reply is None:
            return False
        pid = reply.body[0]
        try:
            with open(f"/proc/{pid}/cmdline", "rb") as f:
                cmdline = f.read().replace(b"\0", b" ")
        except OSError as e:
            log("cannot read cmdline of", pid, e)
            return False
        return self.flag + b" " in cmdline + b" "

    async def attach(self, name, owner):
        reply = await self.call(
            name, MPRIS_PATH, PROPS_IFACE, "GetAll", "s", [PLAYER_IFACE]
        )
        if reply is None:
            return False
        props = reply.body[0]
        self.upstream, self.owner = name, owner
        self.state = {k: v.value for k, v in props.items() if k in DEFAULTS}
        position = props.get("Position")
        self.rebase(position.value if position else 0)
        if not self.exported:
            self.bus.export(MPRIS_PATH, self.root)
            self.bus.export(MPRIS_PATH, self.player)
            self.exported = True
            log("exported interfaces")
        if not self.named:
            result = await self.bus.request_name(OWN_NAME)
            log("request_name result:", result)
            self.named = True
        return True

    async def detach(self):
        log("detach")
        self.upstream = self.owner = None
        self.state = {}
        if self.named:
            await self.bus.release_name(OWN_NAME)
            self.named = False

    async def on_name(self, name, owner):
        log("candidate", name, owner)
        if not await self.belongs(name):
            log("not ours", name)
            return
        for _ in range(20):
            if await self.attach(name, owner):
                log("attached", name)
                return
            await asyncio.sleep(0.5)
        log("gave up", name)

    async def refresh(self):
        reply = await self.call(
            self.upstream, MPRIS_PATH, PROPS_IFACE, "GetAll", "s", [PLAYER_IFACE]
        )
        if reply:
            self.apply({k: v.value for k, v in reply.body[0].items()})

    def on_message(self, msg):
        try:
            self.handle(msg)
        except Exception:
            traceback.print_exc()

    def handle(self, msg):
        if msg.message_type != MessageType.SIGNAL:
            return
        if msg.member == "NameOwnerChanged" and msg.sender == BUS_NAME:
            name, _old, new = msg.body
            if not name.startswith(UPSTREAM_PREFIX):
                return
            log("name change", msg.body)
            if name == self.upstream and not new:
                self.spawn(self.detach())
            elif new:
                self.spawn(self.on_name(name, new))
        elif self.owner and msg.sender == self.owner:
            if msg.member == "PropertiesChanged" and msg.body[0] == PLAYER_IFACE:
                self.apply({k: v.value for k, v in msg.body[1].items()})
                if msg.body[2]:
                    self.spawn(self.refresh())
            elif msg.member == "Seeked" and msg.interface == PLAYER_IFACE:
                self.rebase(msg.body[0])
                if self.exported:
                    self.player.Seeked(msg.body[0])

    async def poll(self):
        while True:
            await asyncio.sleep(5)
            if self.upstream and self.state.get("PlaybackStatus") == "Playing":
                reply = await self.call(
                    self.upstream,
                    MPRIS_PATH,
                    PROPS_IFACE,
                    "Get",
                    "ss",
                    [PLAYER_IFACE, "Position"],
                )
                if reply:
                    self.rebase(reply.body[0].value)

    async def start(self):
        self.bus.add_message_handler(self.on_message)
        rules = (
            "type='signal',sender='org.freedesktop.DBus',"
            "interface='org.freedesktop.DBus',member='NameOwnerChanged',"
            "arg0namespace='org.mpris.MediaPlayer2'",
            "type='signal',path='/org/mpris/MediaPlayer2'",
        )
        for rule in rules:
            await self.bus_call("AddMatch", "s", [rule])
        reply = await self.bus_call("ListNames")
        names = [n for n in (reply.body[0] if reply else []) if n.startswith(UPSTREAM_PREFIX)]
        log("existing upstream names:", names)
        for name in names:
            owner = await self.bus_call("GetNameOwner", "s", [name])
            if owner:
                self.spawn(self.on_name(name, owner.body[0]))


async def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--profile", required=True)
    args = parser.parse_args()

    bus = await MessageBus(bus_type=BusType.SESSION).connect()
    reply = await bus.request_name(LOCK_NAME, NameFlag.DO_NOT_QUEUE)
    if reply != RequestNameReply.PRIMARY_OWNER:
        log("lock held by another proxy, exiting")
        return

    proxy = Proxy(bus, args.profile)
    await proxy.start()
    proxy.spawn(proxy.poll())
    log("proxy started")
    await bus.wait_for_disconnect()


asyncio.run(main())
