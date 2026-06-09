# Phantom Blitz

A **core engine for an online shooter-platformer** (inspired by classic web
shooters like TDP4), built with **Godot 4.4 / GDScript**. One codebase runs on
**PC (Windows / Linux / macOS), mobile (Android / iOS) and Web (HTML5)**.

All visuals are placeholder vector shapes on purpose — this is a clean,
documented foundation you drop your art and content into.

## What's included

| Feature | Where |
|---|---|
| Main menu, Store, Server list, Profile, Settings | `scenes/ui/` |
| In-game HUD: EXP/level, coins + gold, team scores, ping, ammo/HP/grenades, quick chat (keys 1–7), kill feed | `scenes/ui/hud.tscn` |
| Touch controls (dual virtual sticks + buttons) for mobile/web | auto-shown on touch devices |
| Platformer combat: run, double jump, aim with mouse/stick, 5 weapons, grenades, perks | `scripts/game/` |
| Online multiplayer: host / join / direct connect, drop-in drop-out, team auto-balance, chat, ping, dedicated server mode | `autoload/net.gd` |
| Progression: XP/levels, two currencies, purchases, loadout, stats — saved locally | `autoload/profile.gd` |
| Data-driven item database (add a dictionary entry → it appears in the store and in-game) | `autoload/item_db.gd` |

## Quick start

1. Install [Godot 4.4+](https://godotengine.org/download) (standard build, no C# required).
2. Open this folder with Godot (`project.godot`).
3. Press **F5**.
   - **Practice Offline** — instant single-player arena.
   - **Play Online → Host** — start a server and play.
   - Second instance → **Play Online → Connect** to `127.0.0.1` and you have a LAN match.

Dedicated server (no window, e.g. on a VPS):

```sh
godot --headless -- --server --port 7777              # for desktop/mobile clients (ENet)
godot --headless -- --server --websocket --port 7777  # for web clients (WebSocket)
```

## Controls

| Action | Keyboard / mouse | Touch |
|---|---|---|
| Move | A/D or ←/→ | left stick |
| Jump / double jump | Space / W / ↑ | JUMP button |
| Aim + shoot | mouse + LMB | right stick (push to edge to fire) |
| Grenade | G or RMB | NADE button |
| Reload | R | automatic |
| Quick chat | 1–7 | — |
| Pause menu | Esc | — |

## Documentation

- [Getting started](docs/GETTING_STARTED.md) — setup, running, first match
- [Architecture](docs/ARCHITECTURE.md) — how the engine is organized
- [Networking](docs/NETWORKING.md) — transports, authority, RPC flows, master server
- [Exporting](docs/EXPORTING.md) — building for PC, Android, iOS and Web
- [Extending](docs/EXTENDING.md) — new weapons, maps, game modes

## Repository layout

```
project.godot        engine config: autoloads, input map, renderer
export_presets.cfg   export targets for all 6 platforms
autoload/            global singletons (game state, networking, profile, items, servers)
scenes/ui/           menu, store, server browser, profile, settings, HUD
scenes/game/         arena, player, projectile, grenade
scripts/             all GDScript code (ui/ and game/)
tests/               headless scene/script validation
docs/                documentation
```

## License

Source code: use however you like in your game. Engine: [Godot Engine](https://godotengine.org) (MIT).
