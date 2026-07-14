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
- Ensure `"config_schema"` is declared correctly. The root of `config_schema` MUST contain `"type": "object"` and a `"properties"` object.
- Example:
  ```json
  "config_schema": {
      "type": "object",
      "properties": {
          "setting_name": { "type": "number", "default": 1.0 }
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
- Custom assets should be included in the mod's `.import` directory (with names prefixed by the mod name to avoid conflicts).

## References
- Steam Modding Guide: [https://steamcommunity.com/sharedfiles/filedetails/?id=2931079751](https://steamcommunity.com/sharedfiles/filedetails/?id=2931079751)
