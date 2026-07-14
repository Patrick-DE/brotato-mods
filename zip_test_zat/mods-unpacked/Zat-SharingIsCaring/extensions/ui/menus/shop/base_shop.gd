extends "res://ui/menus/shop/base_shop.gd"

var share_materials: bool = true

func _ready():
	ModLoaderLog.info("Shop _ready!", "Zat-SharingIsCaring:Shop")
	var config = ModLoaderConfig.get_current_config("Zat-SharingIsCaring")
	ModLoaderLog.info("Config found!", "Zat-SharingIsCaring:Shop")
	if config != null and "SHARE_MATERIALS" in config.data:
		share_materials = config.data["SHARE_MATERIALS"]

	ModLoaderLog.info("Share materials: " + str(share_materials), "Zat-SharingIsCaring:Shop")

	if not share_materials:
		return

	var player_count: int = RunData.get_player_count()
	var gold: int = 0
	for player_index in player_count:
		gold += RunData.get_player_gold(player_index)
		
	var splits: int = gold / player_count
	ModLoaderLog.info("Players: " + str(player_count), "Zat-SharingIsCaring:Shop")
	ModLoaderLog.info("Total gold: " + str(gold), "Zat-SharingIsCaring:Shop")
	ModLoaderLog.info("Splits: " + str(splits), "Zat-SharingIsCaring:Shop")
	
	if gold == 0 or gold < player_count:
		return
	
	
	for player_index in player_count:
		RunData.remove_gold(RunData.get_player_gold(player_index), player_index)
		RunData.add_gold(splits, player_index)
