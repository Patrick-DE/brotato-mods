extends "res://main.gd"
# =============================================================================
# main.gd extension - installs the FruitAggregator into the live game
# -----------------------------------------------------------------------------
# `res://main.gd` (class Main) is Brotato's in-run scene root. We add a single
# lightweight node as its child once the run starts. That node owns the merge
# loop; main.gd itself stays untouched.
# =============================================================================

var FruitAggregator = load("res://mods-unpacked/Secdude-FruitAggregator/scripts/fruit_aggregator.gd")

func _ready() -> void:
	# Vanilla Main's _ready() is called implicitly before this function.
	var aggregator = FruitAggregator.new()
	aggregator.name = "SecdudeFruitAggregator"
	add_child(aggregator)
