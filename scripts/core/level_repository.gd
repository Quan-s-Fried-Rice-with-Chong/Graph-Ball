extends RefCounted
const Catalog = preload("res://scripts/core/formula_catalog.gd")

static func numeric(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))

static func vector_data(value: Variant, count: int) -> bool:
	if not value is Array or value.size() != count:
		return false
	for entry in value:
		if not numeric(entry) or absf(float(entry)) > 1000:
			return false
	return true

static func validate_document(document: Variant) -> Array[String]:
	var errors: Array[String] = []
	if not document is Dictionary or document.get("schema_version") != 1 or not document.get("levels") is Array or document.levels.is_empty():
		return ["关卡文件结构或版本无效"]
	var ids: Array = []
	for data in document.levels:
		if not data is Dictionary:
			errors.append("关卡必须是对象")
			continue
		if not data.get("id") is String or data.id.is_empty() or ids.has(data.id):
			errors.append("关卡 ID 为空或重复")
		ids.append(data.get("id"))
		for key in ["title", "objective", "hint"]:
			if not data.get(key) is String:
				errors.append("缺少关卡文本 %s" % key)
		if data.has("concept") and not data.concept is String:
			errors.append("concept 必须是文本")
		if not vector_data(data.get("bounds"), 4):
			errors.append("bounds 必须是四个有限数值")
			continue
		var b: Array = data.bounds
		if b[2] <= 0 or b[3] <= 0 or b[2] > 100 or b[3] > 100:
			errors.append("作图区尺寸无效")
		var bounds := Rect2(b[0], b[1], b[2], b[3])
		for key in ["start", "goal"]:
			if not vector_data(data.get(key), 2) or not bounds.has_point(Vector2(data[key][0], data[key][1])):
				errors.append("起终点必须在作图区内")
		for key in ["goal_radius", "checkpoint_radius", "time_limit", "ball_radius"]:
			if not numeric(data.get(key)) or float(data[key]) <= 0:
				errors.append("无效数值 %s" % key)
		if data.get("ball_radius") != GameConstants.BALL_RADIUS:
			errors.append("正式关卡球半径固定为 0.28")
		var max_functions = data.get("max_formulas", 3)
		if not numeric(max_functions) or int(max_functions) != float(max_functions) or int(max_functions) < 1 or int(max_functions) > 3:
			errors.append("函数数量上限应为 1 到 3")
		if not data.get("templates") is Array or data.templates.is_empty():
			errors.append("缺少函数模板白名单")
			continue
		for template_id in data.templates:
			if not Catalog.TEMPLATES.has(template_id):
				errors.append("未知函数模板")
		if data.has("template_defaults"):
			if not data.template_defaults is Dictionary:
				errors.append("template_defaults 必须是对象")
			else:
				for template_id in data.template_defaults:
					if not data.templates.has(template_id):
						errors.append("默认参数使用了未知函数模板")
					elif not data.template_defaults[template_id] is Dictionary or not Catalog.validate(template_id, data.template_defaults[template_id]).is_empty():
						errors.append("函数默认参数无效")
		if data.has("tutorial"):
			if not data.tutorial is Dictionary:
				errors.append("tutorial 必须是对象")
			else:
				var features = data.tutorial.get("features", {})
				if not features is Dictionary:
					errors.append("tutorial.features 必须是对象")
				else:
					for key in ["add_formula", "template_picker"]:
						if features.has(key) and not features[key] is bool:
							errors.append("tutorial.features.%s 必须是布尔值" % key)
				var steps = data.tutorial.get("steps", [])
				if not steps is Array or steps.is_empty():
					errors.append("tutorial.steps 不能为空")
				else:
					var targets := ["formula_list", "formula_card", "formula_card_2", "formula_expand", "formula_parameters", "formula_parameters_2", "formula_domain", "formula_domain_2", "formula_picker", "add_formula", "run_button", "graph", "obstacle", "formula_stat"]
					var actions := ["next", "expand", "parameter_change", "parameter_change_2", "domain_change", "domain_change_2", "formula_added", "template_quadratic", "run"]
					for step in steps:
						if not step is Dictionary or not step.get("target") is String or not step.get("title") is String or not step.get("text") is String:
							errors.append("教程步骤格式错误")
							continue
						if not targets.has(step.target):
							errors.append("未知教程目标 %s" % step.target)
						if not actions.has(step.get("advance", "next")):
							errors.append("未知教程推进方式 %s" % step.get("advance", "next"))
		for key in ["checkpoints", "obstacles", "circle_hazards"]:
			if not data.get(key, []) is Array:
				errors.append("%s 必须是数组" % key)
				continue
			for entry in data.get(key, []):
				var count := 2 if key == "checkpoints" else (4 if key == "obstacles" else 3)
				if not vector_data(entry, count):
					errors.append("%s 坐标格式错误" % key)
				elif key == "checkpoints" and not bounds.has_point(Vector2(entry[0], entry[1])):
					errors.append("检查点在作图区外")
				elif (count == 4 and (entry[2] <= 0 or entry[3] <= 0)) or (count == 3 and entry[2] <= 0):
					errors.append("危险区尺寸无效")
		for key in ["initial_formulas", "reference_formulas"]:
			if not data.get(key) is Array or data[key].is_empty() or data[key].size() > 3:
				errors.append("%s 数量无效" % key)
				continue
			for formula in data[key]:
				if not formula is Dictionary or not formula.get("parameters") is Dictionary or not vector_data(formula.get("domain"), 2):
					errors.append("函数格式错误")
					continue
				if not data.templates.has(formula.get("template")) or not Catalog.validate(formula.get("template", ""), formula.parameters).is_empty():
					errors.append("函数参数不符合模板范围")
				if not Catalog.validate_domain(Vector2(formula.domain[0], formula.domain[1]), bounds).is_empty():
					errors.append("函数定义域无效")
	return errors

static func load_levels() -> Array:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels.json"))
	var errors := validate_document(parsed)
	if not errors.is_empty():
		push_error("关卡文件验证失败：%s" % str(errors))
		return []
	var levels: Array = []
	for raw in parsed.levels:
		var data: Dictionary = raw.duplicate(true)
		var b: Array = data.bounds
		data.bounds = Rect2(b[0], b[1], b[2], b[3])
		data.start = Vector2(data.start[0], data.start[1])
		data.goal = Vector2(data.goal[0], data.goal[1])
		var checkpoints: Array = []
		for p in data.get("checkpoints", []):
			checkpoints.append(Vector2(p[0], p[1]))
		data.checkpoints = checkpoints
		var obstacles: Array = []
		for r in data.get("obstacles", []):
			obstacles.append(Rect2(r[0], r[1], r[2], r[3]))
		data.obstacles = obstacles
		for key in ["initial_formulas", "reference_formulas"]:
			for f in data[key]:
				f.domain = Vector2(f.domain[0], f.domain[1])
		if data.has("template_defaults"):
			for template_id in data.template_defaults:
				data.template_defaults[template_id] = data.template_defaults[template_id].duplicate(true)
		data.initial_template = data.initial_formulas[0].template
		data.initial_parameters = {}
		for f in data.initial_formulas:
			data.initial_parameters[f.template] = f.parameters.duplicate(true)
		levels.append(data)
	return levels
