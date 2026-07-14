extends CoopShop

const TRADE_MOD_ID = "ZloiDed-TradeMod"
const TRADE_MOD_LOG_NAME := TRADE_MOD_ID + ":Shop"
const trade_items_over_limit_config = "TRADE_ITEMS_OVER_LIMIT"
const trade_fee_enabled_config = "TRADE_FEE_ENABLED"
const trade_money_enabled_config = "TRADE_MONEY_ENABLED"
const trade_sell_enabled_config = "TRADE_SELL_ENABLED"
const trade_fee_rate = 0.5
const sell_item_price = 1
const _SETTING_NAME_ALIASES = {
	trade_items_over_limit_config: trade_items_over_limit_config,
	"Allow trading beyond item limit": trade_items_over_limit_config,
	"Передавать предметы сверх лимита": trade_items_over_limit_config,
	trade_fee_enabled_config: trade_fee_enabled_config,
	"Enable trade fee": trade_fee_enabled_config,
	"Включить комиссию обмена": trade_fee_enabled_config,
	trade_money_enabled_config: trade_money_enabled_config,
	"Enable money transfer": trade_money_enabled_config,
	"Включить передачу денег": trade_money_enabled_config,
	trade_sell_enabled_config: trade_sell_enabled_config,
	"Enable item selling": trade_sell_enabled_config,
	"Включить продажу предметов": trade_sell_enabled_config
}

var coop_trading_config
var is_trade_items_over_limit: bool
var is_trade_fee_enabled: bool
var is_trade_money_enabled: bool
var is_trade_sell_enabled: bool
var _last_focus_owner: Control = null
var _last_shop_focus_owner: Control = null
# There I tried to do "is_trade_weapons_over_limit"
# but when the player starts with a weapon over the limit, all weapons after the limit disappear.
#----------------------------------
# So, we could "crack the code" a little and add more hands to the player's over-limit weapons
# but I don't think that would make much sense.

func _ready() -> void:
	var player_count: int = RunData .get_player_count()
	set_process_input(true)
	set_process_unhandled_input(true)

	for player_index in player_count:
		var _item_popup = _get_item_popup(player_index)
		var _error_discard_weapon = _item_popup.connect(
			"weapon_trade_button_pressed_coop", self, "on_weapon_trade_button_pressed_coop"
		)
		var _error_discard_item = _item_popup.connect(
			"item_trade_button_pressed_coop", self, "on_item_trade_button_pressed_coop"
		)
		var _error_sell_item = _item_popup.connect(
			"item_sell_button_pressed", self, "on_item_sell_button_pressed_coop"
		)
		var _error_money_trade = _item_popup.connect(
			"money_trade_button_pressed", self, "on_money_trade_button_pressed"
		)
		
	var ModsConfigInterface = get_node_or_null("/root/ModLoader/dami-ModOptions/ModsConfigInterface")

	coop_trading_config = ModLoaderConfig.get_current_config(TRADE_MOD_ID)
	_load_trade_config()
	if ModsConfigInterface != null:
		ModsConfigInterface.connect("setting_changed", self, "on_config_changed")
	_fix_shop_focus_links()
	var viewport = get_viewport()
	if viewport != null and not viewport.is_connected("gui_focus_changed", self, "_on_gui_focus_changed"):
		viewport.connect("gui_focus_changed", self, "_on_gui_focus_changed")

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_visible_in_tree():
		_fix_shop_focus_links()

func _on_gui_focus_changed(control: Control) -> void:
	if control != null and control is Control:
		_last_focus_owner = control
		if _is_control_in_container(control, self):
			_last_shop_focus_owner = control

func _input(event: InputEvent) -> void:
	if event == null:
		return
	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down") or event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		call_deferred("_recover_focus_if_lost")
	if event.is_action_pressed("ui_up"):
		_handle_no_weapon_up()

func _recover_focus_if_lost() -> void:
	if not is_visible_in_tree():
		return
	var focus_owner = _get_focus_owner()
	if focus_owner != null and focus_owner is Control:
		return
	_recover_shop_focus()

func _unhandled_input(event: InputEvent) -> void:
	if event == null:
		return
	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down") or event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		call_deferred("_recover_focus_if_lost")

