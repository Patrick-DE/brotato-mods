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

const Config = preload("res://mods-unpacked/Secdude-FruitAggregator/scripts/mod_config.gd")
const SpatialHashGrid = preload("res://mods-unpacked/Secdude-FruitAggregator/scripts/spatial_hash_grid.gd")

var _grid
var _accum: float = 0.0

var merge_radius: float = Config.MERGE_RADIUS
var min_fruits_to_merge: int = Config.MIN_FRUITS_TO_MERGE

func _ready() -> void:
	_update_config()
	if Engine.has_singleton("ModLoader"):
		# In Godot ModLoader v6+, ModLoader emits current_config_changed
		# Wait, actually it's a global singleton named ModLoader.
		pass
	# Just connect directly
	if has_node("/root/ModLoader"):
		get_node("/root/ModLoader").connect("current_config_changed", self, "_on_config_changed")
	
	_grid = SpatialHashGrid.new(merge_radius)
	set_process(true)

func _update_config() -> void:
	if not has_node("/root/ModLoaderConfig"):
		return
	var ml_config = get_node("/root/ModLoaderConfig")
	if ml_config == null:
		return
	# Use the class_name ModLoaderConfig directly if available
	var current_config = ModLoaderConfig.get_current_config("Secdude-FruitAggregator")
	if current_config != null and current_config.data != null:
		if current_config.data.has("merge_radius"):
			merge_radius = float(current_config.data["merge_radius"])
		if current_config.data.has("min_fruits_to_merge"):
			min_fruits_to_merge = int(current_config.data["min_fruits_to_merge"])
	
	if _grid != null:
		_grid = SpatialHashGrid.new(merge_radius)

func _on_config_changed(config) -> void:
	if config.mod_id == "Secdude-FruitAggregator":
		_update_config()

func _process(delta: float) -> void:
	# Throttle: run a pass at most every SCAN_INTERVAL seconds, not per frame.
	_accum += delta
	if _accum < Config.SCAN_INTERVAL:
		return
	_accum = 0.0
	_merge_pass()

func _merge_pass() -> void:
	var fruits := _collect_fruits()
	if fruits.size() < min_fruits_to_merge:
		return  # early / mid game: not worth the work

	_grid.clear()
	for f in fruits:
		_grid.insert(f, f.global_position)

	var radius_sq := merge_radius * merge_radius
	var consumed := {}   # instance_id -> true, fruits already merged this pass
	var merges := 0

	for a in fruits:
		if merges >= Config.MAX_MERGES_PER_TICK:
			break
		var a_id = a.get_instance_id()
		if consumed.has(a_id):
			continue  # `a` was already absorbed by an earlier survivor

		# Hoisted out of the inner loop - `a`'s key is constant across neighbours.
		var a_key = a.get_merge_key() if Config.MERGE_ONLY_SAME_TYPE else ""

		for b in _grid.get_neighbors(a.global_position):
			if not is_instance_valid(b):
				continue  # freed earlier this pass; grid entry is stale
			var b_id = b.get_instance_id()
			if b_id == a_id or consumed.has(b_id):
				continue  # never merge with self or an already-consumed fruit
			if Config.MERGE_ONLY_SAME_TYPE and a_key != b.get_merge_key():
				continue
			if a.global_position.distance_squared_to(b.global_position) > radius_sq:
				continue  # exact radius test (squared: avoids a sqrt)

			_merge(a, b)
			consumed[b_id] = true
			merges += 1
			if merges >= Config.MAX_MERGES_PER_TICK:
				break

# Consumables register themselves into MOD_GROUP (unconditionally, since their
# data may be null at _ready). We filter to actually-mergeable fruits HERE, when
# consumable_data is reliably populated - so crates/loot boxes are excluded and
# the MIN_FRUITS_TO_MERGE gate counts only real fruits.
func _collect_fruits() -> Array:
	var out := []
	for n in get_tree().get_nodes_in_group(Config.MOD_GROUP):
		if not is_instance_valid(n):
			continue
		if n.is_queued_for_deletion():
			continue
		if not n.is_mergeable():
			continue
		out.append(n)
	return out

func _merge(survivor, absorbed) -> void:
	survivor.absorb(absorbed)   # transfer merge count; guarded inside consumable.gd
	var main = get_parent()
	if main != null and "_consumables" in main:
		main._consumables.erase(absorbed)
	absorbed.queue_free()       # one fewer entity on screen
