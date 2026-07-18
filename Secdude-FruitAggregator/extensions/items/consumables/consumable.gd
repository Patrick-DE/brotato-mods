extends "res://items/consumables/consumable.gd"
# =============================================================================
# consumable.gd extension - value-preserving fruit merging (effect replay)
# -----------------------------------------------------------------------------
# Adds a `merge_count` so several nearby identical fruits collapse into ONE node
# without losing any healing. On pickup the node replays its heal effect once
# per merged fruit BEFORE vanilla consumes it, so the game recomputes every heal
# through the player's stats (e.g. `consumable_heal`) - exact parity with eating
# the fruits one by one.
#
# VERIFY against your decompiled `res://items/consumables/consumable.gd` (version
# specific, NOT a public API):
#   1. This script's `extends` path.
#   2. `consumable_data` is the ConsumableData instance on the node.
#   3. pickup(player_index) is the pickup entry point.
#   4. RunData.apply_item_effects(consumable_data, player_index) applies effects
#      (the same call the game makes in main.gd::on_consumable_picked_up).
#
# FAIL-SAFE by design:
#   * consumable_data may be null at _ready (the spawner assigns it after the
#     node enters the tree), so we join the merge group UNCONDITIONALLY and let
#     the aggregator decide mergeability later, when data is populated.
#   * Replays run BEFORE the vanilla pickup that pools the node -> no
#     use-after-free.
#   * Consumable nodes are pooled and the pool is SHARED across all consumable
#     types, so merge_count is reset in drop() (the universal respawn seam) -
#     otherwise a recycled survivor would replay fruit heals onto an unrelated
#     consumable (e.g. a reused item box -> duplicated loot).
# =============================================================================

var Config = load("res://mods-unpacked/Secdude-FruitAggregator/scripts/fruit_config.gd")
var MergeService = load("res://mods-unpacked/Secdude-FruitAggregator/scripts/fruit_merge_service.gd")

var merge_count: int = 0   # how many fruits were merged into this one (>= 0)

func _ready() -> void:
	._ready()   # vanilla Item._ready() -> reset() (hide, monitorable, physics)
	# Unconditional: data may still be null here. Cheap, and the aggregator
	# filters by is_mergeable() at scan time.
	add_to_group(Config.MOD_GROUP)

# Runs on first spawn AND on every pool reuse (spawn_consumables always calls it).
# Clears merge state so a recycled node - the consumable pool is shared across
# ALL consumable types - never carries a stale count into its next life.
func drop(pos: Vector2, p_rotation: float, p_push_back_destination: Vector2) -> void:
	merge_count = 0
	_update_visuals()
	.drop(pos, p_rotation, p_push_back_destination)

# Stable type id, used to only ever merge identical consumables.
func get_merge_key() -> String:
	if consumable_data == null:
		return ""
	var key = consumable_data.get("my_id")   # (VERIFY) id field on ConsumableData
	if key == null:
		return ""
	return str(key)

func is_mergeable() -> bool:
	var key := get_merge_key()
	if key == "":
		return false
	return Config.MERGEABLE_TYPE_KEYS.has(key)

# Called by the aggregator when `other` is merged into this fruit. Absorbs the
# other fruit AND anything already merged into it (chain-safe).
func absorb(other) -> void:
	if other == null:
		return
	merge_count = MergeService.combine_counts(merge_count, 1 + other.merge_count)
	_update_visuals()

func _update_visuals() -> void:
	var sprite = get_node_or_null("Sprite")
	if sprite != null:
		var ratio = clamp(float(merge_count) / 15.0, 0.0, 1.0)
		var c = Color.white
		if ratio < 0.5:
			# White to Yellow (0 to ~7 merges)
			c = Color.white.linear_interpolate(Color.yellow, ratio * 2.0)
		else:
			# Yellow to Red (~8 to 15+ merges)
			c = Color.yellow.linear_interpolate(Color.red, (ratio - 0.5) * 2.0)
		sprite.modulate = c

# --- Consume hook -----------------------------------------------------------
# We replay this fruit's heal once per merged fruit FIRST (node still alive, so
# all reads are safe), THEN let vanilla apply the final heal and pool the node.
# Total applications == original fruit count.
func pickup(player_index: int) -> void:
	var replays := merge_count
	for _i in range(replays):
		_replay_heal(player_index)
	.pickup(player_index)

# The single effect-replay seam. Reproduces ONE fruit's heal without freeing the
# node by reusing vanilla's own stat-faithful effect application.
func _replay_heal(player_index: int) -> void:
	if consumable_data != null:
		RunData.apply_item_effects(consumable_data, player_index)
