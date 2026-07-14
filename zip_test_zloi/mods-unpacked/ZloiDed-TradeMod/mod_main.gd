extends Node

const TRADE_MOD_ID = "ZloiDed-TradeMod"
const TRADE_MOD_LOG_NAME := TRADE_MOD_ID + ":Main"
const TRADE_ITEMS_OVER_LIMIT_CONFIG = "TRADE_ITEMS_OVER_LIMIT"
const TRADE_FEE_ENABLED_CONFIG = "TRADE_FEE_ENABLED"
const TRADE_MONEY_ENABLED_CONFIG = "TRADE_MONEY_ENABLED"
const TRADE_SELL_ENABLED_CONFIG = "TRADE_SELL_ENABLED"

var mod_dir_path := ""
var extensions_dir_path := ""
var translations_dir_path := ""
var _option_label_to_key := {}
var _modoptions_localized := false
var _options_ui_localizer: Node = null

func _init() -> void:
	mod_dir_path = get_script().resource_path.get_base_dir()
	# Add extensions
	install_script_extensions()
	# Add translations
	add_translations()
	_register_config_translations()

func _ready():
	ModLoaderLog.info("Ready!", TRADE_MOD_LOG_NAME)
	_config()

func _config()-> void: # Defaults for Mods Options
	var data = ModLoaderStore.mod_data[TRADE_MOD_ID]
	var config = null

	if data != null:
		var version = data.manifest.version_number
		ModLoaderLog.info("Current Version is %s." % version, TRADE_MOD_LOG_NAME)
		config = ModLoaderConfig.get_config(TRADE_MOD_ID, version)

		if config == null:
			var defaultConfig = ModLoaderConfig.get_default_config(TRADE_MOD_ID)
			if defaultConfig != null:
				config = ModLoaderConfig.create_config(TRADE_MOD_ID, version, defaultConfig.data)
			else:
				config = ModLoaderConfig.create_config(TRADE_MOD_ID, version, {})
			
		if config != null:
			if config.has_method("set_name"):
				config.set_name(version)
			else:
				config.set("name", version)
		var current_name = ModLoaderConfig.get_current_config_name(TRADE_MOD_ID)
		if config != null:
			var should_set = false
			if not (current_name is String):
				should_set = true
			elif current_name == "" or current_name != version:
				should_set = true
			if should_set:
				ModLoaderConfig.set_current_config(config)
				if config.is_valid():
					config.save_to_file()
					ModLoaderLog.info("Save config to : %s" % config.save_path, TRADE_MOD_LOG_NAME)
	
	if config != null and (config.data is Dictionary):
		var defaults := {
			TRADE_ITEMS_OVER_LIMIT_CONFIG: true,
			TRADE_FEE_ENABLED_CONFIG: true,
			TRADE_MONEY_ENABLED_CONFIG: true,
			TRADE_SELL_ENABLED_CONFIG: true
		}
		var changed := false
		for key in defaults.keys():
			if not (key in config.data):
				config.data[key] = defaults[key]
				changed = true
		if changed and config.is_valid():
			config.save_to_file()

	var ModsConfigInterface = get_node_or_null("/root/ModLoader/dami-ModOptions/ModsConfigInterface")

	if ModsConfigInterface != null:
		_sync_modoptions_interface(ModsConfigInterface, config)
		ModLoaderLog.info("Connect setting_changed", TRADE_MOD_LOG_NAME)
		call_deferred("_localize_modoptions_labels_with_retry", ModsConfigInterface, 10)
		ModsConfigInterface.connect("setting_changed", self, "setting_changed")
	else:
		ModLoaderLog.info("ModsConfigInterface is null", TRADE_MOD_LOG_NAME)
	_ensure_options_ui_localizer()

func _sync_modoptions_interface(mods_config_interface: Node, config) -> void:
	if mods_config_interface == null or config == null:
		return
	if not mods_config_interface.has_method("get"):
		return
	if not (config.data is Dictionary):
		return
	var mod_configs = mods_config_interface.get("mod_configs")
	if not (mod_configs is Dictionary):
		return
	if not mod_configs.has(TRADE_MOD_ID) or not (mod_configs[TRADE_MOD_ID] is Dictionary):
		mod_configs[TRADE_MOD_ID] = {}
	var mod_config = mod_configs[TRADE_MOD_ID]
	for key in _get_known_config_keys():
		if key in config.data:
			mod_config[key] = bool(config.data[key])

func _ensure_options_ui_localizer() -> void:
	if _options_ui_localizer != null and is_instance_valid(_options_ui_localizer):
		return
	_options_ui_localizer = ModOptionsUiLocalizer.new()
	var root = get_tree().get_root()
	if root != null:
		root.call_deferred("add_child", _options_ui_localizer)