func _handle_no_weapon_up() -> void:
	if RunData == null:
		return
	var focus_owner = _get_focus_owner()
	if focus_owner == null or not (focus_owner is Control):
		return
	for player_index in range(RunData.get_player_count()):
		var shop_container = _get_shop_items_container(player_index)
		var gear_container = _get_gear_container(player_index)
		var player_container = _get_coop_player_container(player_index)
		if shop_container == null:
			continue
		if RunData.get_player_weapons(player_index).size() > 0:
			continue
		var bottom_root = gear_container if gear_container != null else player_container
		if bottom_root == null:
			continue
		if _is_control_in_container(focus_owner, shop_container):
			continue
		if not _is_control_in_container(focus_owner, bottom_root):
			continue
		var bottom_focusables: Array = []
		var player_focusables = _find_focusables_in_node(bottom_root)
		for control in player_focusables:
			if _is_control_in_container(control, shop_container):
				continue
			bottom_focusables.append(control)
		if bottom_focusables.size() == 0:
			continue
		var min_y = _get_min_y(bottom_focusables)
		if not _is_top_row(focus_owner, min_y):
			return
		var up_target = _resolve_focus_target(focus_owner, focus_owner.get_focus_neighbour(1))
		if _is_focusable_control(up_target) and not _is_control_in_container(up_target, bottom_root):
			return
		var shop_focusables = _find_focusables_in_node(shop_container)
		var target: Control = null
		if shop_focusables.size() > 0:
			shop_focusables.sort_custom(self, "_compare_focusable_index")
			target = shop_focusables[shop_focusables.size() - 1]
		else:
			target = _find_focusable_control_by_name(["reroll", "refresh"])
		if target != null and target.is_inside_tree():
			target.grab_focus()
			return

func _get_focus_owner() -> Node:
	var viewport = get_viewport()
	if viewport == null:
		return null
	var owner: Node = null
	if viewport.has_method("gui_get_focus_owner"):
		owner = viewport.gui_get_focus_owner()
	elif viewport.has_method("get_focus_owner"):
		owner = viewport.get_focus_owner()
	return owner

func _recover_shop_focus() -> void:
	if not is_visible_in_tree():
		return
	var focus_owner = _get_focus_owner()
	if focus_owner != null:
		var focus_control = focus_owner if focus_owner is Control else null
		if _is_visible_control(focus_control):
			_last_focus_owner = focus_control
			return
		_last_focus_owner = focus_control
		focus_owner = null
	var target: Control = null
	if _last_focus_owner != null and is_instance_valid(_last_focus_owner) and _is_focusable_control(_last_focus_owner):
		target = _last_focus_owner
	if target == null:
		target = _get_preferred_focus_control()
	if target != null and target.is_inside_tree() and target.visible:
		target.grab_focus()

func _is_shop_control(node: Node) -> bool:
	if node == null:
		return false
	if node == self:
		return true
	return is_a_parent_of(node)

func _get_preferred_focus_control() -> Control:
	var player_count = RunData.get_player_count() if RunData != null else 0
	for player_index in range(player_count):
		var shop_container = _get_shop_items_container(player_index)
		var shop_focusable = _find_focusable_in_node(shop_container)
		if shop_focusable != null:
			return shop_focusable
	for player_index in range(player_count):
		var gear_container = _get_gear_container(player_index)
		var gear_focusable = _find_focusable_in_node(gear_container)
		if gear_focusable != null:
			return gear_focusable
	var primary = _find_focusable_control_by_name(["weapon", "weapons", "item", "items", "tab"])
	return primary if primary != null else _find_first_focusable_control()

func _find_focusable_control_by_name(substrings: Array) -> Control:
	var queue: Array = [self]
	while queue.size() > 0:
		var node = queue.pop_front()
		for child in node.get_children():
			queue.append(child)
		if node is Control:
			var control = node as Control
			if _is_focusable_control(control):
				var name_lower = control.name.to_lower()
				for substring in substrings:
					if name_lower.find(substring) >= 0:
						return control
	return null

func _find_first_focusable_control() -> Control:
	var queue: Array = [self]
	while queue.size() > 0:
		var node = queue.pop_front()
		for child in node.get_children():
			queue.append(child)
		if node is Control:
			var control = node as Control
			if _is_focusable_control(control):
				return control
	return null

