extends Reference
# =============================================================================
# FruitAggregator - central configuration
# -----------------------------------------------------------------------------
# Single source of truth. Holds ALL tunables AND every point where this mod
# touches vanilla Brotato. Change values here, never scattered across the code.
#
# Anything tagged (VERIFY) is a symbol that is NOT part of a public, stable API.
# Brotato's internal names can change between game versions and are only visible
# in a decompiled project (GDRETools). If a (VERIFY) value is wrong the mod
# fails SAFE - it simply does less (or nothing) instead of crashing the game.
# =============================================================================

const MOD_ID: String = "Secdude-FruitAggregator"

static func get_setting(setting_name: String, default_val):
	if Engine.has_main_loop():
		var tree = Engine.get_main_loop()
		if tree.root:
			var mod_loader = tree.root.get_node_or_null("ModLoader")
			if mod_loader:
				var mod_options_mod = mod_loader.get_node_or_null("Oudstand-ModOptions")
				if mod_options_mod:
					var mod_options = mod_options_mod.get_node_or_null("ModOptions")
					if mod_options and mod_options.has_method("get_value"):
						var val = mod_options.get_value(MOD_ID, setting_name)
						if val != null:
							return val

	# ModLoaderConfig fallback - QUIET lookup. get_current_config() logs TWO hard
	# ERRORs per call ("Mod has no config file." + "No config with name ...") when
	# the user profile holds no saved config entry for this mod. get_setting() is
	# polled during gameplay, so that spammed thousands of error lines/sec on
	# machines without a saved config (e.g. a fresh Steam Deck profile) - the
	# reported "infinite loop in log". get_configs() returns {} silently instead.
	var configs = ModLoaderConfig.get_configs(MOD_ID)
	if configs.has(ModLoaderConfig.DEFAULT_CONFIG_NAME):
		var config = configs[ModLoaderConfig.DEFAULT_CONFIG_NAME]
		if config and config.data.has(setting_name):
			return config.data[setting_name]
	return default_val

# --- Behaviour tunables (Dynamically fetched from ModOptions) ----------------
static func merge_radius() -> float:
	return float(get_setting("merge_radius", 100.0))

static func scan_interval() -> float:
	return float(get_setting("scan_interval", 0.25))

static func min_fruits_to_merge() -> int:
	return int(get_setting("min_fruits_to_merge", 0))

static func max_merges_per_tick() -> int:
	return int(get_setting("max_merges_per_tick", 60))

# --- Internal Constants ------------------------------------------------------
const MAX_MERGE_COUNT: int = 9999        # overflow guard on a fruit's merge count

# REQUIRED true for correct healing under effect-replay: the survivor replays
# ITS OWN heal effect once per merged fruit, so all merged fruits must share a
# type. Turning this off would heal cross-type merges as the survivor's type.
const MERGE_ONLY_SAME_TYPE: bool = true

# --- Vanilla coupling --------------------------------------------------------
# MOD_GROUP is OUR group, created by this mod, so it is always safe. EVERY
# consumable adds itself to it in consumable.gd::_ready (unconditionally, because
# consumable_data may not be set yet at _ready time). The aggregator filters to
# mergeable fruits at scan time, when the data is reliably populated.
const MOD_GROUP: String = "secdude_consumables"

# consumable_data ids that are allowed to merge. Keep this to the plain healing
# fruit only - never crates/loot boxes (stacking those would duplicate items).
# Set the real id(s) after inspecting the fruit's ConsumableData resource. While
# this list does not match any fruit the mod is a harmless no-op.        (VERIFY)
const MERGEABLE_TYPE_KEYS: Array = ["consumable_fruit"]