class ModOptionsUiLocalizer:
	extends Node

	var _rescan_attempts := 0
	var _last_locale := ""
	var _next_locale_check_ms := 0

	func _ready() -> void:
		pause_mode = Node.PAUSE_MODE_PROCESS
		var tree = get_tree()
		if tree != null and not tree.is_connected("node_added", self, "_on_node_added"):
			tree.connect("node_added", self, "_on_node_added")
		var root = tree.get_root() if tree != null else null
		if root != null:
			_scan_and_localize(root)
		_last_locale = _get_active_locale()
		set_process(true)
		_schedule_rescan()

	func _process(_delta: float) -> void:
		var now_ms = OS.get_ticks_msec()
		if now_ms < _next_locale_check_ms:
			return
		_next_locale_check_ms = now_ms + 300
		var locale = _get_active_locale()
		if locale != _last_locale:
			_last_locale = locale
			var tree = get_tree()
			var root = tree.get_root() if tree != null else null
			if root != null:
				_scan_and_localize(root)
			_schedule_rescan()

	func _on_node_added(node: Node) -> void:
		call_deferred("_scan_and_localize", node)
		_schedule_rescan()

	func _schedule_rescan() -> void:
		if _rescan_attempts >= 6:
			return
		_rescan_attempts += 1
		var tree = get_tree()
		if tree == null:
			return
		var timer = tree.create_timer(0.4)
		timer.connect("timeout", self, "_rescan_root")

	func _rescan_root() -> void:
		var tree = get_tree()
		if tree == null:
			return
		var root = tree.get_root()
		if root != null:
			_scan_and_localize(root)
		_schedule_rescan()

	func _scan_and_localize(node: Node) -> void:
		if node == null:
			return
		_localize_node(node)
		if not node.has_method("get_children"):
			return
		for child in node.get_children():
			_scan_and_localize(child)

	func _localize_node(node: Node) -> void:
		if node == null:
			return
		if not (node is Control):
			return
		var text = _get_control_text(node)
		if not (text is String) or text == "":
			return
		var locale = _get_active_locale().to_lower()
		var pairs = _get_option_label_pairs()
		for key in pairs.keys():
			var en_label = pairs[key]["en"]
			var ru_label = pairs[key]["ru"]
			if text == key or text == key.to_upper():
				_set_control_text(node, ru_label if locale.begins_with("ru") else en_label)
				return
			if locale.begins_with("ru") and (text == en_label or text == en_label.to_upper()):
				_set_control_text(node, ru_label)
				return
			if not locale.begins_with("ru") and (text == ru_label or text == ru_label.to_upper()):
				_set_control_text(node, en_label)
				return

	func _get_control_text(control: Control) -> String:
		if control.has_method("get_text"):
			return control.get_text()
		if control.has_method("get"):
			var value = control.get("text")
			return value if value is String else ""
		return ""

	func _set_control_text(control: Control, text: String) -> void:
		if control.has_method("set_text"):
			control.set_text(text)
			return
		if control.has_method("set"):
			control.set("text", text)

	func _get_active_locale() -> String:
		var locale = TranslationServer.get_locale()
		var text_node = get_node_or_null("/root/Text")
		if text_node != null:
			if text_node.has_method("get_locale"):
				var value = text_node.call("get_locale")
				if value is String and value != "":
					locale = value
			elif text_node.has_method("get_current_language"):
				var value = text_node.call("get_current_language")
				if value is String and value != "":
					locale = value
			elif text_node.has_method("get_language"):
				var value = text_node.call("get_language")
				if value is String and value != "":
					locale = value
			elif text_node.has_method("get"):
				var value = text_node.get("language")
				if value is String and value != "":
					locale = value
				else:
					value = text_node.get("current_language")
					if value is String and value != "":
						locale = value
		return locale

	func _get_option_label_pairs() -> Dictionary:
		return {
			TRADE_ITEMS_OVER_LIMIT_CONFIG: {
				"en": "Allow trading beyond item limit",
				"ru": "Передавать предметы сверх лимита"
			},
			TRADE_FEE_ENABLED_CONFIG: {
				"en": "Enable trade fee",
				"ru": "Включить комиссию обмена"
			},
			TRADE_MONEY_ENABLED_CONFIG: {
				"en": "Enable money transfer",
				"ru": "Включить передачу денег"
			},
			TRADE_SELL_ENABLED_CONFIG: {
				"en": "Enable item selling",
				"ru": "Включить продажу предметов"
			}
		}
	
	
func setting_changed(setting_name, value, mod_name)->void:
	if mod_name != TRADE_MOD_ID:
		return
	if _option_label_to_key.has(setting_name):
		setting_name = _option_label_to_key[setting_name]
	if not _is_known_config_key(setting_name):
		return
	var config = ModLoaderConfig.get_current_config(TRADE_MOD_ID)

	if config != null:
		config.data[setting_name] = bool(value)
		config.save_to_file()

