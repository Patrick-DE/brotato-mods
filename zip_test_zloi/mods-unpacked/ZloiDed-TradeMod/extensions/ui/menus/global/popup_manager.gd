extends PopupManager

func _get_player_index_for_control(control: Control) -> int:
	if not RunData.is_coop_run:
		return 0
	var player_index = FocusEmulatorSignal.get_player_index(control)
	if player_index >= 0:
		return player_index
	player_index = _find_player_index_in_ancestors(control)
	return player_index if player_index >= 0 else 0

func _find_player_index_in_ancestors(node: Node) -> int:
	var current = node
	while current != null:
		if current.has_method("get"):
			var value = current.get("player_index")
			if value is int and value >= 0:
				return value
		current = current.get_parent()
	return -1