func _find_focusable_in_node(root: Node) -> Control:
	if root == null:
		return null
	var queue: Array = [root]
	while queue.size() > 0:
		var node = queue.pop_front()
		for child in node.get_children():
			queue.append(child)
		if node is Control:
			var control = node as Control
			if _is_focusable_control(control):
				return control
	return null

func _find_focusables_in_node(root: Node) -> Array:
	var results: Array = []
	if root == null:
		return results
	var queue: Array = [root]
	while queue.size() > 0:
		var node = queue.pop_front()
		for child in node.get_children():
			queue.append(child)
		if node is Control:
			var control = node as Control
			if _is_focusable_control(control):
				results.append(control)
	return results

func _is_focus_path_valid(from: Control, path: NodePath) -> bool:
	if from == null or path == NodePath():
		return false
	return from.get_node_or_null(path) != null

func _resolve_focus_target(from: Control, path: NodePath) -> Control:
	if from == null or path == NodePath():
		return null
	var node = from.get_node_or_null(path)
	return node if node is Control else null

func _is_control_in_container(control: Control, container: Node) -> bool:
	if control == null or container == null:
		return false
	return container == control or container.is_a_parent_of(control)

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

func _fix_shop_focus_links() -> void:
	if RunData == null:
		return
	var player_count = RunData.get_player_count()
	for player_index in range(player_count):
		var shop_container = _get_shop_items_container(player_index)
		var gear_container = _get_gear_container(player_index)
		var player_container = _get_coop_player_container(player_index)
		if shop_container == null or gear_container == null:
			continue
		var shop_focusables = _find_focusables_in_node(shop_container)
		var gear_focusables = _find_focusables_in_node(gear_container)
		if shop_focusables.empty():
			var shop_rect = _get_control_rect(shop_container)
			var shop_targets = _find_focusables_in_rect(self, shop_rect, player_container)
			var reroll_button = _find_focusable_control_by_name(["reroll", "refresh"])
			if reroll_button != null:
				var min_y = _get_min_y(gear_focusables)
				for gear_control in gear_focusables:
					if not _is_top_row(gear_control, min_y):
						continue
					var up_path = gear_control.get_focus_neighbour(1)
					var up_target = _resolve_focus_target(gear_control, up_path)
					if up_path == NodePath() or up_target == null or not _is_focusable_control(up_target):
						if shop_targets.size() > 0:
							shop_targets.sort_custom(self, "_compare_focusable_index")
							_safe_set_focus_neighbour(gear_control, 1, shop_targets[shop_targets.size() - 1])
						else:
							_safe_set_focus_neighbour(gear_control, 1, reroll_button)
					elif not _is_control_in_container(up_target, player_container) and not _is_control_in_container(up_target, shop_container):
						if shop_targets.size() > 0:
							shop_targets.sort_custom(self, "_compare_focusable_index")
							_safe_set_focus_neighbour(gear_control, 1, shop_targets[shop_targets.size() - 1])
						else:
							_safe_set_focus_neighbour(gear_control, 1, reroll_button)
			continue
		var gear_focusable = _find_focusable_in_node(gear_container)
		if gear_focusable == null:
			continue
		var _shop_first = shop_focusables[0]
		var shop_last = shop_focusables[shop_focusables.size() - 1]
		if shop_focusables.size() == 1:
			var only_item = shop_focusables[0]
			var down_path = only_item.get_focus_neighbour(3)
			if down_path == NodePath() or not _is_focus_path_valid(only_item, down_path):
				_safe_set_focus_neighbour(only_item, 3, gear_focusable)
			var up_path = gear_focusable.get_focus_neighbour(1)
			if up_path == NodePath() or not _is_focus_path_valid(gear_focusable, up_path):
				_safe_set_focus_neighbour(gear_focusable, 1, only_item)
		elif shop_focusables.size() > 1:
			shop_focusables.sort_custom(self, "_compare_focusable_index")
			_shop_first = shop_focusables[0]
			shop_last = shop_focusables[shop_focusables.size() - 1]
			for i in range(shop_focusables.size()):
				var current = shop_focusables[i]
				var expected_up = shop_focusables[i - 1] if i > 0 else null
				var expected_down = shop_focusables[i + 1] if i < shop_focusables.size() - 1 else null
				var up_path = current.get_focus_neighbour(1)
				var up_target = _resolve_focus_target(current, up_path)
				if expected_up != null:
					if up_path == NodePath() or not _is_control_in_container(up_target, shop_container):
						_safe_set_focus_neighbour(current, 1, expected_up)
				var down_path = current.get_focus_neighbour(3)
				var down_target = _resolve_focus_target(current, down_path)
				if expected_down != null:
					if down_path == NodePath() or not _is_control_in_container(down_target, shop_container):
						_safe_set_focus_neighbour(current, 3, expected_down)
				else:
					if down_path == NodePath() or not _is_focus_path_valid(current, down_path):
						_safe_set_focus_neighbour(current, 3, gear_focusable)
			var gear_up_path = gear_focusable.get_focus_neighbour(1)
			var gear_up_target = _resolve_focus_target(gear_focusable, gear_up_path)
			if gear_up_path == NodePath() or not _is_control_in_container(gear_up_target, shop_container):
				_safe_set_focus_neighbour(gear_focusable, 1, shop_last)

		var has_weapons = RunData.get_player_weapons(player_index).size() > 0 if RunData != null else true
		if not has_weapons:
			var bottom_root = gear_container if gear_container != null else player_container
			if bottom_root == null:
				continue
			var bottom_focusables: Array = []
			var player_focusables = _find_focusables_in_node(bottom_root)
			for control in player_focusables:
				if _is_control_in_container(control, shop_container):
					continue
				bottom_focusables.append(control)
			if bottom_focusables.size() == 0:
				continue
			var min_y = _get_min_y(bottom_focusables)
			var top_row: Array = []
			for current in bottom_focusables:
				if _is_top_row(current, min_y):
					top_row.append(current)
			if top_row.size() == 0:
				continue
			var shop_rect = _get_control_rect(shop_container)
			var shop_targets = _find_focusables_in_rect(self, shop_rect, player_container)
			if shop_targets.size() > 0:
				shop_targets.sort_custom(self, "_compare_focusable_index")
			var reroll_button = _find_focusable_control_by_name(["reroll", "refresh"])
			var reference_target: Control = null
			for current in top_row:
				var up_target = _resolve_focus_target(current, current.get_focus_neighbour(1))
				if _is_focusable_control(up_target) and not _is_control_in_container(up_target, bottom_root):
					reference_target = up_target
					break
			if reference_target == null and shop_targets.size() > 0:
				reference_target = shop_targets[shop_targets.size() - 1]
			if reference_target == null:
				reference_target = reroll_button
			if reference_target == null:
				continue
			for current in top_row:
				var up_target = _resolve_focus_target(current, current.get_focus_neighbour(1))
				if up_target == null or not _is_focusable_control(up_target) or _is_control_in_container(up_target, bottom_root):
					_safe_set_focus_neighbour(current, 1, reference_target)

