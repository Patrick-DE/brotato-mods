extends Node

const MENUSTRING_LOG = "Tinki-BigMapSolo2"
const MOD_ID = "Tinki-BigMapSolo2"

# ModOptions registration state
var options_registered := false
var registration_retry_count := 0
const MAX_REGISTRATION_RETRIES := 5


func _init():
	ModLoaderLog.info("Init", MENUSTRING_LOG)
	var mod_dir_path := ModLoaderMod.get_unpacked_dir().plus_file(MOD_ID)
	var ext_dir := mod_dir_path.plus_file("extensions")
	ModLoaderMod.install_script_extension(ext_dir.plus_file("my_camera.gd"))


func _ready():
	ModLoaderLog.info("Ready", MENUSTRING_LOG)
	# Try to register options with a delay to ensure ModOptions is ready
	call_deferred("_register_mod_options")


func _get_mod_options() -> Node:
	# Use absolute path via root for robustness (works regardless of node tree position)
	var root = get_tree().get_root()
	if not root:
		return null
	var mod_loader = root.get_node_or_null("ModLoader")
	if not mod_loader:
		return null
	var mod_options_mod = mod_loader.get_node_or_null("Oudstand-ModOptions")
	if not mod_options_mod:
		return null
	return mod_options_mod.get_node_or_null("ModOptions")


func _register_mod_options() -> void:
	if options_registered:
		return

	# Retry loop instead of recursion to avoid stack buildup
	var mod_options = null
	while registration_retry_count < MAX_REGISTRATION_RETRIES:
		mod_options = _get_mod_options()
		if mod_options:
			break

		registration_retry_count += 1
		if registration_retry_count < MAX_REGISTRATION_RETRIES:
			yield (get_tree().create_timer(0.2), "timeout")

	if not mod_options:
		ModLoaderLog.error("Failed to register options after %d retries" % MAX_REGISTRATION_RETRIES, MENUSTRING_LOG)
		return

	var options_array: Array = [
		{
			"type": "toggle",
			"id": "locked_wide_camera",
			"label": "Locked Wide Camera",
			"default": true
		},
		{
			"type": "slider",
			"id": "zoom_intensity",
			"label": "Wide View Zoom Level",
			"default": 1.0,
			"min": 0.0,
			"max": 1.0,
			"step": 0.05
		},
		{
			"type": "dropdown",
			"id": "toggle_hotkey",
			"label": "Quick Toggle Input",
			"default": "Mouse - Middle Click",
			"choices": ["None", "Mouse - Middle Click", "Keyboard - Z", "Keyboard - X", "Keyboard - C", "Keyboard - F", "Keyboard - R", "Keyboard - V", "Keyboard - B", "Keyboard - Space", "Joy - R3 (Right Stick)", "Joy - L3 (Left Stick)", "Joy - Y (Triangle)", "Joy - X (Square)", "Joy - Select"]
		}
	]

	mod_options.register_mod_options(MOD_ID, {
		"tab_title": "Big Map Solo 2",
		"options": options_array,
		"info_text": "Customize your camera behavior. Uncheck to start with the vanilla follower camera."
	})

	options_registered = true
	ModLoaderLog.info("BigMapSolo 2 options registered successfully", MENUSTRING_LOG)


# Helper function to get current setting value
func get_setting(option_id: String):
	var mod_options = _get_mod_options()
	if not mod_options:
		return null
	return mod_options.get_value(MOD_ID, option_id)


# Helper function to update a setting value
func set_setting(option_id: String, value) -> void:
	var mod_options = _get_mod_options()
	if mod_options:
		mod_options.set_value(MOD_ID, option_id, value)
