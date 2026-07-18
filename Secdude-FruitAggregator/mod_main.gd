extends Node
# =============================================================================
# FruitAggregator - mod entry point
# -----------------------------------------------------------------------------
# ModLoader instantiates this once at startup. Its only job is to register the
# two script extensions. All real logic lives in scripts/ and extensions/.
# =============================================================================

const MOD_ID := "Secdude-FruitAggregator"
const EXT_DIR := "res://mods-unpacked/Secdude-FruitAggregator/extensions/"

func _init() -> void:
	ModLoaderMod.install_script_extension(EXT_DIR + "main.gd")
	ModLoaderMod.install_script_extension(EXT_DIR + "items/consumables/consumable.gd")

func _get_mod_options() -> Node:
	if not get_tree():
		return null
	var root = get_tree().root
	if not root:
		return null
	var mod_loader = root.get_node_or_null("ModLoader")
	if not mod_loader:
		return null
	var mod_options_mod = mod_loader.get_node_or_null("Oudstand-ModOptions")
	if not mod_options_mod:
		return null
	return mod_options_mod.get_node_or_null("ModOptions")

func _ready() -> void:
	ModLoaderLog.info("Fruit aggregation active.", MOD_ID)
	call_deferred("_register_mod_options")

func _register_mod_options() -> void:
	var mod_options = null
	for i in range(5):
		mod_options = _get_mod_options()
		if mod_options:
			break
		yield(get_tree().create_timer(0.2), "timeout")

	if mod_options and mod_options.has_method("register_mod_options"):
		var config = {
			"tab_title": "Fruit Aggregator",
			"options": [
				{
					"type": "slider",
					"id": "merge_radius",
					"label": "Merge Radius (px)",
					"default": 100.0,
					"min": 10.0,
					"max": 500.0,
					"step": 10.0
				},
				{
					"type": "slider",
					"id": "min_fruits_to_merge",
					"label": "Min Fruits to Merge",
					"default": 0,
					"min": 0,
					"max": 100,
					"step": 1
				}
			]
		}
		mod_options.register_mod_options(MOD_ID, config)

	# dami-ModOptions integration
	if has_node("/root/ModLoader/dami-ModOptions/ModsConfigInterface"):
		var dami = get_node("/root/ModLoader/dami-ModOptions/ModsConfigInterface")
		dami.connect("setting_changed", self, "_on_dami_setting_changed")

func _on_dami_setting_changed(setting_name: String, value, mod_name: String) -> void:
	if mod_name != MOD_ID:
		return
	# Quiet lookup: get_current_config() logs errors when no config exists, and a
	# slider drag fires this signal rapidly. Only persist when a config is present.
	var configs = ModLoaderConfig.get_configs(MOD_ID)
	if configs.has(ModLoaderConfig.DEFAULT_CONFIG_NAME):
		var config = configs[ModLoaderConfig.DEFAULT_CONFIG_NAME]
		if config != null:
			config.data[setting_name] = value
			config.save_to_file()