func _compare_focusable_index(a: Control, b: Control) -> bool:
	if a == null or b == null:
		return false
	return a.get_index() < b.get_index()

func _get_min_y(controls: Array) -> float:
	var min_y = INF
	for control in controls:
		if control == null:
			continue
		min_y = min(min_y, control.rect_global_position.y)
	return min_y

func _is_top_row(control: Control, min_y: float) -> bool:
	if control == null:
		return false
	return abs(control.rect_global_position.y - min_y) <= 2.0

func _get_control_rect(control: Control) -> Rect2:
	if control == null:
		return Rect2()
	return Rect2(control.rect_global_position, control.rect_size)

func _find_focusables_in_rect(root: Node, rect: Rect2, exclude_container: Node) -> Array:
	var results: Array = []
	if root == null:
		return results
	var queue: Array = [root]
	while queue.size() > 0:
		var node = queue.pop_front()
		for child in node.get_children():
			queue.append(child)
		if node is Control:
			var control = node as Control
			if _is_control_in_container(control, exclude_container):
				continue
			if not _is_focusable_control(control):
				continue
			var control_rect = _get_control_rect(control)
			if rect.intersects(control_rect):
				results.append(control)
	return results


func _is_focusable_control(control: Control) -> bool:
	return control != null and control.is_visible_in_tree() and control.focus_mode != FOCUS_NONE

func _is_visible_control(control: Control) -> bool:
	return control != null and control.is_visible_in_tree()

