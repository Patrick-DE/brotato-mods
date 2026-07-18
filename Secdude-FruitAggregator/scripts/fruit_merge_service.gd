extends Reference
# =============================================================================
# FruitMergeService - pure rules for combining merged fruits
# -----------------------------------------------------------------------------
# Side-effect free. No scene tree, no nodes, no game state. Single choke point
# for "is this value safe?" so it can be reasoned about and tested in isolation
# (SRP). Everything is static - there is no instance state.
#
# The mod uses a COUNT model: each fruit tracks how many other fruits were
# merged into it. On pickup the survivor replays its heal effect once per merged
# fruit, so the game recomputes each heal through the player's stats (e.g. the
# `consumable_heal` bonus) - exact parity with eating the fruits separately.
# This is correct only when merged fruits share a type, which the aggregator
# enforces via MERGE_ONLY_SAME_TYPE.
# =============================================================================

var Config = load("res://mods-unpacked/Secdude-FruitAggregator/scripts/fruit_config.gd")

# Coerce any external number into a safe, non-negative int. Rejects non-numbers
# (null, String, etc.), rounds floats (rather than truncating toward zero), and
# clamps negatives to 0. Every value flowing in from a vanilla resource passes
# through here first.
static func sanitize_int(value) -> int:
	var t := typeof(value)
	if t != TYPE_INT and t != TYPE_REAL:
		return 0
	var v := int(round(value))
	if v < 0:
		return 0
	return v

# Combine two merge counts with negative + overflow protection.
static func combine_counts(a, b) -> int:
	var total := sanitize_int(a) + sanitize_int(b)
	if total > Config.MAX_MERGE_COUNT:
		return Config.MAX_MERGE_COUNT
	return total
