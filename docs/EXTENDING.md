# Extending the engine

The core is intentionally small and data-driven. The common growth paths:

## Add a weapon / grenade / perk

Weapons are built with the `_w()` helper in `autoload/item_db.gd` `_init()`:

```gdscript
_w("plasma_rifle", WeaponType.EXOTIC, "Plasma Rifle",
    "Experimental energy weapon.",
    12,        # unlock_level
    12000, 40, # price_silver, price_trinkets
    22, 5.0, true,  # damage, fire_rate, automatic
    2200.0, 1, 1.0, # projectile_speed, pellets, spread_deg
    20, 2.0,        # clip_size, reload_time
    Color(0.5, 1.0, 0.9))
```

Done — it appears in the Store (under its weapon class filter), can be
bought/equipped, shows in the Profile, and fires in-game with those stats.
Pellets > 1 makes it a shotgun; the `color` tints its bullets. Pass
`{"explosive": true, "blast_radius": 90.0}` as the trailing `extra` dict for
launcher-style rounds. Perks support `max_hp_bonus` and `speed_mult`;
grenades support `damage`, `radius`, `fuse`, `throw_speed`, `carry_count`.

## Add a map

1. Create a script-less scene in `maps/` (copy `maps/foundry.tscn` as a base).
2. Keep the **map contract**: a `World` node with `StaticBody2D` colliders
   (TileMaps work too), `SpawnPoints` markers named `Blue*` / `Red*`, and an
   optional `KillZone` Area2D (layer 0, mask 2).
3. Register it in `MAPS` in `autoload/map_db.gd` — it then shows up in the
   main-menu map picker and the server syncs it to late joiners
   automatically (`Game._sync_match_config`).
4. Add the scene path to `MAP_SCENES` in `tests/validate_scenes.gd`.

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

Add an entry to the `MODES` dictionary in **`autoload/game.gd`** with
`name`, `description`, `team_based`, `score_limit`, and optionally
`forced_weapon` (everyone uses one gun, like Instagib) or `gun_ladder`
(Gun Game-style progression). Scoring rules live in `report_kill`; modes
with bespoke rules (flags, zones) add map nodes that call into `Game`.
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
