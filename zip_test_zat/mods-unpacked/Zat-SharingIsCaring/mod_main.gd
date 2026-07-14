extends Node

const MOD_ID = "Zat-SharingIsCaring"
const MYMODNAME_MOD_DIR = "Zat-SharingIsCaring/"
const MYMODNAME_LOG = "Zat-SharingIsCaring"

var dir = ""
var ext_dir = ""
var trans_dir = ""


func _init():
	ModLoaderLog.info("Init", MYMODNAME_LOG)
	dir = ModLoaderMod.get_unpacked_dir() + MYMODNAME_MOD_DIR
	ext_dir = dir + "extensions/"
	trans_dir = dir + "translations/"
	
	# Add extensions
	ModLoaderMod.install_script_extension(ext_dir + "ui/menus/shop/base_shop.gd")
	
	# Add translations
	ModLoaderMod.add_translation(trans_dir + "SharingIsCaring.en.translation")
	
	
func _ready():
	ModLoaderLog.info("Done", MYMODNAME_LOG)
	_config()
	
	
func _config()-> void:
	var data = ModLoaderStore.mod_data[MOD_ID]
	if data != null:
		var version = data.manifest.version_number
		ModLoaderLog.info("Current Version is %s." % version, MOD_ID)
		var config = ModLoaderConfig.get_config(MOD_ID, version)
		if config == null:
			var defaultConfig = ModLoaderConfig.get_default_config(MOD_ID)
			if defaultConfig != null:
				config = ModLoaderConfig.create_config(MOD_ID, version, defaultConfig.data)
			else:
				config = ModLoaderConfig.create_config(MOD_ID, version, {})
			
		if config != null and ModLoaderConfig.get_current_config_name(MOD_ID) != version:
			ModLoaderConfig.set_current_config(config)
			if config.is_valid():
				config.save_to_file()
				ModLoaderLog.info("Save config to : %s" % config.save_path, MOD_ID)
	
	var ModsConfigInterface = get_node("/root/ModLoader/dami-ModOptions/ModsConfigInterface")
	if ModsConfigInterface != null:
		ModLoaderLog.info("Connect setting_changed", MOD_ID)
		ModsConfigInterface.connect("setting_changed", self, "setting_changed")
	else:
		ModLoaderLog.info("ModsConfigInterface is null", MOD_ID)
	
	
func setting_changed(setting_name, value, _mod_nammod_namee)->void:
	var config = ModLoaderConfig.get_current_config(MOD_ID)
	if config != null:
		config.data[setting_name] = value;
		config.save_to_file()
