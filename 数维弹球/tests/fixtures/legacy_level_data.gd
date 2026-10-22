class_name LegacyLevelData
extends RefCounted

static func all_levels() -> Array:
	return [_straight_level(), _bounce_level(), _relay_level()]

static func get_level(index: int) -> Dictionary:
	var levels := all_levels()
	return levels[clampi(index, 0, levels.size() - 1)].duplicate(true)

static func validate(level: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	for field in ["id", "title", "boundary", "start", "goal", "allowed_types", "formulas"]:
		if not level.has(field):
			errors.append("关卡缺少字段: %s" % field)
	var boundary: PackedVector2Array = level.get("boundary", PackedVector2Array())
	if boundary.size() < 3:
		errors.append("关卡边框至少需要 3 个点")
	if float(level.get("time_limit", 0.0)) <= 0.0:
		errors.append("关卡限时必须大于 0")
	var formula_result := FormulaValidator.validate(level.get("formulas", []), level)
	errors.append_array(formula_result["errors"])
	return {"ok": errors.is_empty(), "errors": errors}

static func _common() -> Dictionary:
	return {
		"boundary": PackedVector2Array([
			Vector2(-8.9, -4.8), Vector2(8.9, -4.8),
			Vector2(8.9, 4.8), Vector2(-8.9, 4.8),
		]),
		"parameter_limits": {
			"a": Vector2(-1.2, 1.2),
			"b": Vector2(-5.0, 5.0),
			"c": Vector2(-20.0, 20.0),
		},
		"hazards": [],
		"checkpoints": [],
		"max_functions": 3,
	}

static func _straight_level() -> Dictionary:
	var level := _common()
	level.merge({
		"id": "straight",
		"number": "01",
		"title": "直线入门",
		"subtitle": "调整斜率，让球抵达终点",
		"hint": "一次函数没有弹性。调整 a 或 b，让轨道把球送进终点。",
		"time_limit": 14.0,
		"start": {"position": Vector2(-7.35, 4.242), "velocity": Vector2.ZERO},
		"goal": {"position": Vector2(6.15, -1.72), "radius": 0.78},
		"allowed_types": [GameConstants.MODULE_LINE],
		"max_functions": 2,
		"formulas": [FormulaModel.create_line("line-a", -0.42, 0.8, -8.6, 8.5)],
	}, true)
	return level

static func _bounce_level() -> Dictionary:
	var level := _common()
	level.merge({
		"id": "bounce",
		"number": "02",
		"title": "弹性一次",
		"subtitle": "借助二次曲线改变落点",
		"hint": "让黄色弹性曲线接住下落的小球，并把它弹向右侧终点。",
		"time_limit": 12.0,
		"start": {"position": Vector2(-7.5, 4.5), "velocity": Vector2.ZERO},
		"goal": {"position": Vector2(2.8, 0.4), "radius": 0.9},
		"allowed_types": [GameConstants.MODULE_QUADRATIC],
		"max_functions": 2,
		"bounce_boost": Vector2(4.45, 2.85),
		"limited_bounce": true,
		"formulas": [FormulaModel.create_quadratic("quad-a", -0.25, -4.5, -16.65, -9.2, -4.8)],
	}, true)
	return level

static func _relay_level() -> Dictionary:
	var level := _common()
	level.merge({
		"id": "relay",
		"number": "03",
		"title": "双轨接力",
		"subtitle": "普通轨道接上弹性轨道",
		"hint": "先用直线引导，再用二次函数反弹，按顺序经过检查点和终点。",
		"boundary": PackedVector2Array([
			Vector2(-9.0, -4.8), Vector2(8.6, -4.8), Vector2(9.1, 2.7),
			Vector2(7.5, 4.9), Vector2(-8.5, 4.9),
		]),
		"time_limit": 16.0,
		"start": {"position": Vector2(-7.7, 4.335), "velocity": Vector2.ZERO},
		"goal": {"position": Vector2(6.35, 0.18), "radius": 0.88},
		"checkpoints": [{"position": Vector2(4.15, 3.4), "radius": 0.56}],
		"hazards": [{"position": Vector2(0.3, -3.45), "radius": 1.25, "label": "危险区"}],
		"allowed_types": [GameConstants.MODULE_LINE, GameConstants.MODULE_QUADRATIC],
		"max_functions": 3,
		"formulas": [
			FormulaModel.create_line("line-b", -0.4, 0.9, -8.6, 0.2),
			FormulaModel.create_quadratic("quad-b", -0.36, 0.72, 1.15, -1.2, 4.4),
		],
	}, true)
	return level
