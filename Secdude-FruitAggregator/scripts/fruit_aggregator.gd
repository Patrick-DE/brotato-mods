extends Node
# =============================================================================
# FruitAggregator - the orchestrator node
# -----------------------------------------------------------------------------
# Added as a child of the running game (see extensions/main.gd). Every
# SCAN_INTERVAL it collapses clusters of nearby, identical fruits into single
# nodes to cut down on-screen entity count in the late game.
#
# It is deliberately dumb about *how* to combine value (fruit.absorb) and about
# *where* fruits are (SpatialHashGrid) - it only wires those pieces together.
# =============================================================================

const Config = preload("res://mods-unpacked/Secdude-FruitAggregator/scripts/fruit_config.gd")
const SpatialHashGrid = preload("res://mods-unpacked/Secdude-FruitAggregator/scripts/spatial_hash_grid.gd")

var _grid
var _accum: float = 0.0
var _fruits_buffer := []

func _ready() -> void:
	_grid = SpatialHashGrid.new(Config.merge_radius())
	set_process(true)

func _process(delta: float) -> void:
	# Throttle: run a pass at most every SCAN_INTERVAL seconds, not per frame.
	_accum += delta
	if _accum < Config.scan_interval():
		return
	_accum = 0.0
	_merge_pass()

func _merge_pass() -> void:
	_collect_fruits()
	if _fruits_buffer.size() < Config.min_fruits_to_merge():
		return  # early / mid game: not worth the work

	_grid.clear()
	for i in range(_fruits_buffer.size()):
		var f = _fruits_buffer[i]
		_grid.insert(f, f.global_position)

	var current_merge_radius: float = Config.merge_radius()
	var radius_sq: float = current_merge_radius * current_merge_radius
	var max_merges: int = Config.max_merges_per_tick()
	var merges := 0

	for i in range(_fruits_buffer.size()):
		var a = _fruits_buffer[i]
		if merges >= max_merges:
			break
		if not is_instance_valid(a) or a.is_queued_for_deletion():
			continue

		var a_key = a.get_merge_key() if Config.MERGE_ONLY_SAME_TYPE else ""
		var a_pos = a.global_position

		var neighbors = _grid.get_neighbors(a_pos)
		for j in range(neighbors.size()):
			var b = neighbors[j]
			if not is_instance_valid(b) or b.is_queued_for_deletion() or b == a:
				continue
			if Config.MERGE_ONLY_SAME_TYPE and a_key != b.get_merge_key():
				continue
			if a_pos.distance_squared_to(b.global_position) > radius_sq:
				continue  # exact radius test (squared: avoids a sqrt)

			_merge(a, b)
			merges += 1
			if merges >= max_merges:
				break

# Consumables register themselves into MOD_GROUP (unconditionally, since their
# data may be null at _ready). We filter to actually-mergeable fruits HERE, when
# consumable_data is reliably populated - so crates/loot boxes are excluded and
# the MIN_FRUITS_TO_MERGE gate counts only real fruits.
func _collect_fruits() -> void:
	_fruits_buffer.clear()
	var all_fruits = get_tree().get_nodes_in_group(Config.MOD_GROUP)
	for i in range(all_fruits.size()):
		var n = all_fruits[i]
		if is_instance_valid(n) and not n.is_queued_for_deletion() and n.is_mergeable():
			_fruits_buffer.append(n)

func _merge(survivor, absorbed) -> void:
	survivor.absorb(absorbed)   # transfer merge count; guarded inside consumable.gd
	var main = get_parent()
	if main != null and "_consumables" in main:
		main._consumables.erase(absorbed)
	absorbed.queue_free()       # one fewer entity on screen