func _normalize_setting_name(setting_name: String) -> String:
	return _SETTING_NAME_ALIASES[setting_name] if _SETTING_NAME_ALIASES.has(setting_name) else setting_name

func on_config_changed(setting_name:String, value, mod_name):
	if mod_name != TRADE_MOD_ID:
		return
	setting_name = _normalize_setting_name(setting_name)
	var config = ModLoaderConfig.get_current_config(TRADE_MOD_ID)

	if setting_name == trade_items_over_limit_config:
		is_trade_items_over_limit = bool(value)
		if config != null:
			config.data[trade_items_over_limit_config] = is_trade_items_over_limit
	elif setting_name == trade_fee_enabled_config:
		is_trade_fee_enabled = bool(value)
		if config != null:
			config.data[trade_fee_enabled_config] = is_trade_fee_enabled
	elif setting_name == trade_money_enabled_config:
		is_trade_money_enabled = bool(value)
		if config != null:
			config.data[trade_money_enabled_config] = is_trade_money_enabled
	elif setting_name == trade_sell_enabled_config:
		is_trade_sell_enabled = bool(value)
		if config != null:
			config.data[trade_sell_enabled_config] = is_trade_sell_enabled

func _get_config_flag(setting_name: String, default_value: bool) -> bool:
	if coop_trading_config != null and coop_trading_config.data is Dictionary and setting_name in coop_trading_config.data:
		return bool(coop_trading_config.data[setting_name])
	return default_value

func _load_trade_config() -> void:
	coop_trading_config = ModLoaderConfig.get_current_config(TRADE_MOD_ID)
	if coop_trading_config == null:
		coop_trading_config = ModLoaderConfig.get_default_config(TRADE_MOD_ID)
	is_trade_items_over_limit = _get_config_flag(trade_items_over_limit_config, true)
	is_trade_fee_enabled = _get_config_flag(trade_fee_enabled_config, true)
	is_trade_money_enabled = _get_config_flag(trade_money_enabled_config, true)
	is_trade_sell_enabled = _get_config_flag(trade_sell_enabled_config, true)

func on_weapon_trade_button_pressed_coop(weapon_data: WeaponData, from_player_index: int = 0, to_player_index: int = 1) -> void:
	_load_trade_config()
	if !_can_weapon_be_bought(weapon_data, to_player_index):
		SoundManager.play(Utils.get_rand_element(Player.new().hurt_sounds), 0, 0.0, true)
		return

	if is_trade_fee_enabled:
		if !_try_pay_trade_fee(weapon_data, from_player_index, to_player_index):
			SoundManager.play(Utils.get_rand_element(Player.new().hurt_sounds), 0, 0.0, true)
			return
	
	process_player_weapons_inventory(weapon_data, from_player_index)
	.buy_weapon(weapon_data, to_player_index)
	_refresh_player_after_inventory_change(to_player_index)
	
	SoundManager.play(Utils.get_rand_element(recycle_sounds), 0, 0.1, true)

func on_item_trade_button_pressed_coop(item_data: ItemData, from_player_index: int = 0, to_player_index: int = 1) -> void:
	_load_trade_config()
	
	if !is_can_trade_item(item_data, to_player_index):
		SoundManager.play(Utils.get_rand_element(Player.new().hurt_sounds), 0, 0.0, true)
		return

	if is_trade_fee_enabled:
		if !_try_pay_trade_fee(item_data, from_player_index, to_player_index):
			SoundManager.play(Utils.get_rand_element(Player.new().hurt_sounds), 0, 0.0, true)
			return
	
	process_player_items_inventory(item_data, from_player_index)
	.buy_item(item_data, to_player_index)
	_refresh_player_after_inventory_change(to_player_index)
	
	SoundManager.play(Utils.get_rand_element(recycle_sounds), 0, 0.1, true)

func on_item_sell_button_pressed_coop(item_data: ItemData, from_player_index: int) -> void:
	_load_trade_config()
	if not is_trade_sell_enabled:
		return
	if item_data == null:
		return
	process_player_item_sell_inventory(item_data, from_player_index)
	SoundManager.play(Utils.get_rand_element(recycle_sounds), 0, 0.1, true)

