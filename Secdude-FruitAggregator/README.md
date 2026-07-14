# FruitAggregator

A performance mod for **Brotato** (Godot 3.5, GodotModding ModLoader).

In late-game waves, large numbers of ground consumables ("fruits") tank the
frame rate. Brotato already solves this for **materials**: past a cap, new drops
are merged into an existing blob instead of spawning a new node, so value is
never lost. **FruitAggregator applies the same idea to healing fruits** — nearby
identical fruits collapse into one node whose combined healing equals the sum of
the fruits it absorbed.

---

## How it works

| Piece | File | Responsibility |
|-------|------|----------------|
| Config | `scripts/fruit_config.gd` | Every tunable + every vanilla-coupling point, in one place |
| Spatial hash grid | `scripts/spatial_hash_grid.gd` | O(n) neighbour lookup (no game knowledge) |
| Merge service | `scripts/fruit_merge_service.gd` | Pure value math with overflow / negative guards |
| Aggregator node | `scripts/fruit_aggregator.gd` | Throttled merge loop, wires the pieces together |
| `main.gd` extension | `extensions/main.gd` | Spawns the aggregator into a live run |
| `consumable.gd` extension | `extensions/entities/units/consumables/consumable.gd` | Per-fruit stacking + value-preserving pickup |
| Entry point | `mod_main.gd` | Registers the two script extensions |

### The merge algorithm

1. **Fruits self-register.** When a healing fruit enters the tree it adds itself
   to our own group (`secdude_mergeable_fruits`). Using our own group means the
   mod never depends on guessing Brotato's internal group names.
2. **Throttle + gate.** The aggregator runs a pass at most every `SCAN_INTERVAL`
   (0.25 s), and only once at least `MIN_FRUITS_TO_MERGE` (20) fruits exist — so
   early/mid game has zero overhead.
3. **Spatial hash, not O(n²).** Each pass drops every fruit into a uniform grid
   whose cell size equals `MERGE_RADIUS`. To find a fruit's neighbours we only
   scan the 3×3 block of cells around it. With `cell == radius`, that block is
   mathematically guaranteed to contain every fruit within the radius, so we get
   correct results at roughly O(n) instead of O(n²).
4. **Exact test.** Candidates from the grid are confirmed with Godot's built-in
   `Vector2.distance_squared_to` compared against `radius²` (squared avoids a
   `sqrt`). Only fruits of the **same type** merge (`MERGE_ONLY_SAME_TYPE`).
5. **Merge = count + free.** The survivor's `merge_count` grows by the absorbed
   fruit (plus anything already merged into it, so chains stay correct); the
   absorbed fruit is `queue_free()`d. One fewer entity on screen.
6. **Pickup replays the effect.** When the survivor is consumed, the extension
   replays its heal effect once per merged fruit **before** the vanilla
   `.consume()` (which applies the final heal and frees the node). Total heals ==
   the original fruit count. Because the game recomputes each heal, the player's
   `consumable_heal` stat and any heal modifiers apply exactly as if the fruits
   were eaten one by one.

> **Why count, not summed HP.** Replaying the effect (rather than pre-summing HP
> and calling `heal()` with a raw number) is what preserves stat parity — but it
> means every merged fruit must share a type, which `MERGE_ONLY_SAME_TYPE = true`
> enforces. The replay call itself is the one version-specific seam: set
> `EFFECT_APPLY_METHOD` to your consumable's effect-application method. Until it
> is set, the mod falls back to a raw `heal()` so value is never lost — see the
> "Develop / verify" steps.

> **Trade-off (by design).** Because replay applies the *heal effect only*, any
> other per-consumable trigger (a "consumables collected" counter, pickup sound,
> `consumable_stats_while_max`, etc.) fires **once** for a merged node, not once
> per absorbed fruit. Healing is exact; those secondary per-pickup effects scale
> with node count, not fruit count. This is the intended consequence of merging.

### Safety / stability

