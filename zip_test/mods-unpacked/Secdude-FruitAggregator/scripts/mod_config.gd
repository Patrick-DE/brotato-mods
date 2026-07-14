extends Reference
# =============================================================================
# FruitAggregator - central configuration
# -----------------------------------------------------------------------------
# Single source of truth. Holds ALL tunables AND every point where this mod
# touches vanilla Brotato. Change values here, never scattered across the code.
#
# Anything tagged (VERIFY) is a symbol that is NOT part of a public, stable API.
# Brotato's internal names can change between game versions and are only visible
# in a decompiled project (GDRETools). If a (VERIFY) value is wrong the mod
# fails SAFE - it simply does less (or nothing) instead of crashing the game.
# =============================================================================

# --- Behaviour tunables ------------------------------------------------------
const MERGE_RADIUS: float = 100.0         # px; fruits closer than this may merge
const SCAN_INTERVAL: float = 0.25        # s between merge passes (throttle)
const MIN_FRUITS_TO_MERGE: int = 0      # do nothing until this many fruits exist
const MAX_MERGES_PER_TICK: int = 60      # cap merges per pass to smooth frames
const MAX_MERGE_COUNT: int = 9999        # overflow guard on a fruit's merge count

# REQUIRED true for correct healing under effect-replay: the survivor replays
# ITS OWN heal effect once per merged fruit, so all merged fruits must share a
# type. Turning this off would heal cross-type merges as the survivor's type.
const MERGE_ONLY_SAME_TYPE: bool = true

# --- Effect replay -----------------------------------------------------------
# Preferred, stat-faithful path: name the method on the vanilla consumable that
# applies its effects to the player (find it in your decompiled consumable.gd -
# grep for 'effects' / 'RunData' / 'apply'). It MUST apply effects only and MUST
# NOT free the node. Leave "" to use the raw-heal fallback below.       (VERIFY)
const EFFECT_APPLY_METHOD: String = ""

# --- Fail-safe healing fallback (used only when EFFECT_APPLY_METHOD is "") ----
const FALLBACK_HEAL: int = 3             # base fruit heal in HP (Brotato wiki)
const HEAL_FIELD: String = "value"       # ConsumableData heal field      (VERIFY)
const PLAYER_HEAL_METHOD: String = "heal" # player's heal method name      (VERIFY)

# --- Vanilla coupling --------------------------------------------------------
# MOD_GROUP is OUR group, created by this mod, so it is always safe. EVERY
# consumable adds itself to it in consumable.gd::_ready (unconditionally, because
# consumable_data may not be set yet at _ready time). The aggregator filters to
# mergeable fruits at scan time, when the data is reliably populated.
const MOD_GROUP: String = "secdude_consumables"

# consumable_data ids that are allowed to merge. Keep this to the plain healing
# fruit only - never crates/loot boxes (stacking those would duplicate items).
# Set the real id(s) after inspecting the fruit's ConsumableData resource. While
# this list does not match any fruit the mod is a harmless no-op.        (VERIFY)
const MERGEABLE_TYPE_KEYS: Array = ["consumable_fruit"]
