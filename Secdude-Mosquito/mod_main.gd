extends Node

const MOD_ID = "Secdude-Mosquito"
const EXT_DIR = "res://mods-unpacked/Secdude-Mosquito/extensions/"

# The character name is a translation KEY (vanilla convention - every character
# uses a "CHARACTER_*" key resolved via tr()). We register it for every locale
# Brotato ships so tr() never falls back to the raw key. It is a proper noun, so
# the same value is used for all languages; edit per-locale below to localise.
const CHARACTER_NAME_KEY = "CHARACTER_SECDUDE_MOSQUITO"
const CHARACTER_NAME = "The Mosquito"
const GAME_LOCALES = ["de", "en", "es", "fr", "it", "ja", "ko", "pl", "pt", "ru", "tr", "zh", "zh_TW"]

func _init() -> void:
	ModLoaderMod.install_script_extension(EXT_DIR + "item_service.gd")

func _ready() -> void:
	_register_translations()
	ModLoaderLog.info("Secdude-Mosquito mod initialized.", MOD_ID)

# Register the character name for all shipped locales. Runs at mod init, long
# before the character-selection menu reads the name, so tr() always resolves.
func _register_translations() -> void:
	for locale in GAME_LOCALES:
		var t = Translation.new()
		t.locale = locale
		t.add_message(CHARACTER_NAME_KEY, CHARACTER_NAME)
		TranslationServer.add_translation(t)
