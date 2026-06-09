# Extending the engine

The core is intentionally small and data-driven. The common growth paths:

## Add a weapon / grenade / perk

Append one entry to `ITEMS` in `autoload/item_db.gd`:

```gdscript
"plasma_rifle": {
    "name": "Plasma Rifle",
    "category": Category.WEAPON,
    "description": "Experimental energy weapon.",
    "price_coins": 12000,
    "price_gold": 40,
    "unlock_level": 12,
    "damage": 22,
    "fire_rate": 5.0,
    "automatic": true,
    "projectile_speed": 2200.0,
    "pellets": 1,
    "spread_deg": 1.0,
    "clip_size": 20,
    "reload_time": 2.0,
    "color": Color(0.5, 1.0, 0.9),
},
```

Done — it appears in the Store, can be bought/equipped, shows in the Profile,
and fires in-game with those stats. Pellets > 1 makes it a shotgun; the
`color` tints its bullets. Perks support `max_hp_bonus` and `speed_mult`;
grenades support `damage`, `radius`, `fuse`, `throw_speed`, `carry_count`.

## Add a map

1. Duplicate `scenes/game/arena.tscn` and rebuild the `World` geometry
   (any `StaticBody2D` colliders work — TileMaps too).
2. Keep the **map contract**: `Players` node, `SpawnPoints` markers named
   `Blue*` / `Red*`, a `KillZone` Area2D, the root script with
   `get_spawn_position()` (reuse `arena.gd`), and the HUD instance.
3. Point `Game.ARENA_SCENE` to it — or turn that constant into a variable to
   support map voting / rotation (sync the choice from the server before
   `start_match`).

## Replace the placeholder art

Visuals are isolated from logic:

- Player: swap `BodyVisual`/`Head` polygons in `player.tscn` for an
  `AnimatedSprite2D`. Team tint is applied to the `BodyVisual` node —
  keep that name or update `player.gd:_refresh_identity()`.
- World: replace `Visual` polygons under each platform, or rebuild with a
  `TileMapLayer` (colliders included).
- Bullets/grenades: `Visual` nodes in their scenes.
- UI: everything is standard Godot `Control` themes — add a `Theme` resource
  to restyle every menu at once.

## Add a game mode

Match rules live in **`autoload/game.gd`** only (`report_kill`,
`SCORE_LIMIT`, `_sync_match_end`). For example, for Deathmatch ignore teams in
scoring; for Capture-the-Flag add flag nodes to the map that call into `Game`.
The HUD listens to `Game.score_changed` / `Game.match_ended` and doesn't care
how scores are produced.

## Add pickups (health, ammo, weapons on the map)

1. New scene: `Area2D` on physics layer 4 (`pickups`), monitoring layer 2
   (`players`).
2. On `body_entered`, run the effect **server-side only**
   (`if Net.is_server():`), e.g. `body.take_damage(-25, 0)` for a medkit,
   then despawn via RPC or a `MultiplayerSpawner`.

## Persistence / accounts

`Profile` is local JSON — fine for single player and friendly servers, forgeable
in serious online play. Production path: keep `Profile`'s API, but make
`purchase`/`add_xp` call an HTTP backend and treat the local file as a cache.

## Quality checklist when you extend

- Run `godot --headless --path . --script res://tests/validate_scenes.gd` —
  it loads every scene and fails on broken references.
- Test online with **Debug → Run Multiple Instances** (one hosts, one joins).
- Anything that changes *state others see* must run on the server and be
  pushed by RPC — never let clients write their own HP/score/currency in
  networked contexts.