- All counts flow through `fruit_merge_service.gd`, which rejects non-numbers,
  rounds floats, clamps negatives to `0`, and caps the merge count at
  `MAX_MERGE_COUNT` (overflow / replay-loop guard).
- Freed nodes are guarded with `is_instance_valid` / `is_queued_for_deletion`,
  and a fruit can never merge with itself or a fruit already consumed this pass.
- `MAX_MERGES_PER_TICK` bounds the work per pass so a huge pile can't spike a
  single frame.
- **Fail-safe:** every uncertain vanilla symbol is isolated in `fruit_config.gd`.
  If a symbol is wrong the mod does *less*, it does not crash — see below.

---

## Setup

### Requirements
- Brotato with the [GodotModding ModLoader](https://thunderstore.io/c/brotato/p/GodotModding/GodotModLoader/)
  installed and enabled.

### Install (players)
1. Copy the whole `Secdude-FruitAggregator/` folder into your Brotato
   `mods-unpacked/` directory:
   `…/Steam/steamapps/common/Brotato/mods-unpacked/Secdude-FruitAggregator/`
2. Launch the game with ModLoader enabled.
3. Check the ModLoader log for `Fruit aggregation active.` to confirm it loaded.

> Packaged (.zip / Thunderstore) installs work too — the `manifest.json` is
> already in Thunderstore format. Zip the folder's **contents** at the root.

### Develop / verify
Because Brotato's internal names are not a public API, confirm the `(VERIFY)`
values against a decompiled copy of your game version before shipping:

1. Decompile Brotato with **GDRETools** and open the project in **Godot 3.5**.
2. Open `res://entities/units/consumables/consumable.gd` and confirm:
   - the **class/field** that stores the resource is `consumable_data`;
   - the **pickup method** is `consume(player)` — if the name or arguments
     differ, rename the override in the extension to match exactly.
3. **Effect replay (recommended).** In that same file, find how `consume`
   applies the fruit's effect to the player (grep for `effects`, `RunData`, or
   `apply`). Set `EFFECT_APPLY_METHOD` in `fruit_config.gd` to that method's name.
   It **must apply effects only and must not free the node.** This gives full
   stat parity (`consumable_heal` etc.).
   - If you leave it `""`, the mod falls back to a raw heal: set `HEAL_FIELD`
     (field on `ConsumableData` holding the heal amount) and confirm the player
     exposes `PLAYER_HEAL_METHOD` (default `"heal"`). Value is preserved; only
     the healing stat is not re-applied to the merged portion.
4. Find the healing fruit's `ConsumableData` resource and read its `my_id`
   (or equivalent). Put that id in `MERGEABLE_TYPE_KEYS`. **Until this matches,
   the mod is a safe no-op.**

If `consume(player)` is handled in `main.gd` instead of `consumable.gd` in your
version, move the consume override there — the merge core (grid, service,
aggregator) does not change.

---

## Configuration

All in `scripts/fruit_config.gd`:

| Setting | Default | Meaning |
|---------|---------|---------|
| `MERGE_RADIUS` | `24.0` | px; fruits closer than this may merge |
| `SCAN_INTERVAL` | `0.25` | seconds between merge passes |
| `MIN_FRUITS_TO_MERGE` | `20` | do nothing below this fruit count |
| `MAX_MERGES_PER_TICK` | `60` | cap merges per pass (frame smoothing) |
| `MAX_MERGE_COUNT` | `9999` | overflow / replay-loop guard on merge count |
| `MERGE_ONLY_SAME_TYPE` | `true` | **required true** for correct effect replay |
| `EFFECT_APPLY_METHOD` | `""` | vanilla effect-apply method; `""` = raw-heal fallback |
| `FALLBACK_HEAL` | `3` | fallback base heal if the data field can't be read |
| `MERGEABLE_TYPE_KEYS` | `["consumable_fruit"]` | consumable ids allowed to merge |

## Uninstall
Delete the `Secdude-FruitAggregator/` folder from `mods-unpacked/`.

## License
MIT.
