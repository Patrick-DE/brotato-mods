extends Node

const AUTHORNAME_MODNAME_LOG_NAME := "lionmaster-SkipWaitingTimes:Main" # Full ID of the mod (AuthorName-ModName)


func _ready():
	ModLoaderLog.info("Init", AUTHORNAME_MODNAME_LOG_NAME)
	
	VisualServer.force_draw()
	VisualServer.render_loop_enabled = false
	
	# Have to wait just a liiiiiittle bit longer, in case of mods.
	ProgressData.connect("ready", self, "_on_progress_data_ready")


func _on_progress_data_ready() -> void:
	yield(get_tree().create_timer(0.2), "timeout")
	ProgressData.apply_settings()
	VisualServer.render_loop_enabled = true
	get_tree().change_scene("res://ui/menus/title_screen/title_screen.tscn")
