extends CoopItemPopup

signal weapon_trade_button_pressed_coop(weapon_data, from_player_index, to_player_index)
signal item_trade_button_pressed_coop(item_data, from_player_index, to_player_index)
signal money_trade_button_pressed(amount, from_player_index, to_player_index)
signal item_sell_button_pressed(item_data, from_player_index)

var _ptrade = [null, null, null, null]
var _money_buttons = {}
var _money_cancel_down_path = null
var _money_buttons_flat: Array = []
var _trade_buttons_pending = false
var _sell_button: Control = null

const TRADE_MOD_ID = "ZloiDed-TradeMod"
const trade_money_enabled_config = "TRADE_MONEY_ENABLED"
const trade_fee_enabled_config = "TRADE_FEE_ENABLED"
const trade_sell_enabled_config = "TRADE_SELL_ENABLED"
const trade_fee_rate = 0.5
const money_transfer_amounts = [50, 100]
const sell_price = 1

func _has_common_parent(a: Node, b: Node) -> bool:
	if a == null or b == null:
		return false
	var ancestors := {}
	var cur: Node = a
	while cur != null:
		ancestors[cur] = true
		cur = cur.get_parent()
	cur = b
	while cur != null:
		if ancestors.has(cur):
			return true
		cur = cur.get_parent()
	return false

func _is_focus_safe(a: Control, b: Control) -> bool:
	return is_instance_valid(a) and is_instance_valid(b) and a.is_inside_tree() and b.is_inside_tree() and a.get_tree() == b.get_tree() and _has_common_parent(a, b)

func _safe_set_focus_neighbour(a: Control, dir: int, b: Control) -> void:
	if _is_focus_safe(a, b):
		var path = b.get_path()
		if path != NodePath() and a.get_node_or_null(path) != null:
			a.set_focus_neighbour(dir, path)

func _safe_set_focus_neighbour_path(a: Control, dir: int, path: NodePath) -> void:
	if a == null or path == NodePath():
		return
	if a.get_node_or_null(path) != null:
		a.set_focus_neighbour(dir, path)

func Is_coop() -> bool:
	return RunData.get_player_count() > 1

func _ready():
	if not Is_coop():
		return
	if _cancel_button == null:
		return

	for player_index in RunData.get_player_count():
		var button = _build_trade_button()
		button.text = _get_trade_button_base_label(player_index)
		button.name = "%%_p%s" % (player_index + 1)
		button.set_meta("trade_target", player_index)
		button.connect("pressed", self, "_on_TradeButton_pressed_coop" + str(player_index + 1))
		button.hide()
		_ptrade[player_index] = button
		var buttons = _cancel_button.get_parent()
		buttons.add_child(button)
		buttons.move_child(button, _cancel_button.get_index() + 1)

	_sell_button = _build_trade_button()
	_sell_button.text = _get_sell_button_text()
	_sell_button.name = "%%_sell_item"
	_sell_button.connect("pressed", self, "_on_sell_button_pressed")
	_sell_button.hide()
	var buttons = _cancel_button.get_parent()
	buttons.add_child(_sell_button)
	buttons.move_child(_sell_button, _cancel_button.get_index() + 1)

	_create_money_buttons()

func _build_trade_button() -> Control:
	var button = preload("res://ui/menus/global/my_menu_button.gd").new()
	button.theme = _cancel_button.theme
	button.add_font_override("font", _cancel_button.get_font("font"))
	var normal_style = _discard_button.get_stylebox("normal").duplicate()
	button.add_stylebox_override("normal", normal_style)
	button.rect_min_size = _cancel_button.rect_min_size
	button.size_flags_horizontal = _cancel_button.size_flags_horizontal
	button.size_flags_vertical = _cancel_button.size_flags_vertical
	return button

func _create_money_buttons() -> void:
	if _cancel_button == null:
		return
	var buttons = _cancel_button.get_parent()
	for target_index in RunData.get_player_count():
		_money_buttons[target_index] = []
		for amount in money_transfer_amounts:
			var button = _build_trade_button()
			button.text = _get_money_button_text(amount, target_index)
			button.name = "%%_money_p%s_%s" % [str(target_index + 1), str(amount)]
			button.set_meta("money_amount", amount)
			button.connect("pressed", self, "_on_money_trade_button_pressed", [target_index, amount])
			button.hide()
			button.focus_mode = FOCUS_NONE
			_money_buttons[target_index].append(button)
			_money_buttons_flat.append(button)
			buttons.add_child(button)
			buttons.move_child(button, _cancel_button.get_index() + 1)

func _is_money_transfer_enabled() -> bool:
	var config = ModLoaderConfig.get_current_config(TRADE_MOD_ID)
	if config != null and trade_money_enabled_config in config.data:
		return config.data[trade_money_enabled_config]
	return true

