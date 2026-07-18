extends "res://singletons/item_service.gd"

const MyCharacterData = preload("res://items/characters/character_data.gd")
const MyEffect = preload("res://items/global/effect.gd")
const MyGainStatForEveryStatEffect = preload("res://effects/items/gain_stat_for_every_stat_effect.gd")
const MyStatGainsModificationEffect = preload("res://effects/items/stat_gains_modification_effect.gd")

func init_unlocked_pool() -> void:
	var found = false
	for c in characters:
		if c.my_id == "character_secdude_mosquito":
			found = true
			break
			
	if not found:
		var mosquito = MyCharacterData.new()
		mosquito.my_id = "character_secdude_mosquito"
		mosquito.unlocked_by_default = true
		mosquito.name = "CHARACTER_SECDUDE_MOSQUITO"   # translation key (vanilla convention); registered in mod_main.gd
		
		# Safely load image in exported game without an import file
		mosquito.icon = _load_image_texture("res://mods-unpacked/Secdude-Mosquito/mosquito_icon.png")
		
		# Load appearance accessories
		var MyItemAppearanceData = preload("res://items/global/item_appearance_data.gd")
		
		var app_nose = MyItemAppearanceData.new()
		app_nose.position = 7 # Position.NOSE
		app_nose.display_priority = 2 # Priority.MEDIUM
		app_nose.depth = 400.0
		app_nose.is_character_appearance = true
		app_nose.sprite = _load_image_texture("res://mods-unpacked/Secdude-Mosquito/nose_icon.png")
		
		var app_wings = MyItemAppearanceData.new()
		app_wings.position = 9 # Position.BACK
		app_wings.display_priority = 1 # Priority.LOW
		app_wings.depth = 10.0
		app_wings.is_character_appearance = true
		app_wings.sprite = _load_image_texture("res://mods-unpacked/Secdude-Mosquito/wings_icon.png")
		
		var app_eyes = MyItemAppearanceData.new()
		app_eyes.position = 6 # Position.EYES
		app_eyes.display_priority = 2 # Priority.MEDIUM
		app_eyes.depth = 500.0
		app_eyes.is_character_appearance = true
		app_eyes.sprite = _load_image_texture("res://mods-unpacked/Secdude-Mosquito/eyes_icon.png")
		
		mosquito.item_appearances = [app_nose, app_wings, app_eyes]

		
		var eff1 = MyEffect.new()
		eff1.key = "stat_lifesteal"
		eff1.value = 20
		eff1.text_key = "stat_lifesteal"
		
		var eff2 = MyGainStatForEveryStatEffect.new()
		eff2.key = "stat_attack_speed"
		eff2.text_key = "effect_gain_stat_for_every_stat"
		eff2.value = 1
		eff2.stat_scaled = "stat_lifesteal"
		eff2.nb_stat_scaled = 1
		eff2.perm_stats_only = false
		
		var eff3 = MyEffect.new()
		eff3.key = "stat_dodge"
		eff3.text_key = "stat_dodge"
		eff3.value = 15
		
		var eff4 = MyEffect.new()
		eff4.key = "stat_speed"
		eff4.text_key = "stat_speed"
		eff4.value = 15
		
		var eff5 = MyEffect.new()
		eff5.key = "stat_max_hp"
		eff5.text_key = "stat_max_hp"
		eff5.value = -10
		
		var eff6 = MyEffect.new()
		eff6.key = "stat_hp_regeneration"
		eff6.text_key = "stat_hp_regeneration"
		eff6.value = -100
		
		var eff7 = MyEffect.new()
		eff7.key = "stat_percent_damage"
		eff7.text_key = "stat_percent_damage"
		eff7.value = -30
		
		var eff8 = MyEffect.new()
		eff8.key = "stat_range"
		eff8.text_key = "stat_range"
		eff8.value = -50
		
		var eff9 = MyStatGainsModificationEffect.new()
		eff9.key = "effect_increase_stat_gains"
		eff9.stat_displayed = "stat_lifesteal"
		eff9.stats_modified = ["stat_lifesteal"]
		eff9.value = 50
		
		var eff10 = MyEffect.new()
		eff10.key = "consumable_heal"
		eff10.text_key = "effect_consumable_heal"
		eff10.value = -100
		
		mosquito.effects = [eff1, eff2, eff3, eff4, eff5, eff6, eff7, eff8, eff9, eff10]
		
		mosquito.banned_item_groups = ["hp_regeneration", "consumable_heal"]
		
		var sick_char = load("res://items/characters/sick/sick_data.tres")
		mosquito.starting_weapons = sick_char.starting_weapons.duplicate()
		
		characters.push_back(mosquito)
		
	.init_unlocked_pool()

func _load_image_texture(path: String) -> ImageTexture:
	var tex = ImageTexture.new()
	var file = File.new()
	if file.open(path, File.READ) == OK:
		var buffer = file.get_buffer(file.get_len())
		var img = Image.new()
		var err = img.load_png_from_buffer(buffer)
		if err != OK:
			err = img.load_jpg_from_buffer(buffer)
		if err == OK:
			tex.create_from_image(img)
		file.close()
	return tex
