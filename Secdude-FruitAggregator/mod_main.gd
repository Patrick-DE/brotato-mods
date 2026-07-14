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

func _ready() -> void:
	ModLoaderLog.info("Fruit aggregation active.", MOD_ID)