func _is_trade_fee_enabled() -> bool:
	var config = ModLoaderConfig.get_current_config(TRADE_MOD_ID)
	if config != null and trade_fee_enabled_config in config.data:
		return config.data[trade_fee_enabled_config]
	return true

func _is_sell_enabled() -> bool:
	var config = ModLoaderConfig.get_current_config(TRADE_MOD_ID)
	if config != null and trade_sell_enabled_config in config.data:
		return bool(config.data[trade_sell_enabled_config])
	return true

func _get_item_id_hash(item_data: ItemParentData) -> int:
	if item_data == null:
		return Keys.empty_hash
	var item_id_hash = item_data.get("my_id_hash")
	return item_id_hash if item_id_hash is int else Keys.empty_hash

func _get_trade_fee(item_data: ItemParentData) -> int:
	if item_data == null:
		return 0
	if ItemService == null or not ItemService.has_method("get_value"):
		return 0
	var base_cost = ItemService.get_value(
		RunData.current_wave,
		item_data.value,
		player_index,
		true,
		item_data is WeaponData,
		_get_item_id_hash(item_data)
	)
	if base_cost <= 0:
		return 0
	return int(round(base_cost * trade_fee_rate))

func _trade_button_label(target_index: int) -> String:
	var base_text = _get_trade_button_base_label(target_index)
	var player_name = _get_player_name(target_index)
	if player_name != "":
		base_text = "%s (%s)" % [base_text, player_name]
	if _is_trade_fee_enabled():
		var fee = _get_trade_fee(_item_data)
		if fee > 0:
			return "%s (-%s)" % [base_text, str(fee)]
	return base_text

func _get_trade_button_base_label(target_index: int) -> String:
	var base_key = "TRADE_GIVE_TO_PLAYER_BUTTON_%s" % str(target_index + 1)
	var translated = tr(base_key)
	if translated != base_key:
		return translated
	var locale = TranslationServer.get_locale().to_lower()
	if locale.begins_with("ru"):
		return "Передать игроку %s" % str(target_index + 1)
	return "Give to player %s" % str(target_index + 1)

func _get_sell_button_text() -> String:
	var key = "TRADE_SELL_ITEM_BUTTON"
	var template = tr(key)
	if template == key:
		var locale = TranslationServer.get_locale().to_lower()
		if locale.begins_with("ru"):
			template = "Продать за {price} монету"
		else:
			template = "Sell for {price} coin"
	return template.replace("{price}", str(sell_price))

func _get_trade_target_index(button: Control) -> int:
	if button != null and button.has_meta("trade_target"):
		return int(button.get_meta("trade_target"))
	return -1

func _get_player_name(target_index: int) -> String:
	if RunData.players_data == null:
		return "P%s" % str(target_index + 1)
	if target_index < 0 or target_index >= RunData.players_data.size():
		return "P%s" % str(target_index + 1)
	var player_data = RunData.players_data[target_index]
	if player_data == null or player_data.current_character == null:
		return "P%s" % str(target_index + 1)
	var name_key = player_data.current_character.get("name_key")
	if name_key is String and name_key != "":
		var translated = TranslationServer.translate(name_key)
		if translated != name_key:
			return translated
	var raw_name = player_data.current_character.get("name")
	if raw_name is String and raw_name != "":
		var translated_name = TranslationServer.translate(raw_name)
		return translated_name if translated_name != raw_name else raw_name
	var my_id = player_data.current_character.get("my_id")
	if my_id is String and my_id != "":
		return my_id
	return "P%s" % str(target_index + 1)

func update_trade_buttons() -> void:
	if _trade_buttons_pending:
		return
	_trade_buttons_pending = true
	call_deferred("_update_trade_buttons_now")