func on_money_trade_button_pressed(amount: int, from_player_index: int, to_player_index: int) -> void:
	_load_trade_config()
	if !is_trade_money_enabled:
		return
	if amount <= 0:
		return
	if !_has_player_gold(from_player_index, amount):
		SoundManager.play(Utils.get_rand_element(Player.new().hurt_sounds), 0, 0.0, true)
		return
	_apply_player_gold(from_player_index, -amount)
	_apply_player_gold(to_player_index, amount)
	_refresh_player_after_gold_change(from_player_index)
	_refresh_player_after_gold_change(to_player_index)
	SoundManager.play(Utils.get_rand_element(recycle_sounds), 0, 0.1, true)

# Blatantly copied from the original game code.
func _can_weapon_be_bought(weapon_data: WeaponData, player_index: int)->bool:
	var min_weapon_tier = RunData.get_player_effect(Keys.min_weapon_tier_hash, player_index)
	var max_weapon_tier = RunData.get_player_effect(Keys.max_weapon_tier_hash, player_index)
	var no_melee_weapons = RunData.get_player_effect_bool(Keys.no_melee_weapons_hash, player_index)
	var no_ranged_weapons = RunData.get_player_effect_bool(Keys.no_ranged_weapons_hash, player_index)
	var no_duplicate_weapons = RunData.get_player_effect_bool(Keys.no_duplicate_weapons_hash, player_index)
	var lock_current_weapons = RunData.get_player_effect_bool(Keys.lock_current_weapons_hash, player_index)

	var weapon_type: = weapon_data.type
	var weapons = RunData.get_player_weapons_ref(player_index)
	var weapon_slot_available: bool = RunData.has_weapon_slot_available(weapon_data, player_index)

	var player_has_weapon = false
	for weapon in weapons:
		if weapon.my_id == weapon_data.my_id:
			player_has_weapon = true
			break

	var player_has_weapon_family = false
	if weapon_data.weapon_id in RunData.get_unique_weapon_ids(player_index):
		player_has_weapon_family = true

	if weapon_data.tier > max_weapon_tier or weapon_data.tier < min_weapon_tier:
		return false

	if no_melee_weapons and weapon_type == WeaponType.MELEE:
		return false

	if no_ranged_weapons and weapon_type == WeaponType.RANGED:
		return false

	if lock_current_weapons and not weapon_slot_available:
		return false

	if player_has_weapon and not weapon_slot_available and weapon_data.upgrades_into != null and weapon_data.upgrades_into.tier <= max_weapon_tier:
		return true

	if no_duplicate_weapons and player_has_weapon_family:
		return false

	return weapon_slot_available

func is_can_trade_item(object_data, player_index: int) -> bool:
	if is_trade_items_over_limit:
		return true
	
	if object_data is ItemData:
		return RunData.get_remaining_max_nb_item(object_data, player_index) > 0
	else:
		return false

func _get_item_id_hash(item_data: ItemParentData) -> int:
	if item_data == null:
		return Keys.empty_hash
	var item_id_hash = item_data.get("my_id_hash")
	return item_id_hash if item_id_hash is int else Keys.empty_hash

func _get_trade_fee(item_data: ItemParentData, player_index: int) -> int:
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

func _try_pay_trade_fee(item_data: ItemParentData, from_player_index: int, _to_player_index: int) -> bool:
	var fee_from = _get_trade_fee(item_data, from_player_index)
	if !_has_player_gold(from_player_index, fee_from):
		return false
	_apply_player_gold(from_player_index, -fee_from)
	_update_stats(from_player_index)
	return true

func _has_player_gold(player_index: int, amount: int) -> bool:
	if amount <= 0:
		return true
	var gold = _get_player_gold(player_index)
	return gold >= amount

func _apply_player_gold(player_index: int, delta: int) -> void:
	if delta == 0:
		return
	if _apply_player_gold_via_run_data(player_index, delta):
		return
	if RunData.players_data == null:
		return
	if player_index < 0 or player_index >= RunData.players_data.size():
		return
	var player_data = RunData.players_data[player_index]
	if player_data == null:
		return
	player_data.gold += delta
	if RunData.has_signal("gold_changed"):
		RunData.emit_signal("gold_changed", player_data.gold, player_index)

func _get_player_gold(player_index: int) -> int:
	var gold = _get_player_gold_via_run_data(player_index)
	if gold >= 0:
		return gold
	if RunData.players_data == null:
		return 0
	if player_index < 0 or player_index >= RunData.players_data.size():
		return 0
	var player_data = RunData.players_data[player_index]
	if player_data == null:
		return 0
	return player_data.gold

