class_name FormulaValidator
extends RefCounted
const Catalog = preload("res://scripts/core/formula_catalog.gd")

static func validate(formulas: Array, level: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var normalized: Array = []
	var maximum := mini(int(level.get("max_functions", 3)), GameConstants.MAX_FORMULAS)
	if formulas.is_empty() or formulas.size() > maximum:
		errors.append("请配置 1 至 %d 条函数" % maximum)
	for index in formulas.size():
		var raw = formulas[index]
		if not raw is Dictionary or not raw.get("parameters") is Dictionary:
			errors.append("函数数据格式错误")
			continue
		var type: String = raw.get("type", "")
		if not level.get("allowed_types", ["line", "quadratic", "sine"]).has(type):
			errors.append("本关不允许函数类型 %s" % type)
			continue
		var required: Array = {"line": ["a", "b"], "quadratic": ["a", "b", "c"], "sine": ["a", "b", "h", "k"]}.get(type, [])
		if required.is_empty():
			errors.append("未知函数类型")
		for key in required:
			var value = raw.parameters.get(key)
			if not (value is int or value is float) or not is_finite(float(value)) or absf(float(value)) > 10000.0:
				errors.append("第 %d 条函数参数 %s 无效" % [index + 1, key])
		if not raw.get("ui_source", {}) is Dictionary:
			errors.append("界面参数来源格式错误")
			continue
		var ui: Dictionary = raw.get("ui_source", {})
		if not ui.is_empty():
			if not ui.get("parameters") is Dictionary or not ui.get("domain") is Vector2:
				errors.append("界面函数格式错误")
				continue
			var message := Catalog.validate(ui.get("template", ""), ui.get("parameters", {}))
			if not message.is_empty():
				errors.append(message)
			else:
				var expected: Dictionary = Catalog.to_core(ui, index)
				if type != expected.type or raw.parameters != expected.parameters or raw.get("x_range") != expected.x_range:
					errors.append("界面参数与物理参数不一致")
		var raw_domain = raw.get("x_range")
		if not raw_domain is Vector2 and not (raw_domain is Array and raw_domain.size() == 2 and (raw_domain[0] is int or raw_domain[0] is float) and (raw_domain[1] is int or raw_domain[1] is float)):
			errors.append("定义域格式错误")
			continue
		var formula := FormulaModel.normalized(raw)
		var domain: Vector2 = formula.x_range
		if not is_finite(domain.x) or not is_finite(domain.y) or domain.y - domain.x < 0.05:
			errors.append("定义域应按从小到大填写，宽度至少 0.05")
		var bounds := BoundaryClipper.polygon_bounds(level.get("boundary", PackedVector2Array()))
		if bounds.has_area() and (domain.x < bounds.position.x or domain.y > bounds.end.x):
			errors.append("定义域超出作图区")
		normalized.append(formula)
	return {"ok": errors.is_empty(), "errors": errors, "formulas": normalized}
