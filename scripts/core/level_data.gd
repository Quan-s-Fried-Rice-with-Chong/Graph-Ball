class_name LevelData
extends RefCounted
const Repository = preload("res://scripts/core/level_repository.gd")
const Catalog = preload("res://scripts/core/formula_catalog.gd")

static func from_ui(data: Dictionary) -> Dictionary:
	var b: Rect2 = data.bounds
	var checkpoints: Array = []
	for p in data.checkpoints:
		checkpoints.append({"position": p, "radius": data.checkpoint_radius})
	var hazards: Array = []
	for r in data.obstacles:
		hazards.append({"rect": r})
	for c in data.get("circle_hazards", []):
		hazards.append({"position": Vector2(c[0], c[1]), "radius": c[2]})
	var types: Array = []
	for t in data.templates:
		types.append("line" if t == "linear" else t)
	return {"id": data.id, "title": data.title, "time_limit": data.time_limit,
		"start": {"position": data.start, "velocity": Vector2.ZERO},
		"goal": {"position": data.goal, "radius": data.goal_radius},
		"checkpoints": checkpoints, "hazards": hazards, "allowed_types": types, "max_functions": 3,
		"boundary": PackedVector2Array([b.position, Vector2(b.end.x, b.position.y), b.end, Vector2(b.position.x, b.end.y)]),
		"formulas": Catalog.to_core_list(data.initial_formulas)}

static func all_levels() -> Array:
	var result: Array = []
	for data in Repository.load_levels():
		result.append(from_ui(data))
	return result

static func get_level(index: int) -> Dictionary:
	var levels := all_levels()
	return {} if levels.is_empty() else levels[clampi(index, 0, levels.size() - 1)]

static func validate(level: Dictionary) -> Dictionary:
	var result := FormulaValidator.validate(level.get("formulas", []), level)
	if level.get("boundary", []).size() < 3 or float(level.get("time_limit", 0)) <= 0:
		result.errors.append("关卡边界或时间无效")
	result.ok = result.errors.is_empty()
	return result
