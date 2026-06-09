# Architecture

## Big picture

```
                ┌────────────────────────────────────────────┐
                │                 Autoloads                  │
                │  (always alive, survive scene changes)     │
                │                                            │
                │  Game     scene flow + match state (RPCs)  │
                │  Net      connections + player registry    │
                │  Profile  local progression / wallet / save│
                │  ItemDB   static item & weapon data        │
                │  Servers  saved server list                │
                └────────────────────────────────────────────┘
                       ▲                    ▲
        UI scenes ─────┘                    └───── game scenes
   main_menu / store / server_browser    arena (spawns player.tscn per peer,
   profile_screen / settings             instances hud.tscn, projectiles)
```

The **autoloads are the engine core**: every scene is a thin view over them.
UI scenes call into autoloads and listen to their signals; gameplay scenes do
the same. This keeps scenes replaceable — you can restyle the whole UI without
touching game logic, or swap the arena without touching the UI.

## Autoloads (`autoload/`)

| Singleton | File | Responsibility |
|---|---|---|
| `Game` | `game.gd` | Scene switching, match lifecycle, team scores, kill events + rewards. Server-authoritative; state reaches clients via RPCs on this node. |
| `Net` | `net.gd` | Hosting/joining (ENet or WebSocket), the `players` registry (peer_id → name/team/kills/deaths), team auto-balance, chat relay, ping measurement, dedicated-server bootstrap. |
| `Profile` | `profile.gd` | The local player: name, XP/level, coins/gold, owned items, equipped loadout, settings. JSON-persisted to `user://`. |
| `ItemDB` | `item_db.gd` | Pure data: every weapon/grenade/perk and its stats/prices. No state. |
| `Servers` | `servers.gd` | The server browser's backend: a locally saved list of servers, pluggable for a master server. |

## Scene flow

```
main_menu ──► server_browser ──host/join──► arena ──leave/disconnect──► main_menu
    │  ▲                                      ▲
    │  └── store / profile_screen / settings  │
    └────────────── Practice Offline ─────────┘
```

All transitions go through `Game.goto_scene()` / `Game.start_match()` /
`Game.return_to_menu()`.

## The match (`scenes/game/arena.tscn`)

- The **server** owns player lifecycles: `arena.gd` watches
  `Net.player_list_changed` and keeps exactly one `player.tscn` node per
  registered peer (named after the peer id). A `MultiplayerSpawner`
  replicates spawn/despawn to clients automatically — this gives free
  **drop-in / drop-out**.
- `player.gd` splits authority (see [NETWORKING.md](NETWORKING.md)):
  movement + aim belong to the owning client, health + death + respawn belong
  to the server.
- Projectiles and grenades are **not** synchronized nodes: a shot is one RPC,
  and every peer simulates a local projectile. Only the server's copy deals
  damage. This is the cheapest scalable model for bullet-heavy games.
- The HUD (`hud.tscn`, a `CanvasLayer`) is instanced inside the arena and is
  purely reactive — it reads autoload signals and the local player node.

## The player contract

Anything that wants to behave like a player must provide what other systems
consume:

- group `players`, node name = peer id
- `peer_id`, `team`, `hp`, `max_hp` properties
- `take_damage(amount, attacker_id)` (server-side)
- `local_state_changed` signal (HUD refresh)

`arena.tscn` exposes the map contract: a `Players` container,
`SpawnPoints` with markers named `Blue*` / `Red*`, a `KillZone`, and the
`arena` group with `get_spawn_position(team)`. Any scene honoring this
contract is a valid map.

## Data-driven content

Items live in one dictionary (`item_db.gd`). The store, the profile/loadout
screen, the HUD and the weapon logic all read from it — adding a weapon is a
single data edit, no UI or gameplay code changes. See
[EXTENDING.md](EXTENDING.md).

## Persistence

`Profile` and `Servers` serialize to JSON under `user://`, which works on all
six target platforms (web uses IndexedDB transparently). There is no server-
side account system yet — see [NETWORKING.md](NETWORKING.md) for the
recommended path to one.

## Rendering / multiplatform choices

- **GL Compatibility renderer** — the only renderer that targets desktop,
  mobile *and* WebGL2 from one project.
- **`canvas_items` stretch mode** with `expand` aspect: the UI scales cleanly
  from phone screens to desktop monitors.
- **Vector placeholder art** (polygons/rects): zero binary assets, tiny repo,
  trivially replaceable with sprites later (swap the `Polygon2D` visuals for
  `Sprite2D`/`AnimatedSprite2D` nodes — nothing else changes).
- `emulate_touch_from_mouse` is on, so touch UI is testable on desktop.
