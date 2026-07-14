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
# VERIFY these against your decompiled `consumable.gd` - version specific, NOT a
# public API:
#   1. This script's `extends` path.
#   2. `consumable_data` is the ConsumableData instance on the node.
#   3. The consume/pickup method name + signature (assumed `consume(player)`).
#   4. Config.EFFECT_APPLY_METHOD (preferred) or Config.PLAYER_HEAL_METHOD +
#      Config.HEAL_FIELD (fallback).
#
# FAIL-SAFE by design:
#   * consumable_data may be null at _ready (the spawner often assigns it after
#     the node enters the tree), so we join the merge group UNCONDITIONALLY and
#     let the aggregator decide mergeability later, when data is populated.
#   * Replays run BEFORE the vanilla consume that frees the node -> no
#     use-after-free.
#   * If EFFECT_APPLY_METHOD is unset/missing we fall back to a raw heal, so
#     value is never lost and nothing crashes.
# =============================================================================

const Config = preload("res://mods-unpacked/Secdude-FruitAggregator/scripts/mod_config.gd")
const MergeService = preload("res://mods-unpacked/Secdude-FruitAggregator/scripts/fruit_merge_service.gd")

var merge_count: int = 0   # how many fruits were merged into this one (>= 0)

func _ready() -> void:
	._ready()
	# Unconditional: data may still be null here. Cheap, and the aggregator
	# filters by is_mergeable() at scan time.
	add_to_group(Config.MOD_GROUP)

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

# Total HP one fruit heals on its own. Only used by the raw-heal fallback.
func get_base_heal() -> int:
	if consumable_data != null:
		var raw = consumable_data.get(Config.HEAL_FIELD)   # (VERIFY) heal field
		if raw != null:
			var parsed := MergeService.sanitize_int(raw)
			if parsed > 0:
				return parsed
	return Config.FALLBACK_HEAL

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
# VERIFY the signature. We replay this fruit's heal once per merged fruit FIRST
# (node still alive, so all reads are safe), THEN let vanilla apply the final
# heal and free the node. Total applications == original fruit count.
func pickup(player_index: int) -> void:
	var replays = merge_count
	for _i in range(replays):
		_replay_heal(player_index)
	.pickup(player_index)

# The single effect-replay seam. Reproduces ONE fruit's heal without freeing the
# node. Preferred path reuses vanilla's own effect application (stat-faithful).
func _replay_heal(player_index: int) -> void:
	if consumable_data != null:
		RunData.apply_item_effects(consumable_data, player_index)
