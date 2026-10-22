class_name SaveManager
extends RefCounted

const SAVE_VERSION := 2
const CONTENT_ID := "shuwei-pinball"
static var save_path := "user://progress.json"

static func empty_progress() -> Dictionary:
	return {"version": SAVE_VERSION, "content_id": CONTENT_ID, "completed_levels": {}}

static func migrate(source: Variant) -> Dictionary:
	if not source is Dictionary or source.get("content_id") != CONTENT_ID or not source.get("completed_levels") is Dictionary:
		return empty_progress()
	var version := int(source.get("version", 0))
	if version < 1 or version > SAVE_VERSION:
		return empty_progress()
	var result := empty_progress()
	for id in source.completed_levels:
		var row = source.completed_levels[id]
		if not row is Dictionary or not row.get("completed", false):
			continue
		var time = row.get("best_time", -1)
		var count = row.get("best_formula_count", row.get("min_formulas", 0))
		if not (time is float or time is int) or not is_finite(float(time)) or time < 0 or not (count is float or count is int) or count < 1 or count > 3:
			continue
		result.completed_levels[id] = {"completed": true, "best_time": float(time), "best_formula_count": int(count)}
	return result

static func load_progress() -> Dictionary:
	if not FileAccess.file_exists(save_path):
		return empty_progress()
	return migrate(JSON.parse_string(FileAccess.get_file_as_string(save_path)))

static func mark_level_completed(level_id: String, elapsed_time: float, formula_count: int) -> bool:
	if level_id.is_empty() or not is_finite(elapsed_time) or elapsed_time < 0 or formula_count < 1 or formula_count > 3:
		return false
	# Preserve newer saves for a newer executable instead of overwriting them.
	if FileAccess.file_exists(save_path):
		var existing = JSON.parse_string(FileAccess.get_file_as_string(save_path))
		if existing is Dictionary and existing.get("content_id") == CONTENT_ID and int(existing.get("version", 0)) > SAVE_VERSION:
			return false
	var progress := load_progress()
	var previous: Dictionary = progress.completed_levels.get(level_id, {})
	progress.completed_levels[level_id] = {"completed": true,
		"best_time": minf(float(previous.get("best_time", elapsed_time)), elapsed_time),
		"best_formula_count": mini(int(previous.get("best_formula_count", formula_count)), formula_count)}
	var temporary := save_path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(progress, "  "))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		return false
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(save_path)) == OK
