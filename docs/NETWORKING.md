# Networking

Built on Godot's high-level multiplayer API (`MultiplayerAPI`, RPCs,
`MultiplayerSpawner`/`MultiplayerSynchronizer`). One peer is the **server**
(a hosting player or a headless dedicated server); everyone else is a client.

## Transports

| Platform | Transport | Why |
|---|---|---|
| Windows / Linux / macOS / Android / iOS | **ENet** (UDP) | low latency, packet ordering control |
| Web (HTML5) | **WebSocket** (TCP) | browsers cannot open UDP sockets |

`Net.join_game()` picks the transport automatically (`OS.has_feature("web")`).
Consequences:

- A normal (ENet) server serves desktop + mobile clients.
- Web clients need a server started with `--websocket`.
- Browsers can never **host** — the Host UI is hidden on web builds.
- To serve *both* populations of one match you'd run the dedicated server
  twice or implement a dual-peer relay; simplest production setup is
  WebSocket-only servers (everyone can join those).

## Dedicated server

```sh
godot --headless --path . -- --server [--websocket] [--port 7777]
```

`net.gd:_check_dedicated_server()` parses the user args, hosts, and loads the
arena. No player node is spawned for the server peer (`is_dedicated`).

## Authority model

| State | Owner | Mechanism |
|---|---|---|
| Position, velocity, aim, equipped items | owning client | `MultiplayerSynchronizer` (see `player.tscn` replication config) |
| HP, death, respawn | **server** | `take_damage()` runs server-side only; results pushed by RPC (`_sync_hp`, `_die`, `_respawn`), which clients accept only from peer 1 |
| Kills, deaths, team scores, match end | **server** | `Game.report_kill()` → `_sync_kill` RPC |
| Player registry, teams, chat | **server** | clients *request* (`_register_player`, `_request_chat`), server relays |
| Shooting | owning client announces | `_shoot` RPC (`call_local`); each peer simulates a local projectile, only the server's copy applies damage |

This is "client-predicted movement, server-authoritative combat" — the
standard compromise for fast online action games: movement feels instant,
while HP/score can't be forged by a client *writing* state. Note that the
server currently *trusts* fire-rate/ammo from the shooter; validating those
server-side is the first anti-cheat upgrade (see TODOs below).

## Connection flow

```
client                              server
  │ join_game(addr)                   │
  │ ──── transport connect ────────►  │
  │ connected_to_server               │ peer_connected
  │ _register_player(name, lvl) ────► │ assigns team (auto-balance),
  │                                   │ stores in players{}
  │ ◄──── _sync_players(players) ──── │ (broadcast)
  │ ◄──── Game._sync_score ────────── │ (late-join score catch-up)
  │ Game.start_match() → arena        │ arena spawns player node
  │                                   │ MultiplayerSpawner replicates it
```

Disconnects: `peer_disconnected` removes the registry entry → arena despawns
the node everywhere. If the *server* vanishes, clients get
`server_disconnected` → back to the main menu.

## Ping

Clients RPC `_ping_request(timestamp)` to the server every 2 s; the server
echoes it back; the client computes round-trip time → HUD. Offline/host shows 0.

## Server list & master server

`Servers` (autoload) keeps a local JSON list — enough for LAN parties and
community servers by IP. To add a central **master server**:

1. Run any small HTTP service with two endpoints:
   `POST /announce` (called periodically by game servers: name, port, players)
   and `GET /servers` (returns the live list as JSON).
2. In the game, fetch `GET /servers` with `HTTPRequest` from
   `server_browser.gd` and display the result alongside saved entries.
3. Optionally have `net.gd` announce itself after `host_game()`.

The UI and `Servers.add_server()` are already shaped for this — only the HTTP
fetch is missing.

## Scaling & hardening TODOs

Deliberately out of scope for the core, in rough priority order:

- **Server-side fire validation** — track per-player cooldown/ammo on the
  server inside `_shoot`'s server copy; ignore shots that violate weapon stats.
- **Accounts** — profile lives client-side now; for real online play, move
  XP/currency mutations behind an authenticated backend service.
- **Client-side interpolation** — add a buffer on synchronized transforms for
  smoother remote players at high ping.
- **Lag compensation / hit rewind** for high-latency fairness.
- **Encryption**: use DTLS (`ENetConnection.dtls_*`) / `wss://` in production.