func _update_trade_buttons_now() -> void:
	_trade_buttons_pending = false
	if not is_instance_valid(_cancel_button) or not _cancel_button.is_inside_tree():
		return
	if not _focused or not buttons_enabled:
		for button in _ptrade:
			if button != null:
				button.hide()
				button.focus_mode = FOCUS_NONE
		if _sell_button != null:
			_sell_button.hide()
			_sell_button.focus_mode = FOCUS_NONE
		return
	var cbd = _cancel_button.get_focus_neighbour(3)
	var visible_buttons: Array = []
	var show_sell = _sell_button != null and (_item_data is ItemData) and (not "character" in _item_data.my_id) and _is_sell_enabled()
	if show_sell:
		_sell_button.text = _get_sell_button_text()
		_sell_button.show()
		_sell_button.focus_mode = FOCUS_ALL if _focused else FOCUS_NONE
		visible_buttons.append(_sell_button)
	elif _sell_button != null:
		_sell_button.hide()
		_sell_button.focus_mode = FOCUS_NONE
	for target_index in range(RunData.get_player_count()):
		var button = _ptrade[target_index]
		if button == null:
			continue
		if target_index == player_index:
			button.hide()
			button.focus_mode = FOCUS_NONE
			continue
		button.text = _trade_button_label(target_index)
		button.show()
		button.focus_mode = FOCUS_ALL if _focused else FOCUS_NONE
		visible_buttons.append(button)

	if visible_buttons.size() > 0:
		visible_buttons.sort_custom(self, "_compare_button_index")
		_safe_set_focus_neighbour(_cancel_button, 3, visible_buttons[0])
		for i in range(visible_buttons.size()):
			var current = visible_buttons[i]
			if i == 0:
				_safe_set_focus_neighbour(current, 1, _cancel_button)
			else:
				_safe_set_focus_neighbour(current, 1, visible_buttons[i - 1])
			if i < visible_buttons.size() - 1:
				_safe_set_focus_neighbour(current, 3, visible_buttons[i + 1])
			else:
				if current.is_inside_tree() and cbd != NodePath():
					_safe_set_focus_neighbour_path(current, 3, cbd)
	else:
		if cbd != NodePath():
			_safe_set_focus_neighbour_path(_cancel_button, 3, cbd)

	if _focused:
		_cancel_button.show()
	else:
		_cancel_button.hide()
		
	if !ModLoaderStore.mod_data.has("RobocrafterLP-ItemSelling"):
		_discard_button.hide()
		
	_combine_button.hide()
	
	if _item_data is WeaponData and _focused:
		_discard_button.show()
		_combine_button.visible = RunData.can_combine(_item_data, player_index)
		

func _update_money_buttons() -> void:
	var should_show = Is_coop() and _is_money_transfer_enabled() and buttons_enabled and _item_data != null and "character" in _item_data.my_id
	if should_show and _cancel_button != null and not _cancel_button.visible:
		should_show = false
	for target_index in _money_buttons:
		var buttons = _money_buttons[target_index]
		for button in buttons:
			if button == null:
				continue
			if should_show and button.has_meta("money_amount"):
				var amount = int(button.get_meta("money_amount"))
				button.text = _get_money_button_text(amount, target_index)
			if should_show and target_index != player_index:
				button.show()
				button.focus_mode = FOCUS_ALL
			else:
				button.hide()
				button.focus_mode = FOCUS_NONE
	_update_money_focus_neighbours(should_show)

func _update_money_focus_neighbours(show_list: bool) -> void:
	if not is_instance_valid(_cancel_button):
		return
	if not _cancel_button.is_inside_tree():
		return
	var cancel_visible = _cancel_button.visible
	var cbd = _cancel_button.get_focus_neighbour(3)
	if not show_list:
		if cancel_visible and _money_cancel_down_path != null:
			_safe_set_focus_neighbour_path(_cancel_button, 3, _money_cancel_down_path)
			_money_cancel_down_path = null
		return
	if cancel_visible and _money_cancel_down_path == null:
		_money_cancel_down_path = cbd
	var flat_buttons = _get_money_buttons_visible()
	if flat_buttons.size() > 0:
		if cancel_visible:
			_safe_set_focus_neighbour(_cancel_button, 3, flat_buttons[0])
		for i in range(flat_buttons.size()):
			var current = flat_buttons[i]
			if i == 0:
				_safe_set_focus_neighbour(current, 1, _cancel_button)
			else:
				_safe_set_focus_neighbour(current, 1, flat_buttons[i - 1])
			if i < flat_buttons.size() - 1:
				_safe_set_focus_neighbour(current, 3, flat_buttons[i + 1])
			else:
				if cancel_visible and current.is_inside_tree() and _money_cancel_down_path != NodePath():
					_safe_set_focus_neighbour_path(current, 3, _money_cancel_down_path)

func _get_money_buttons_visible() -> Array:
	var visible_buttons: Array = []
	for button in _money_buttons_flat:
		if button != null and button.visible and button.is_inside_tree():
			visible_buttons.append(button)
	visible_buttons.sort_custom(self, "_compare_button_index")
	return visible_buttons

func _compare_button_index(a: Control, b: Control) -> bool:
	if a == null or b == null:
		return false
	return a.get_index() < b.get_index()

