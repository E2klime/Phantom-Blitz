# Getting started

## Requirements

- [Godot 4.4 or newer](https://godotengine.org/download) — the **standard**
  build (GDScript). No C#/Mono needed, no plugins, no asset downloads.
- That's it. The project has zero external dependencies.

## Opening the project

1. Launch Godot → **Import** → select this repository's `project.godot`.
2. First import takes a few seconds (Godot generates its `.godot/` cache —
   that folder is disposable and git-ignored).
3. Press **F5** (Run Project). The main menu appears.

## Your first match

### Offline

Main menu → **Practice Offline**. You spawn alone in the arena — useful for
testing movement, weapons and map changes without any networking.

### Hosting + joining on one machine

1. Run the project twice (in the editor: **Debug → Run Multiple Instances → 2**
   is the fastest way; or export once and run the binary twice).
2. Instance A: **Play Online → Host a game → Host**.
3. Instance B: **Play Online**, type `127.0.0.1` into the address field →
   **Connect** (or select the built-in *Local Server* entry → **Join**).

You should see both players in the arena, on opposite teams, with live HP,
score, chat (keys **1–7**) and ping.

### Over the internet

Run a dedicated server on a machine with an open port:

```sh
# clients on desktop / mobile (ENet/UDP):
godot --headless --path . -- --server --port 7777

# clients in a browser (WebSocket/TCP):
godot --headless --path . -- --server --websocket --port 7777
```

Players then **Connect** to your public IP/domain. Add the server with
**Save to list** so it shows up in the server list permanently.

> Web builds can only *join* WebSocket servers — browsers cannot host.
> See [NETWORKING.md](NETWORKING.md).

## Where things are saved

| Data | File |
|---|---|
| Profile (name, level, XP, currencies, inventory, loadout, settings) | `user://profile.json` |
| Saved server list | `user://servers.json` |

`user://` maps to the platform's standard app-data dir (on web: IndexedDB).
Delete the files to reset progress.

## Validating the project headlessly (CI)

```sh
godot --headless --path . --import          # parse/import everything
godot --headless --path . --script res://tests/validate_scenes.gd
```

The validation script instantiates every scene and fails (non-zero exit) on
any script or scene error — wire it into CI to catch breakage early.
