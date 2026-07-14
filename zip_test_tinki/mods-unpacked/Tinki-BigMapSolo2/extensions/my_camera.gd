extends "res://global/my_camera.gd"

const MOD_ID := "Tinki-BigMapSolo2"

var camera_mode: bool = false
var zoom_intensity: float = 1.0
var toggle_hotkey: String = "Mouse - Middle Click"

const KEY_MAP := {
	"Keyboard - Z": KEY_Z,
	"Keyboard - X": KEY_X,
	"Keyboard - C": KEY_C,
	"Keyboard - F": KEY_F,
	"Keyboard - R": KEY_R,
	"Keyboard - V": KEY_V,
	"Keyboard - B": KEY_B,
	"Keyboard - Space": KEY_SPACE
}

const JOY_MAP := {
	"Joy - R3 (Right Stick)": 9,
	"Joy - L3 (Left Stick)": 8,
	"Joy - Y (Triangle)": 3,
	"Joy - X (Square)": 2,
	"Joy - Select": 10
}


func _ready():
	if not RunData.is_coop_run:
		zoom_in_speed_factor = 1.0 # beaucoup plus rapide qu'avant
		zoom_out_speed_factor = 1.0 # quasi instantané
		
		# Try to fetch current settings
		var mod_options = _get_mod_options()
		if mod_options:
			var is_locked = mod_options.get_value(MOD_ID, "locked_wide_camera")
			if is_locked != null:
				camera_mode = !is_locked
			
			var intensity = mod_options.get_value(MOD_ID, "zoom_intensity")
			if intensity != null:
				zoom_intensity = intensity
			
			var hotkey = mod_options.get_value(MOD_ID, "toggle_hotkey")
			if hotkey != null:
				toggle_hotkey = hotkey
				
			# Connect to config changes to react in real-time
			if not mod_options.is_connected("config_changed", self , "_on_config_changed"):
				mod_options.connect("config_changed", self , "_on_config_changed")


func _get_mod_options() -> Node:
	var root = get_tree().get_root()
	var mod_loader = root.get_node_or_null("ModLoader")
	if mod_loader:
		var mod_options_mod = mod_loader.get_node_or_null("Oudstand-ModOptions")
		if mod_options_mod:
			return mod_options_mod.get_node_or_null("ModOptions")
	return null


func _on_config_changed(mod_id: String, option_id: String, new_value) -> void:
	if mod_id == MOD_ID:
		if option_id == "locked_wide_camera":
			camera_mode = !new_value
		elif option_id == "zoom_intensity":
			zoom_intensity = new_value
		elif option_id == "toggle_hotkey":
			toggle_hotkey = new_value


func _input(event: InputEvent) -> void:
	if toggle_hotkey == "None":
		return
		
	if toggle_hotkey == "Mouse - Middle Click":
		if event is InputEventMouseButton and event.button_index == BUTTON_MIDDLE and event.pressed:
			_toggle_camera_mode()
			get_tree().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.is_echo():
		if KEY_MAP.has(toggle_hotkey) and event.scancode == KEY_MAP[toggle_hotkey]:
			_toggle_camera_mode()
			get_tree().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed:
		if JOY_MAP.has(toggle_hotkey) and event.button_index == JOY_MAP[toggle_hotkey]:
			_toggle_camera_mode()
			get_tree().set_input_as_handled()


func _toggle_camera_mode() -> void:
	camera_mode = !camera_mode
	
	# Sync back to ModOptions
	var mod_options = _get_mod_options()
	if mod_options:
		mod_options.set_value(MOD_ID, "locked_wide_camera", !camera_mode)
		
		# Force update the UI Checkbox visually, because Oudstand-ModOptions
		# doesn't auto-update its injected UI when set_value is called via script.
		var root = get_tree().get_root()
		var checkbox = root.find_node("LockedWideCameraButton", true, false)
		if checkbox and checkbox is CheckButton:
			checkbox.set_block_signals(true)
			checkbox.pressed = !camera_mode
			checkbox.set_block_signals(false)


func _adjust_zoom(alive_targets: Array, delta: float) -> void:
	if not camera_mode and not RunData.is_coop_run:
		var zoom_val = 1.0 + (zoom_intensity * (_max_zoom - 1.0))
		zoom = Vector2(zoom_val, zoom_val)
		return
		
	._adjust_zoom(alive_targets, delta)
