extends Reference
# =============================================================================
# SpatialHashGrid - uniform spatial hash for O(n) neighbour queries
# -----------------------------------------------------------------------------
# Pure data structure. Knows nothing about Brotato, fruits, or healing, so it is
# reusable and unit-testable in isolation.
#
# INVARIANT: cell size MUST be >= the query radius. Two points within `radius`
# of each other differ by at most `radius` on each axis, so with cell == radius
# their cell coordinates differ by at most 1. Scanning the 3x3 block of cells
# around a point is therefore guaranteed to contain every point within radius.
# =============================================================================

var _cell_size: float
var _cells: Dictionary = {}   # Vector2 cell-key -> Array of nodes
var _query_result := []       # Reused array for memory efficiency

func _init(cell_size: float) -> void:
	_cell_size = max(cell_size, 1.0)

func clear() -> void:
	_cells.clear()

func insert(node: Object, pos: Vector2) -> void:
	var key := _key(pos)
	if not _cells.has(key):
		_cells[key] = []
	_cells[key].append(node)

# Returns every node in the 3x3 cell block around `pos`. Callers must still do
# the exact radius test - this only narrows the candidate set.
func get_neighbors(pos: Vector2) -> Array:
	_query_result.clear()
	var base := _key(pos)
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var key := base + Vector2(dx, dy)
			if _cells.has(key):
				var cell_nodes = _cells[key]
				for i in range(cell_nodes.size()):
					_query_result.append(cell_nodes[i])
	return _query_result

func _key(pos: Vector2) -> Vector2:
	return Vector2(floor(pos.x / _cell_size), floor(pos.y / _cell_size))
