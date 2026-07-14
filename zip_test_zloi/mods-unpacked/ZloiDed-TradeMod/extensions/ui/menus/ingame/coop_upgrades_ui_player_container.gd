extends CoopUpgradesUIPlayerContainer

signal item_trade_button_pressed(item_data, to_player_index)

func _ready()->void :
	var buttons = _take_button.get_parent().duplicate()
	_take_button.get_parent().get_parent().add_child(buttons)
	_take_button.get_parent().get_parent().move_child(buttons, _take_button.get_parent().get_index() + 1)
	for child in buttons.get_children():
		child.free()

	var player_count = RunData.get_player_count()
	var trade_buttons: Array = []
	for _player_index in player_count:
		if _player_index != player_index:
			var test = _take_button.get_stylebox("normal").duplicate()
			var button = _take_button.duplicate()
			button.text = _trade_button_label(_player_index)
			button.name = "%%_p%s" % (_player_index + 1)
			button.disconnect("pressed", self, "_on_TakeButton_pressed")
			button.connect("pressed", self, "_on_item_trade_button_pressed" + str(_player_index + 1))
			button.set_script(preload("res://ui/menus/global/my_menu_button.gd"))
			button.add_stylebox_override("normal", test)
			buttons.add_child(button)
			trade_buttons.append(button)

	# Keep base focus order; don't override neighbours here.

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

func _trade_button_label(target_index: int) -> String:
	var base_text = _get_trade_button_base_label(target_index)
	var player_name = _get_player_name(target_index)
	if player_name != "":
		base_text = "%s (%s)" % [base_text, player_name]
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

func _update_trade_buttons_focus(_trade_buttons: Array) -> void:
	return

func _on_item_trade_button_pressed1() -> void:
	_on_item_trade_button_pressed(0)

func _on_item_trade_button_pressed2() -> void:
	_on_item_trade_button_pressed(1)

func _on_item_trade_button_pressed3() -> void:
	_on_item_trade_button_pressed(2)

func _on_item_trade_button_pressed4() -> void:
	_on_item_trade_button_pressed(3)

func _on_item_trade_button_pressed(to: int):
	if _button_pressed:return 
	_button_pressed = true
	_button_delay_timer.start()
	if _things_to_process_container:
		_things_to_process_container.consumables.remove_element(_consumable_data)
	emit_signal("item_trade_button_pressed", _item_data, to)
