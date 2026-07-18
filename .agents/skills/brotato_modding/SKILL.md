---
name: brotato_modding
description: Provides guidelines, standards, and workflow steps for modding Brotato using the Godot ModLoader.
---

# Brotato Modding Guidelines

When working on Brotato mods, adhere to the following standards established by the Godot ModLoader and the official Brotato modding guide.

## Directory Structure
Brotato uses Godot ModLoader v6. All mods MUST be located in the `mods-unpacked/` directory.
The mod folder must be named using the format `Author-ModName` (e.g., `Secdude-FruitAggregator`).

```text
mods-unpacked/
└── Author-ModName/
    ├── manifest.json
    ├── mod_main.gd
    ├── scripts/
    └── extensions/
```

## `manifest.json`
Every mod must contain a `manifest.json` file in its root directory.
- ModLoader v6 enforces strict schema validation. You MUST include `"namespace"`, `"config_schema"`, and an `"extra"` block with Godot details. Otherwise, the ModLoader will crash with an `Invalid get index 'extra'` error or refuse to load.
- Ensure `"config_schema"` is declared correctly. The root of `config_schema` MUST contain `"type": "object"` and a `"properties"` object.
- Example:
  ```json
  "config_schema": {
      "type": "object",
      "properties": {
          "setting_name": { "type": "number", "default": 1.0 }
      }
  },
  "extra": {
      "godot": {
          "id": "Author-ModName",
          "authors": ["Author"],
          "compatible_mod_loader_version": ["6.0.0"]
      }
  }
  ```

## `mod_main.gd`
- ModLoader instantiates this file once at startup.
- Its primary job is to register script extensions via `ModLoaderMod.install_script_extension()`.
- Do NOT use this file for heavy game logic.

## Mod Extensions
- Use `ModLoaderMod.install_script_extension("res://mods-unpacked/Author-ModName/extensions/path/to/script.gd")` to override vanilla game logic.
- Extension files MUST `extends "res://path/to/vanilla/script.gd"`.
- Always verify API changes between versions (such as Local Co-op adding `player_index` to pickup functions).

## Packaging for Steam Workshop
To publish a mod, you need to package it as a ZIP file.
- The ZIP file MUST contain the `mods-unpacked/` structure at its root.
- Do NOT zip just the mod contents. Zip the `mods-unpacked` folder so that it unzips directly into the right path.
- **CRITICAL ZIP FORMATTING**: Do NOT use Windows PowerShell's `Compress-Archive` to create the zip file. It injects backslashes (`\`) as path separators inside the zip manifest, which completely breaks Godot's ModLoader when loaded from the Steam Workshop. Always use a tool that creates POSIX paths (forward slashes `/`), such as a Python `zipfile` script or 7-Zip.
- Custom assets should ideally be included in the mod's `.import` directory (with names prefixed by the mod name to avoid conflicts).
- **Loading Raw PNGs:** If you do not import `.png` files in the Godot Editor, Godot 3's `Image.load()` will fail to load them from `res://` paths in the exported game. To safely load unimported PNGs dynamically:
  ```gdscript
  var icon = ImageTexture.new()
  var file = File.new()
  if file.open("res://mods-unpacked/Author-ModName/icon.png", File.READ) == OK:
      var buffer = file.get_buffer(file.get_len())
      var img = Image.new()
      img.load_png_from_buffer(buffer)
      icon.create_from_image(img)
      file.close()
  ```

## ModOptions Integration (Legacy & Modern)
When integrating your mod with community Options menus, be aware of competing frameworks:
- **`Oudstand-ModOptions`**: Can be accessed dynamically. The standard node path is NOT `/root/ModOptions`, but typically `/root/ModLoader/Oudstand-ModOptions/ModOptions`. You should use a `yield(get_tree().create_timer(0.2), "timeout")` retry loop in `_ready()` because it might load after your mod.
- **`dami-ModOptions`**: This is a legacy framework that completely ignores ModLoader v6's official `config_schema`. To support it, you MUST add a `config_defaults` block inside `manifest.json` under `extra.godot`. 
  - To properly format sliders in `dami-ModOptions`, append magic suffixes to the keys inside `config_defaults` (e.g., `setting_name_title`, `setting_name_min`, `setting_name_max`, `setting_name_step`, `setting_name_format`).
  - `dami-ModOptions` does NOT save configurations automatically. You must connect to its `ModsConfigInterface`'s `setting_changed` signal and manually call `config.save_to_file()` in your callback.

## Common Pitfalls & Optimizations
- **Strict Typing Compilation Error (`:=`)**: Godot ModLoader APIs (like `Config.setting_name()`) return generic `Variant` types. Using strict type inference (`var value := Config.setting_name()`) causes Godot to fail compilation with a fatal "type can't be inferred" parse error. This crash causes the ModLoader to panic and disable ALL mods! Always use explicit typing: `var value: float = Config.setting_name()`.
- **Fatal VFS Crash with `preload()`**: When writing script extensions (loaded via `install_script_extension()`), NEVER use `preload("res://mods-unpacked/...")` to load other scripts or resources from your mod. Godot 3's Virtual File System (VFS) resolves `preload` at compile-time. Because ModLoader injects script extensions dynamically at boot, this can lock the VFS, cause a massive cyclic dependency, or result in a fatal C++ engine crash (`Condition "_first != nullptr" is true`) that instantly closes the game. Always use runtime `load("res://mods-unpacked/...")` instead.
- **Garbage Collection Spikes**: Avoid creating new Arrays (`[]`) or Dictionaries (`{}`) inside high-frequency loops (e.g., `_process` or custom timers). Godot's GDScript garbage collector will spike, causing micro-stutters. Use pre-allocated, reused array buffers (`_buffer.clear()`) and use indexed loops (`for i in range(size)`).
- **Node Tracking**: Instead of using internal dictionaries to track if an object was processed/destroyed, utilize Godot's engine-level `is_queued_for_deletion()` for zero-allocation checks.

## Character Visual Design
When designing custom characters, always adhere to the official Brotato visual style to ensure they integrate seamlessly:
- **Base Potato is Required**: Do NOT completely override the character's body with a full sprite that hides the base potato entirely, as this disables the game's dynamic rendering of animated limbs (arms holding weapons and feet walking).
- **Use Individual Appearance Parts**: Break character designs into individual accessories (e.g., eyes, nose, wings, hats). Use `ItemAppearanceData` with `is_character_appearance = true` and assign them to proper positions (e.g., `Position.EYES`, `Position.NOSE`) and `depth` layers so they attach properly to the underlying vanilla white potato body.
- **No Pre-drawn Limbs**: The sprites for your accessories should never have pre-drawn arms, hands, or feet. The game engine dynamically attaches its own animated limbs to the base potato during gameplay.
- **Menu Icon Compositing**: While the in-game model is drawn dynamically layer-by-layer, the character selection menu icon (the small clickable square button in the UI, `_icon.png`) requires a flat, static PNG image. This means you MUST composite your accessory sprites on top of a static white potato base, otherwise the selection button will just show floating accessories without a body. Ensure icons are properly squared, transparent, and standardized to `150x150` pixels.

## References
- Steam Modding Guide: [https://steamcommunity.com/sharedfiles/filedetails/?id=2931079751](https://steamcommunity.com/sharedfiles/filedetails/?id=2931079751)