func _get_player_gold_via_run_data(player_index: int) -> int:
	var method_names = [
		"get_player_gold",
		"get_player_materials",
		"get_gold",
		"get_materials"
	]
	for method_name in method_names:
		if RunData.has_method(method_name):
			var argc = _get_method_argc(RunData, method_name)
			if argc == 1:
				return int(RunData.call(method_name, player_index))
			if argc == 0:
				return int(RunData.call(method_name))
	return -1

func _apply_player_gold_via_run_data(player_index: int, delta: int) -> bool:
	if delta == 0:
		return true
	var amount = abs(delta)
	var method_calls = []
	if delta > 0:
		method_calls = [
			["add_player_gold", delta],
			["add_player_materials", delta],
			["add_gold", delta],
			["add_materials", delta]
		]
	else:
		method_calls = [
			["remove_player_gold", amount],
			["remove_player_materials", amount],
			["remove_gold", amount],
			["remove_materials", amount],
			["add_player_gold", delta],
			["add_player_materials", delta],
			["add_gold", delta],
			["add_materials", delta]
		]
	for call_data in method_calls:
		var method_name = call_data[0]
		var value = call_data[1]
		if RunData.has_method(method_name):
			var argc = _get_method_argc(RunData, method_name)
			if argc == 2:
				RunData.call(method_name, value, player_index)
				return true
			if argc == 1:
				RunData.call(method_name, value)
				return true
	return false

func _get_method_argc(obj: Object, method_name: String) -> int:
	for method_info in obj.get_method_list():
		if method_info.has("name") and method_info["name"] == method_name:
			if method_info.has("args"):
				return method_info["args"].size()
	return -1

func _refresh_player_after_inventory_change(player_index: int) -> void:
	_update_stats(player_index)
	var shop_items_container = _get_shop_items_container(player_index)
	if shop_items_container != null:
		shop_items_container.reload_shop_items()
	var reroll_button = _get_reroll_button(player_index)
	if reroll_button != null:
		reroll_button.set_color_from_currency(_get_player_gold(player_index))

func _refresh_player_after_gold_change(player_index: int) -> void:
	_update_stats(player_index)
	var shop_items_container = _get_shop_items_container(player_index)
	if shop_items_container != null:
		shop_items_container.update_buttons_color()
	var reroll_button = _get_reroll_button(player_index)
	if reroll_button != null:
		reroll_button.set_color_from_currency(_get_player_gold(player_index))

func process_player_items_inventory(item_data: ItemData, player_index: int):
	_popup_manager.reset_focus(player_index)
	RunData.remove_item(item_data, player_index, false)
	_refresh_player_after_inventory_change(player_index)
	_get_coop_player_container(player_index).on_hide_focused_inventory_popup()
	var player_gear_container = _get_gear_container(player_index)
	var player_items: Array = RunData.get_player_items(player_index)
	player_gear_container.set_items_data(player_items)
	player_gear_container.items_container.focus_element_index(0)

func process_player_item_sell_inventory(item_data: ItemData, player_index: int) -> void:
	_popup_manager.reset_focus(player_index)
	RunData.remove_item(item_data, player_index, false)
	_apply_player_gold(player_index, sell_item_price)
	_refresh_player_after_inventory_change(player_index)
	_get_coop_player_container(player_index).on_hide_focused_inventory_popup()
	var player_gear_container = _get_gear_container(player_index)
	var player_items: Array = RunData.get_player_items(player_index)
	player_gear_container.set_items_data(player_items)
	player_gear_container.items_container.focus_element_index(0)

func process_player_weapons_inventory(weapon_data: WeaponData, player_index: int):
	_popup_manager.reset_focus(player_index)
	RunData.remove_weapon(weapon_data, player_index)
	_refresh_player_after_inventory_change(player_index)
	_get_coop_player_container(player_index).on_hide_focused_inventory_popup()
	var player_gear_container = _get_gear_container(player_index)
	var player_weapons: Array = RunData.get_player_weapons(player_index)
	player_gear_container.set_weapons_data(player_weapons)
	player_gear_container.items_container.focus_element_index(0)