func _get_money_button_text(amount: int, target_index: int) -> String:
	var target_name = _get_player_name(target_index)
	var player_number = str(target_index + 1)
	var key = "TRADE_GIVE_MONEY_TO_PLAYER"
	var template = tr(key)
	if template == key:
		var locale = TranslationServer.get_locale().to_lower()
		if locale.begins_with("ru"):
			template = "Передать {amount} монет персонажу игрока {player} ({name})"
		else:
			template = "Give {amount} coins to player {player} character ({name})"
	template = template.replace("{amount}", str(amount))
	template = template.replace("{player}", player_number)
	template = template.replace("{name}", target_name)
	return template


func trade_update_visible(_element):
	if not Is_coop():
		return

	if _item_data is WeaponData and buttons_enabled:
		for _player_index in RunData.get_player_count():
			var button = _ptrade[_player_index]
			button.focus_mode = FOCUS_ALL if _focused else FOCUS_NONE
			
		update_trade_buttons()
	elif _item_data is ItemData and buttons_enabled and not "character" in _item_data.my_id:
		for _player_index in RunData.get_player_count():
			var button = _ptrade[_player_index]
			button.focus_mode = FOCUS_ALL if _focused else FOCUS_NONE
		
		update_trade_buttons()
	else:
		for _player_index in RunData.get_player_count():
			var button = _ptrade[_player_index]
			button.hide()
			button.focus_mode = FOCUS_NONE
		if _sell_button != null:
			_sell_button.hide()
			_sell_button.focus_mode = FOCUS_NONE
	_update_money_buttons()

func display_element(element: InventoryElement) -> void:
	.display_element(element)
	trade_update_visible(null)
	_compat_fix_improved_tooltips_update_button()

func _compat_fix_improved_tooltips_update_button() -> void:
	if not ModLoaderStore.mod_data.has("_wl-ImprovedTooltips"):
		return
	if _combine_button == null:
		return
	var button_container = _combine_button.get_parent()
	if button_container == null:
		return
	var allow_upgrade = _item_data is WeaponData
	if RunData != null and RunData.get_player_weapons(player_index).size() == 0:
		allow_upgrade = false
	for child in button_container.get_children():
		if not (child is Control):
			continue
		var btn = child as Control
		if not btn.has_signal("pressed"):
			continue
		var connections = btn.get_signal_connection_list("pressed")
		for connection in connections:
			if "method" in connection and connection["method"] == "_wl_show_update":
				if not allow_upgrade:
					btn.focus_mode = FOCUS_NONE
					btn.visible = false
				return

func focus()->void :
	.focus()
	trade_update_visible(null)

func hide(_player_index: = - 1)->void :
	.hide(_player_index)
	trade_update_visible(null)

func _on_TradeButton_pressed_coop1() -> void:
	_on_TradeButton_pressed_coop(0)

func _on_TradeButton_pressed_coop2() -> void:
	_on_TradeButton_pressed_coop(1)

func _on_TradeButton_pressed_coop3() -> void:
	_on_TradeButton_pressed_coop(2)

func _on_TradeButton_pressed_coop4() -> void:
	_on_TradeButton_pressed_coop(3)

func _on_TradeButton_pressed_coop(to: int) -> void:
	if _item_data is ItemData:
		emit_signal("item_trade_button_pressed_coop", _item_data, player_index, to)
	elif _item_data is WeaponData:
		emit_signal("weapon_trade_button_pressed_coop", _item_data, player_index, to)

func _on_sell_button_pressed() -> void:
	if _item_data is ItemData and not "character" in _item_data.my_id:
		emit_signal("item_sell_button_pressed", _item_data, player_index)

func _on_money_trade_button_pressed(to: int, amount: int) -> void:
	emit_signal("money_trade_button_pressed", amount, player_index, to)
	_update_money_buttons()


func should_show_buttons(item_data: ItemParentData, focused: bool) -> bool:
	if item_data is ItemData:
		if "character" in item_data.my_id:
			return buttons_enabled and _is_money_transfer_enabled() and (not RunData.is_coop_run or focused)
		return buttons_enabled and not "character" in item_data.my_id and (not RunData.is_coop_run or focused)
	elif item_data is WeaponData:
		return .should_show_buttons(item_data, focused)
	return false

func _update_button_visibilities() -> void:
	var buttons := [_combine_button, _discard_button, _cancel_button]
	if _item_data is WeaponData:
		._update_button_visibilities()
		return
	elif _item_data is ItemData:
		if _item_data == null or not should_show_buttons(_item_data, _focused):
			for button in buttons:
				if button != null:
					button.hide()
					button.focus_mode = FOCUS_NONE
			return

		for button in buttons:
			if (button != _combine_button):
				button.show()
				button.focus_mode = FOCUS_ALL if _focused else FOCUS_NONE
		if "character" in _item_data.my_id:
			if _discard_button != null:
				_discard_button.hide()
				_discard_button.focus_mode = FOCUS_NONE
		
		trade_update_visible(null)