func _is_known_config_key(setting_name: String) -> bool:
	return _get_known_config_keys().has(setting_name)

func _get_known_config_keys() -> Array:
	return [
		TRADE_ITEMS_OVER_LIMIT_CONFIG,
		TRADE_FEE_ENABLED_CONFIG,
		TRADE_MONEY_ENABLED_CONFIG,
		TRADE_SELL_ENABLED_CONFIG
	]

func install_script_extensions() -> void:
	extensions_dir_path = mod_dir_path.plus_file("extensions")

	var extensions = [
		"ui/menus/global/popup_manager.gd",
		"ui/menus/shop/coop_item_popup.gd",
		"ui/menus/shop/coop_shop.gd",
		"ui/menus/ingame/coop_upgrades_ui_player_container.gd",
		"ui/menus/ingame/upgrades_ui.gd"
	]

	# I don't think it makes much sense, but it looks cool
	for extension in extensions:
		ModLoaderMod.install_script_extension(extensions_dir_path.plus_file(extension))

func add_translations() -> void:
	# Use in-code translations to avoid mojibake from stale .translation files.
	return

func _register_config_translations() -> void:
	var csv_path = mod_dir_path.plus_file("translations").plus_file("trade-mod.csv")
	var file = File.new()
	if not file.file_exists(csv_path):
		ModLoaderLog.info("Translations CSV not found: %s" % csv_path, TRADE_MOD_LOG_NAME)
		return
	if file.open(csv_path, File.READ) != OK:
		ModLoaderLog.info("Failed to open translations CSV: %s" % csv_path, TRADE_MOD_LOG_NAME)
		return
	# Skip header
	if not file.eof_reached():
		file.get_line()
	var entries = []
	while not file.eof_reached():
		var line = file.get_line()
		if line == "":
			continue
		var parts = line.split(",", false, 2)
		if parts.size() < 3:
			continue
		parts[0] = parts[0].strip_edges()
		parts[1] = parts[1].strip_edges()
		parts[2] = parts[2].strip_edges()
		entries.append(parts)
	file.close()

	for locale in ["en", "ru"]:
		var tr = Translation.new()
		tr.locale = locale
		for parts in entries:
			var key = parts[0]
			var value = parts[1] if locale == "en" else parts[2]
			tr.add_message(key, value)
		TranslationServer.add_translation(tr)

func _localize_modoptions_labels_with_retry(mods_config_interface: Node, tries_left: int) -> void:
	if _modoptions_localized:
		return
	var localized = _localize_modoptions_labels(mods_config_interface)
	if localized:
		_modoptions_localized = true
		return
	if tries_left > 0:
		call_deferred("_localize_modoptions_labels_with_retry", mods_config_interface, tries_left - 1)

func _localize_modoptions_labels(mods_config_interface: Node) -> bool:
	if mods_config_interface == null:
		return false
	if not mods_config_interface.has_method("get"):
		return false
	var mod_configs = mods_config_interface.get("mod_configs")
	if not (mod_configs is Dictionary) or not mod_configs.has(TRADE_MOD_ID):
		return false
	var mod_config = mod_configs[TRADE_MOD_ID]
	if not (mod_config is Dictionary):
		return false
	var labels = _get_option_label_map()
	_option_label_to_key.clear()
	for key in labels.keys():
		if not mod_config.has(key):
			continue
		var label = labels[key]
		if label == "" or label == key:
			continue
		_option_label_to_key[label] = key
		mod_config[label] = mod_config[key]
		mod_config.erase(key)
		var tooltip_key = key + "_tooltip"
		if mod_config.has(tooltip_key):
			mod_config[label + "_tooltip"] = mod_config[tooltip_key]
			mod_config.erase(tooltip_key)
		var title_key = key + "_title"
		if mod_config.has(title_key):
			mod_config[label + "_title"] = mod_config[title_key]
			mod_config.erase(title_key)
	return true

func _get_option_label_map() -> Dictionary:
	var locale = TranslationServer.get_locale().to_lower()
	if locale.begins_with("ru"):
		return {
			TRADE_ITEMS_OVER_LIMIT_CONFIG: "Передавать предметы сверх лимита",
			TRADE_FEE_ENABLED_CONFIG: "Включить комиссию обмена",
			TRADE_MONEY_ENABLED_CONFIG: "Включить передачу денег",
			TRADE_SELL_ENABLED_CONFIG: "Включить продажу предметов"
		}
	return {
		TRADE_ITEMS_OVER_LIMIT_CONFIG: "Allow trading beyond item limit",
		TRADE_FEE_ENABLED_CONFIG: "Enable trade fee",
		TRADE_MONEY_ENABLED_CONFIG: "Enable money transfer",
		TRADE_SELL_ENABLED_CONFIG: "Enable item selling"
	}
